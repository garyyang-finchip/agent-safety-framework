// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {ASFSpecificationRegistry} from "asf/ASFSpecificationRegistry.sol";
import {ASFBindingRegistry} from "asf/ASFBindingRegistry.sol";
import {ASFGuardedAccount} from "asf/examples/ASFGuardedAccount.sol";
import {ASFTaskTenderAdapter} from "asf/adapters/ASFTaskTenderAdapter.sol";
import {ITaskTenderKernel} from "asf/interfaces/ITaskTenderKernel.sol";
import {OperatorProbe, LendingDesk, IGuardedAccountLike} from "./helpers/OperatorProbe.sol";
import {TaskToken} from "../test/fixtures/task-token/TaskToken.sol";
import {ITaskTender} from "../test/fixtures/task-token/interfaces/ITaskTender.sol";

/// @notice Evidence run of the Agent Safety and Security Framework reference implementation (Sepolia, rehearsed on Anvil).
///
/// Three keys take part: PRIVATE_KEY (deployer; plays the principal, the specification publisher, the swarm
/// organizer and the task publisher), AGENT_PK (the assistant / worker / swarm member A), GUARDIAN_PK (the
/// guardian who may suspend the principal's binding). The deployer funds the other two with a little ETH.
///
/// Phases (each a separate `forge script --sig` invocation; state in deployments/<network>.json):
///   1. deployCore()      registries, LendingDesk, guarded account + probe, task adapter (and, without
///                        TASK_TOKEN, a local TaskToken fixture); funds the agent and the guardian
///      -> relink the examples with the real addresses:
///         node tools/build-examples.js --dir deployments/sepolia/examples --chain-id 11155111
///              --spec-registry <specRegistry> --binding-registry <bindingRegistry> --publisher <deployer>
///              --map 0x..a11ce=<deployer>,0x..a6e7=<agent>,0x..6a2d=<guardian>,0x..60a9=<deployer>,0x..aa=<agent>
///   2. publishAndAdopt() publish the two specifications; principal adopts for the assistant on the guarded
///                        account; organizer adopts for the swarm; agent adopts the derived member binding and
///                        its own worker binding; the principal presents the binding to the guarded account
///   3. guardLoop()       borrow (ok) -> guardian suspends (no new risk + derisk only) -> borrow refused -> repay ok -> guardian resumes -> borrow ok
///   4. tenderLoop()      mint a tender with the adapter as authority, fund it; the agent submits and is accepted
///                        and paid; the guardian (no binding) submits and is rejected
///   5. lifecycle()       full-stop suspension by the principal refuses even repay; resume; terminate the swarm binding and show the
///                        derived member binding failing with ParentNotSatisfied; deprecate a version
///
/// Environment: PRIVATE_KEY, AGENT_PK, GUARDIAN_PK, optional TASK_TOKEN (live kernel), optional DEPLOYMENTS
/// (default deployments/sepolia.json), optional MANIFEST (default deployments/sepolia/examples/manifest.json),
/// optional LOCATOR_BASE (URL prefix of the published example files).
contract SepoliaEvidence is Script {
    string internal constant SWARM_REF = "x:swarm:eip155:11155111:0x00000000000000000000000000000000000005aa:7";

    function _deployments() internal view returns (string memory) {
        return vm.envOr("DEPLOYMENTS", string("deployments/sepolia.json"));
    }

    function _manifestPath() internal view returns (string memory) {
        return vm.envOr("MANIFEST", string("deployments/sepolia/examples/manifest.json"));
    }

    function _state() internal view returns (string memory) {
        return vm.readFile(_deployments());
    }

    function _addr(string memory key) internal view returns (address) {
        return vm.parseJsonAddress(_state(), key);
    }

    function _put(string memory key, string memory json) internal {
        vm.writeJson(json, _deployments(), key);
    }

    function _locator(string memory file) internal view returns (string memory) {
        return string.concat(vm.envOr("LOCATOR_BASE", string("https://raw.githubusercontent.com/garyyang-finchip/agent-safety-framework/main/deployments/sepolia/examples/")), file);
    }

    // ------------------------------------------------------------------ phase 1

    struct Core {
        address deployer;
        address agent;
        address guardian;
        address specs;
        address reg;
        address desk;
        address acct;
        address probe;
        address taskToken;
        address adapter;
        bytes32 spec1;
        bytes32 spec2;
    }

    function deployCore() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Core memory c;
        c.deployer = vm.addr(pk);
        c.agent = vm.addr(vm.envUint("AGENT_PK"));
        c.guardian = vm.addr(vm.envUint("GUARDIAN_PK"));
        c.taskToken = vm.envOr("TASK_TOKEN", address(0));

        vm.startBroadcast(pk);
        _deployRegistries(c);
        _deployGuard(c);
        _deployAdapter(c);
        payable(c.agent).transfer(0.012 ether);
        payable(c.guardian).transfer(0.006 ether);
        vm.stopBroadcast();
        _recordCore(c);
    }

    function _deployRegistries(Core memory c) internal {
        ASFSpecificationRegistry specs = new ASFSpecificationRegistry();
        c.specs = address(specs);
        c.reg = address(new ASFBindingRegistry());
        c.desk = address(new LendingDesk());
        c.spec1 = specs.computeSpecId(c.deployer, bytes32(uint256(1)));
        c.spec2 = specs.computeSpecId(c.deployer, bytes32(uint256(2)));
    }

    /// The principal's account requires the principal's own adoption of Personal Assistant Safety v1 for the
    /// assistant, enforced at least at the account level.
    function _deployGuard(Core memory c) internal {
        T.RequirementSet memory req = _oneClause(c.specs, c.spec1, c.deployer, ASFKeys.accountSubjectKey(c.agent));
        ASFGuardedAccount acct = new ASFGuardedAccount(ASFBindingRegistry(c.reg), c.deployer, address(0), req);
        OperatorProbe probe = new OperatorProbe(c.agent, IGuardedAccountLike(address(acct)));
        acct.setOperator(address(probe));
        acct.setDeriskAllowed(c.desk, LendingDesk.repay.selector, true);
        acct.setDeriskAllowed(c.desk, LendingDesk.cancelOrder.selector, true);
        c.acct = address(acct);
        c.probe = address(probe);
    }

    /// The tender requires the fulfiller's own adoption of the same specification, account-enforced.
    /// The tender requires the fulfiller's own adoption of Personal Assistant Safety v1, account-enforced, with
    /// the task publisher (the deployer) named as an intervener holding the suspend right.
    function _deployAdapter(Core memory c) internal {
        if (c.taskToken == address(0)) c.taskToken = address(new TaskToken("Task Token", "TASK"));
        T.RequirementSet memory tmpl = _oneClause(c.specs, c.spec1, address(0), bytes32(0));
        tmpl.clauses[0].interveners = new T.Intervener[](1);
        tmpl.clauses[0].interveners[0] = T.Intervener({account: c.deployer, rights: T.RIGHT_SUSPEND});
        c.adapter = address(new ASFTaskTenderAdapter(ASFBindingRegistry(c.reg), ITaskTenderKernel(c.taskToken), tmpl));
    }

    function _oneClause(address specs, bytes32 specId, address adopter, bytes32 subjectKey)
        internal pure returns (T.RequirementSet memory req)
    {
        req.combinator = T.Combinator.All;
        req.clauses = new T.Clause[](1);
        req.clauses[0].specRegistry = specs;
        req.clauses[0].specId = specId;
        req.clauses[0].versions = new uint32[](1);
        req.clauses[0].versions[0] = 1;
        req.clauses[0].adopter = adopter;
        req.clauses[0].subjectKey = subjectKey;
        req.clauses[0].enforcement = T.ENFORCED_ACCOUNT;
    }

    function _recordCore(Core memory c) internal {
        string memory obj = "deployment";
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeAddress(obj, "deployer", c.deployer);
        vm.serializeAddress(obj, "agent", c.agent);
        vm.serializeAddress(obj, "guardian", c.guardian);
        vm.serializeAddress(obj, "specRegistry", c.specs);
        vm.serializeAddress(obj, "bindingRegistry", c.reg);
        vm.serializeAddress(obj, "lendingDesk", c.desk);
        vm.serializeAddress(obj, "guardedAccount", c.acct);
        vm.serializeAddress(obj, "operatorProbe", c.probe);
        vm.serializeAddress(obj, "taskToken", c.taskToken);
        vm.serializeBytes32(obj, "specIdPersonalAssistant", c.spec1);
        vm.serializeBytes32(obj, "specIdSwarmSharedFunds", c.spec2);
        string memory out = vm.serializeAddress(obj, "taskTenderAdapter", c.adapter);
        vm.writeJson(out, _deployments());
        console2.log("ASFSpecificationRegistry", c.specs);
        console2.log("ASFBindingRegistry", c.reg);
        console2.log("ASFGuardedAccount", c.acct);
        console2.log("ASFTaskTenderAdapter", c.adapter);
        console2.log("TaskToken", c.taskToken);
    }

    // ------------------------------------------------------------------ phase 2

    function publishAndAdopt() external {
        string memory m = vm.readFile(_manifestPath());
        (bytes32 spec1, bytes32 spec2) = _publishSpecs(m);
        (bytes32 personal, bytes32 charter) = _adoptAsPrincipal(m, spec1, spec2);
        (bytes32 member, bytes32 worker) = _adoptAsAgent(m, spec1, spec2, charter);
        _put(".bindingPersonalAssistant", _q(vm.toString(personal)));
        _put(".bindingSwarmCharter", _q(vm.toString(charter)));
        _put(".bindingSwarmMemberA", _q(vm.toString(member)));
        _put(".bindingWorkerSelf", _q(vm.toString(worker)));
        console2.log("personal binding"); console2.logBytes32(personal);
        console2.log("charter binding"); console2.logBytes32(charter);
        console2.log("member binding"); console2.logBytes32(member);
        console2.log("worker binding"); console2.logBytes32(worker);
    }

    function _publishSpecs(string memory m) internal returns (bytes32 spec1, bytes32 spec2) {
        ASFSpecificationRegistry specs = ASFSpecificationRegistry(_addr(".specRegistry"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        spec1 = specs.registerSpecification(
            bytes32(uint256(1)),
            vm.parseJsonBytes32(m, '.specifications["Personal Assistant Safety"].contentHash'),
            _locator("specifications/personal-assistant-safety.v1.json"),
            _profileIds(m, "Personal Assistant Safety")
        );
        spec2 = specs.registerSpecification(
            bytes32(uint256(2)),
            vm.parseJsonBytes32(m, '.specifications["Swarm Shared Funds"].contentHash'),
            _locator("specifications/swarm-shared-funds.v1.json"),
            _profileIds(m, "Swarm Shared Funds")
        );
        vm.stopBroadcast();
        require(spec1 == vm.parseJsonBytes32(m, '.specifications["Personal Assistant Safety"].specId'), "manifest spec1 mismatch");
        require(spec2 == vm.parseJsonBytes32(m, '.specifications["Swarm Shared Funds"].specId'), "manifest spec2 mismatch");
    }

    /// The principal adopts for the assistant on the guarded account (the guardian may suspend) and presents
    /// the binding to the account; the same key, as the swarm's organizer, adopts for the swarm.
    function _adoptAsPrincipal(string memory m, bytes32 spec1, bytes32 spec2) internal returns (bytes32 personal, bytes32 charter) {
        ASFBindingRegistry reg = ASFBindingRegistry(_addr(".bindingRegistry"));
        address specs = _addr(".specRegistry");
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // interveners come from the relinked example (the guardian with suspend + resume)
        T.BindingInput memory b1 = _input(m, "personal-assistant.binding.json", specs, spec1, "bindings/personal-assistant.binding.json");
        require(b1.interveners.length == 1 && b1.interveners[0].account == _addr(".guardian"), "guardian not relinked");
        personal = reg.adopt(b1);
        bytes32[] memory present = new bytes32[](1);
        present[0] = personal;
        ASFGuardedAccount(payable(_addr(".guardedAccount"))).presentBindings(present);
        charter = reg.adopt(_input(m, "swarm-charter.binding.json", specs, spec2, "bindings/swarm-charter.binding.json"));
        vm.stopBroadcast();
    }

    /// Member A derives its own binding from the swarm's; the worker binds itself for tenders.
    function _adoptAsAgent(string memory m, bytes32 spec1, bytes32 spec2, bytes32 charter) internal returns (bytes32 member, bytes32 worker) {
        ASFBindingRegistry reg = ASFBindingRegistry(_addr(".bindingRegistry"));
        address specs = _addr(".specRegistry");
        vm.startBroadcast(vm.envUint("AGENT_PK"));
        T.BindingInput memory b3 = _input(m, "swarm-member-a.binding.json", specs, spec2, "bindings/swarm-member-a.binding.json");
        b3.parentBindingId = charter;
        member = reg.adopt(b3);
        worker = reg.adopt(_input(m, "worker-self.binding.json", specs, spec1, "bindings/worker-self.binding.json"));
        vm.stopBroadcast();
    }

    // ------------------------------------------------------------------ phase 3

    function guardLoop() external {
        uint256 agentPk = vm.envUint("AGENT_PK");
        uint256 guardianPk = vm.envUint("GUARDIAN_PK");
        ASFBindingRegistry reg = ASFBindingRegistry(_addr(".bindingRegistry"));
        OperatorProbe probe = OperatorProbe(_addr(".operatorProbe"));
        LendingDesk desk = LendingDesk(_addr(".lendingDesk"));
        bytes32 personal = vm.parseJsonBytes32(_state(), ".bindingPersonalAssistant");

        vm.startBroadcast(agentPk);
        (bool ok1,) = probe.attempt(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (100)));
        vm.stopBroadcast();
        require(ok1, "borrow while active should pass");

        string memory m = vm.readFile(_manifestPath());
        vm.startBroadcast(guardianPk);
        reg.suspend(
            personal,
            uint8(vm.parseJsonUint(m, '.responses["guardian-derisk-only.response.json"].restrictionsBits')),
            vm.parseJsonBytes32(m, '.responses["guardian-derisk-only.response.json"].responseRef'),
            keccak256("alert: injected instruction detected")
        );
        vm.stopBroadcast();

        vm.startBroadcast(agentPk);
        (bool ok2,) = probe.attempt(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        (bool ok3,) = probe.attempt(address(desk), 0, abi.encodeCall(LendingDesk.repay, (40)));
        vm.stopBroadcast();
        require(!ok2, "borrow under no-new-risk + derisk-only should be refused");
        require(ok3, "repay under no-new-risk + derisk-only should pass");

        // the guardian's suspension is not the principal's to lift: the guardian (suspend + resume) resumes
        vm.startBroadcast(guardianPk);
        reg.resume(personal, keccak256("reviewed: false alarm"));
        vm.stopBroadcast();

        vm.startBroadcast(agentPk);
        (bool ok4,) = probe.attempt(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        vm.stopBroadcast();
        require(ok4, "borrow after resume should pass");

        _put(".guardLoop", '"borrow ok; guardian suspends (no new risk + derisk only); borrow refused; repay ok; guardian resumes; borrow ok"');
        console2.log("guard loop complete; desk debt", desk.debt(_addr(".guardedAccount")));
    }

    // ------------------------------------------------------------------ phase 4

    function tenderLoop() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 agentPk = vm.envUint("AGENT_PK");
        uint256 guardianPk = vm.envUint("GUARDIAN_PK");
        address deployer = vm.addr(pk);
        address agent = vm.addr(agentPk);
        TaskToken task = TaskToken(_addr(".taskToken"));
        ASFTaskTenderAdapter adapter = ASFTaskTenderAdapter(_addr(".taskTenderAdapter"));

        vm.startBroadcast(pk);
        ITaskTender.TenderTerms memory terms = ITaskTender.TenderTerms(address(0), 0.001 ether, 2, 0, 0, 0, 0, 7 days);
        uint256 tokenId = task.mintTask(deployer, deployer, address(adapter), sha256("ASF evidence task"), sha256("asf taskroot v1"), _locator("task.json"), terms);
        task.fundTask{value: 0.002 ether}(tokenId, 0.002 ether);
        vm.stopBroadcast();

        vm.startBroadcast(agentPk);
        uint256 sidWorker = task.submitFulfillment(tokenId, sha256("deliverable by the bound worker"), _locator("result-worker.json"));
        vm.stopBroadcast();
        vm.startBroadcast(guardianPk);
        uint256 sidUnbound = task.submitFulfillment(tokenId, sha256("deliverable by an unbound account"), _locator("result-unbound.json"));
        vm.stopBroadcast();

        uint256 before = agent.balance;
        vm.startBroadcast(pk);
        T.Verdict v1 = adapter.judge(tokenId, sidWorker);
        T.Verdict v2 = adapter.judge(tokenId, sidUnbound);
        vm.stopBroadcast();
        require(v1 == T.Verdict.Satisfied, "bound worker should be accepted");
        require(v2 == T.Verdict.NotSatisfied, "unbound account should be rejected");

        _put(".tenderTokenId", vm.toString(tokenId));
        _put(".tenderSubmissionWorker", vm.toString(sidWorker));
        _put(".tenderSubmissionUnbound", vm.toString(sidUnbound));
        console2.log("tender", tokenId, "worker paid", agent.balance - before);
    }

    // ------------------------------------------------------------------ phase 5

    function lifecycle() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 agentPk = vm.envUint("AGENT_PK");
        ASFSpecificationRegistry specs = ASFSpecificationRegistry(_addr(".specRegistry"));
        ASFBindingRegistry reg = ASFBindingRegistry(_addr(".bindingRegistry"));
        OperatorProbe probe = OperatorProbe(_addr(".operatorProbe"));
        LendingDesk desk = LendingDesk(_addr(".lendingDesk"));
        string memory s = _state();
        bytes32 personal = vm.parseJsonBytes32(s, ".bindingPersonalAssistant");
        bytes32 charter = vm.parseJsonBytes32(s, ".bindingSwarmCharter");
        bytes32 member = vm.parseJsonBytes32(s, ".bindingSwarmMemberA");
        bytes32 spec2 = vm.parseJsonBytes32(s, ".specIdSwarmSharedFunds");

        string memory m = vm.readFile(_manifestPath());
        vm.startBroadcast(pk);
        reg.suspend(
            personal,
            uint8(vm.parseJsonUint(m, '.responses["principal-full-stop.response.json"].restrictionsBits')),
            vm.parseJsonBytes32(m, '.responses["principal-full-stop.response.json"].responseRef'),
            keccak256("maintenance")
        );
        vm.stopBroadcast();
        vm.startBroadcast(agentPk);
        (bool ok,) = probe.attempt(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
        vm.stopBroadcast();
        require(!ok, "full stop refuses even repay");

        vm.startBroadcast(pk);
        reg.resume(personal, keccak256("maintenance over"));
        reg.terminate(charter, keccak256("swarm dissolved"));
        specs.deprecateVersion(spec2, 1, keccak256("superseded by a later arrangement"));
        vm.stopBroadcast();

        T.Clause memory c;
        c.specRegistry = address(specs);
        c.specId = spec2;
        c.versions = new uint32[](0);
        (T.Verdict v, T.Reason r,) = reg.checkBinding(member, c);
        require(v == T.Verdict.NotSatisfied && r == T.Reason.ParentNotSatisfied, "member falls with the charter");
        require(reg.bindingOf(member).state == T.BindingState.Active, "member record untouched");

        _put(".lifecycle", '"full stop refused repay; resumed; charter terminated; member ParentNotSatisfied; swarm spec v1 deprecated"');
        console2.log("lifecycle complete");
    }

    // ------------------------------------------------------------------ helpers

    function _q(string memory v) internal pure returns (string memory) {
        return string.concat('"', v, '"');
    }

    function _profileIds(string memory m, string memory spec) internal view returns (bytes32[] memory ids) {
        string memory key = string.concat('.specifications["', spec, '"].requiredProfiles');
        uint256 n = 0;
        while (true) {
            string memory p = string.concat(key, "[", vm.toString(n), "].profileId");
            if (!vm.keyExistsJson(m, p)) break;
            n++;
        }
        ids = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            ids[i] = vm.parseJsonBytes32(m, string.concat(key, "[", vm.toString(i), "].profileId"));
        }
    }

    function _input(string memory m, string memory file, address specRegistry, bytes32 specId, string memory locatorFile)
        internal view returns (T.BindingInput memory i)
    {
        string memory k = string.concat('.bindings["', file, '"]');
        i.subjectKey = vm.parseJsonBytes32(m, string.concat(k, ".subjectKey"));
        i.scopeKey = vm.parseJsonBytes32(m, string.concat(k, ".scopeKey"));
        i.specRegistry = specRegistry;
        i.specId = specId;
        i.version = uint32(vm.parseJsonUint(m, string.concat(k, ".specification.version")));
        i.contentHash = vm.parseJsonBytes32(m, string.concat(k, ".specification.contentHash"));
        i.paramsHash = vm.parseJsonBytes32(m, string.concat(k, ".paramsHash"));
        i.paramsLocator = _locator(locatorFile);
        i.authorityRef = vm.parseJsonBytes32(m, string.concat(k, ".authorityRef"));
        i.enforcement = uint16(vm.parseJsonUint(m, string.concat(k, ".enforcement")));
        i.validFrom = uint64(vm.parseJsonUint(m, string.concat(k, ".validFrom")));
        i.validUntil = uint64(vm.parseJsonUint(m, string.concat(k, ".validUntil")));
        i.salt = vm.parseJsonBytes32(m, string.concat(k, ".salt"));
        uint256 n = vm.parseJsonUint(m, string.concat(k, ".intervenerCount"));
        i.interveners = new T.Intervener[](n);
        for (uint256 j = 0; j < n; j++) {
            string memory q = string.concat(k, ".interveners[", vm.toString(j), "]");
            i.interveners[j] = T.Intervener({
                account: vm.parseJsonAddress(m, string.concat(q, ".account")),
                rights: uint8(vm.parseJsonUint(m, string.concat(q, ".rights")))
            });
        }
    }
}
