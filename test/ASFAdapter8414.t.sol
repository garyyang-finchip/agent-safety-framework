// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {ASFTaskTenderAdapter} from "asf/adapters/ASFTaskTenderAdapter.sol";
import {ITaskTenderKernel} from "asf/interfaces/ITaskTenderKernel.sol";
import {TaskToken} from "./fixtures/task-token/TaskToken.sol";
import {ITaskTender} from "./fixtures/task-token/interfaces/ITaskTender.sol";
import {ToggleSpecRegistry} from "./mocks/ToggleSpecRegistry.sol";

/// Test group 5 — closed loop on the task path, against the real TASK-KERNEL v3.0 TaskToken (vendored
/// fixture): a tender whose acceptance authority admits only fulfillers holding the required binding.
contract ASFAdapter8414Test is ASFBase {
    TaskToken task;
    ASFTaskTenderAdapter adapter;

    address owner = address(0xA11CE);
    address taskPublisher = address(0xB0B);
    address funder = address(0xF00D);
    address worker = address(0xCAFE);
    address worker2 = address(0xCAFE2);

    bytes32 TD = sha256("TASK.md v1");
    bytes32 TH = sha256("taskroot v1");
    bytes32 RES = sha256("deliverable");

    event FulfillmentAccepted(uint256 indexed tokenId, uint256 indexed submissionId, address indexed fulfiller, uint256 reward);
    event FulfillmentRejected(uint256 indexed tokenId, uint256 indexed submissionId);

    function setUp() public override {
        super.setUp();
        task = new TaskToken("Task Token", "TASK");
        // the tender requires: a self-adopted binding of spec v1, enforced at least at the account level
        T.Clause memory c = clause();
        c.versions = new uint32[](1);
        c.versions[0] = 1;
        c.enforcement = T.ENFORCED_ACCOUNT;
        adapter = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        vm.deal(funder, 100 ether);
    }

    function terms(uint64 judgmentWindow) internal pure returns (ITaskTender.TenderTerms memory) {
        return ITaskTender.TenderTerms(address(0), 1 ether, 2, 0, 0, 0, 0, judgmentWindow);
    }

    function mintWithAdapter(uint64 judgmentWindow) internal returns (uint256 id) {
        id = task.mintTask(owner, taskPublisher, address(adapter), TD, TH, "ipfs://task-v1", terms(judgmentWindow));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
    }

    function submit(address who, uint256 id) internal returns (uint256 sid) {
        vm.prank(who);
        sid = task.submitFulfillment(id, RES, "ipfs://result");
    }

    /// The worker adopts the specification for itself (adopter == subject == worker).
    function selfAdopt(address who, bytes32 salt, uint16 enforcement) internal returns (bytes32 id) {
        T.BindingInput memory i = input(salt);
        i.subjectKey = ASFKeys.accountSubjectKey(who);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = enforcement;
        id = adoptAs(who, i);
    }

    function test_fulfiller_with_binding_is_accepted_and_paid_through_the_real_kernel() public {
        bytes32 b = selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (T.Verdict pre, bytes32[] memory ids,) = adapter.evaluate(worker);
        assertVerdict(pre, T.Verdict.Satisfied);
        assertEq(ids[0], b);
        uint256 before = worker.balance;
        vm.expectEmit(true, true, true, true, address(task));
        emit FulfillmentAccepted(id, sid, worker, 1 ether);
        vm.prank(rando);
        T.Verdict v = adapter.judge(id, sid);
        assertVerdict(v, T.Verdict.Satisfied);
        assertEq(worker.balance, before + 1 ether);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Accepted));
    }

    function test_N41_fulfiller_without_binding_is_rejected_and_the_reservation_released() public {
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        assertEq(task.pendingOf(id), 1);
        vm.expectEmit(true, true, false, true, address(task));
        emit FulfillmentRejected(id, sid);
        T.Verdict v = adapter.judge(id, sid);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        assertEq(task.pendingOf(id), 0);
    }

    function test_N42_a_binding_adopted_by_someone_else_for_the_worker_does_not_count() public {
        // the task publisher "adopts" the spec for the worker: an attributable statement by the publisher,
        // not the worker's own commitment, so the tender's self-adoption clause is not met
        T.BindingInput memory i = input(keccak256("x"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.enforcement = T.ENFORCED_ACCOUNT;
        adoptAs(taskPublisher, i);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (T.Verdict v,,) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_N43_binding_suspended_between_submission_and_judgment_leads_to_rejection() public {
        bytes32 b = selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        vm.prank(worker);
        reg.suspend(b, T.Restriction.FullStop, keccak256("self-reported incident"));
        (T.Verdict v, bytes32[] memory ids, T.Reason[] memory reasons) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(ids[0], b, "the explaining candidate is reported");
        assertReason(reasons[0], T.Reason.Suspended);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_N44_self_declared_enforcement_is_not_enough_for_this_tender() public {
        selfAdopt(worker, keccak256("w"), T.ENFORCED_SELF);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (, , T.Reason[] memory reasons) = adapter.evaluate(worker);
        assertReason(reasons[0], T.Reason.EnforcementMismatch);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_the_first_satisfying_binding_is_selected_among_several() public {
        selfAdopt(worker, keccak256("weak"), T.ENFORCED_SELF);
        bytes32 strong = selfAdopt(worker, keccak256("strong"), T.ENFORCED_ACCOUNT | T.ENFORCED_CONTRACT);
        (T.Verdict v, bytes32[] memory ids,) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.Satisfied);
        assertEq(ids[0], strong);
    }

    function test_N45_unknown_verdict_does_nothing_and_the_task_clock_governs() public {
        // a tender whose requirement points at a specification registry that later becomes unavailable
        bytes32 tSpec = keccak256("toggle spec");
        ToggleSpecRegistry toggle = new ToggleSpecRegistry(tSpec, HASH1);
        T.Clause memory c = clause();
        c.specRegistry = address(toggle);
        c.specId = tSpec;
        ASFTaskTenderAdapter a2 = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        T.BindingInput memory i = input(keccak256("t"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.specRegistry = address(toggle);
        i.specId = tSpec;
        adoptAs(worker, i);

        uint256 id = task.mintTask(owner, taskPublisher, address(a2), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        uint256 submittedAt = vm.getBlockTimestamp();

        toggle.setBroken(true);
        vm.expectRevert("ASFTender: verdict unknown; the task clock governs");
        a2.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Pending));
        // the kernel's own default is untouched by the unknown verdict
        vm.expectRevert("TaskToken: window open");
        task.claimUnjudged(id, sid);
        vm.warp(submittedAt + 7 days + 1);
        uint256 before = worker.balance;
        task.claimUnjudged(id, sid);
        assertEq(worker.balance, before + 1 ether, "silence pays the fulfiller, on the kernel's clock");
    }

    function test_N46_adapter_requires_the_authority_and_a_pending_judged_submission() public {
        uint256 id = task.mintTask(owner, taskPublisher, rando, TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        vm.expectRevert("ASFTender: not the acceptance authority");
        adapter.judge(id, sid);

        uint256 id2 = mintWithAdapter(7 days);
        uint256 sid2 = submit(worker, id2);
        adapter.judge(id2, sid2); // rejected (no binding)
        vm.expectRevert("ASFTender: not pending");
        adapter.judge(id2, sid2);
    }

    function test_N47_template_may_not_pre_bind_adopter_or_subject() public {
        T.Clause memory c = clauseFor(worker, bytes32(0), bytes32(0), 1);
        vm.expectRevert("ASFTender: template binds adopter or subject");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        c = clauseFor(address(0), subjectAgent, bytes32(0), 1);
        vm.expectRevert("ASFTender: template binds adopter or subject");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        vm.expectRevert("ASFTender: zero address");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(0)), one(clause()));
    }

    function test_requirement_for_a_fulfiller_fills_adopter_and_subject() public view {
        T.RequirementSet memory r = adapter.requirementFor(worker);
        assertEq(r.clauses[0].adopter, worker);
        assertEq(r.clauses[0].subjectKey, ASFKeys.accountSubjectKey(worker));
        assertEq(adapter.template().clauses[0].adopter, address(0));
        assertTrue(adapter.supportsInterface(0x01ffc9a7));
    }

    function test_two_workers_are_judged_independently() public {
        selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 s1 = submit(worker, id);
        uint256 s2 = submit(worker2, id);
        adapter.judge(id, s1);
        adapter.judge(id, s2);
        assertEq(uint8(task.submissionOf(id, s1).status), uint8(ITaskTender.SubmissionStatus.Accepted));
        assertEq(uint8(task.submissionOf(id, s2).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }
}
