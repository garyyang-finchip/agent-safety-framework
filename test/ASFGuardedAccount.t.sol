// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {ASFGuardedAccount} from "asf/examples/ASFGuardedAccount.sol";

/// A target the guarded account acts on: new exposure (borrow) versus de-risking (repay, cancel).
contract LendingDesk {
    mapping(address => uint256) public debt;
    mapping(address => uint256) public orders;
    function borrow(uint256 amount) external { debt[msg.sender] += amount; }
    function repay(uint256 amount) external { debt[msg.sender] -= amount; }
    function placeOrder() external { orders[msg.sender] += 1; }
    function cancelOrder() external { orders[msg.sender] -= 1; }
}

/// Test group 4 — closed loop on the wallet path: an operator may act only while the principal's
/// binding is satisfied; suspension blocks; DeriskOnly keeps the de-risking calls open; no bypass exists.
contract ASFGuardedAccountTest is ASFBase {
    ASFGuardedAccount acct;
    LendingDesk desk;
    bytes32 bindingId;

    function setUp() public override {
        super.setUp();
        desk = new LendingDesk();
        // the account requires: the user's own adoption of spec v1 for the agent on this wallet,
        // enforced at least at the account level
        T.Clause memory c = clauseFor(user, subjectAgent, bytes32(0), 1);
        c.enforcement = T.ENFORCED_ACCOUNT;
        acct = new ASFGuardedAccount(reg, user, agent, one(c));
        // the scope of the binding is the guarded account itself
        T.BindingInput memory i = input(keccak256("wallet"));
        i.scopeKey = keccak256(bytes(string.concat('{"ref":"', "guarded-account", '"}')));
        i.enforcement = T.ENFORCED_ACCOUNT;
        i = withGuardian(i, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        bindingId = adoptAs(user, i);
        vm.prank(user);
        acct.presentBindings(ids1(bindingId));
        vm.startPrank(user);
        acct.setDeriskAllowed(address(desk), LendingDesk.repay.selector, true);
        acct.setDeriskAllowed(address(desk), LendingDesk.cancelOrder.selector, true);
        vm.stopPrank();
    }

    function exec(bytes memory data) internal {
        vm.prank(agent);
        acct.execute(address(desk), 0, data);
    }

    function test_operator_acts_while_the_binding_is_satisfied() public {
        exec(abi.encodeCall(LendingDesk.borrow, (100)));
        exec(abi.encodeCall(LendingDesk.placeOrder, ()));
        assertEq(desk.debt(address(acct)), 100);
        assertEq(desk.orders(address(acct)), 1);
        (T.Verdict v,,) = acct.status();
        assertVerdict(v, T.Verdict.Satisfied);
    }

    function test_N33_suspension_blocks_new_exposure_and_derisk_only_keeps_unwinding_open() public {
        exec(abi.encodeCall(LendingDesk.borrow, (100)));
        exec(abi.encodeCall(LendingDesk.placeOrder, ()));
        // the guardian suspends under DeriskOnly after an alert
        vm.prank(guardian);
        reg.suspend(bindingId, T.RESTRICT_DERISK_ONLY, bytes32(0), keccak256("alert: injected instruction detected"));
        // new exposure is blocked
        vm.prank(agent);
        vm.expectRevert(); // ASFGuardedAccount.BindingNotSatisfied(NotSatisfied, [Suspended])
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.placeOrder, ()));
        // de-risking still goes through
        exec(abi.encodeCall(LendingDesk.repay, (40)));
        exec(abi.encodeCall(LendingDesk.cancelOrder, ()));
        assertEq(desk.debt(address(acct)), 60);
        assertEq(desk.orders(address(acct)), 0);
    }

    function test_N48_combined_response_requirements_keep_derisking_open_unless_full_stop_is_set() public {
        exec(abi.encodeCall(LendingDesk.borrow, (100)));
        // no new risk + derisk only: borrowing stops, repaying continues
        vm.prank(guardian);
        reg.suspend(bindingId, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, keccak256("response"), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        exec(abi.encodeCall(LendingDesk.repay, (10)));
        assertEq(desk.debt(address(acct)), 90);
        // adding full stop to the same set closes the de-risking path as well (the guardian lifts its own
        // suspension; the principal could not)
        vm.prank(guardian);
        reg.resume(bindingId, bytes32(0));
        vm.prank(user);
        reg.suspend(bindingId, T.RESTRICT_DERISK_ONLY | T.RESTRICT_FULL_STOP, keccak256("response"), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
    }

    function test_N34_full_stop_blocks_even_derisking() public {
        exec(abi.encodeCall(LendingDesk.borrow, (100)));
        vm.prank(user);
        reg.suspend(bindingId, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
    }

    function test_N35_resume_reopens_and_terminate_closes_for_good() public {
        vm.prank(guardian);
        reg.suspend(bindingId, T.RESTRICT_NO_NEW_RISK, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        // the principal cannot wave the guardian's stop away; the guardian lifts it
        vm.prank(user);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(bindingId, bytes32(0));
        vm.prank(guardian);
        reg.resume(bindingId, bytes32(0));
        exec(abi.encodeCall(LendingDesk.borrow, (1)));
        vm.prank(user);
        reg.terminate(bindingId, bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1))); // terminated is not DeriskOnly
    }

    function test_N36_expiry_closes_the_path_without_any_transaction() public {
        T.BindingInput memory i = input(keccak256("short"));
        i.enforcement = T.ENFORCED_ACCOUNT;
        i.validUntil = uint64(block.timestamp + 1 days);
        bytes32 shortId = adoptAs(user, i);
        vm.prank(user);
        acct.presentBindings(ids1(shortId));
        exec(abi.encodeCall(LendingDesk.borrow, (1)));
        vm.warp(block.timestamp + 1 days);
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
    }

    function test_N37_a_third_partys_binding_does_not_satisfy_the_principals_requirement() public {
        // rando adopts the very same specification for the same agent; the account requires the user's adoption
        T.BindingInput memory i = input(keccak256("impostor"));
        i.enforcement = T.ENFORCED_ACCOUNT;
        bytes32 impostor = adoptAs(rando, i);
        vm.prank(user);
        acct.presentBindings(ids1(impostor));
        (T.Verdict v, T.Reason[] memory reasons,) = acct.status();
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.AdopterMismatch);
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
    }

    function test_N38_weaker_enforcement_declaration_is_refused() public {
        T.BindingInput memory i = input(keccak256("self-declared"));
        i.enforcement = T.ENFORCED_SELF; // the agent promises; the account requires account-level enforcement
        bytes32 weak = adoptAs(user, i);
        vm.prank(user);
        acct.presentBindings(ids1(weak));
        (, T.Reason[] memory reasons,) = acct.status();
        assertReason(reasons[0], T.Reason.EnforcementMismatch);
    }

    function test_N39_only_the_operator_executes_and_only_the_owner_configures() public {
        vm.prank(rando);
        vm.expectRevert(ASFGuardedAccount.NotOperator.selector);
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        vm.prank(agent);
        vm.expectRevert(ASFGuardedAccount.NotOwner.selector);
        acct.presentBindings(ids1(bindingId));
        vm.prank(agent);
        vm.expectRevert(ASFGuardedAccount.NotOwner.selector);
        acct.setDeriskAllowed(address(desk), LendingDesk.borrow.selector, true);
    }

    function test_N40_malformed_requirement_cannot_be_deployed() public {
        T.RequirementSet memory r;
        r.clauses = new T.Clause[](0);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        new ASFGuardedAccount(reg, user, agent, r);
    }

    function test_requirement_is_fixed_at_deployment() public view {
        T.RequirementSet memory r = acct.requirement();
        assertEq(r.clauses.length, 1);
        assertEq(r.clauses[0].adopter, user);
        assertEq(r.clauses[0].subjectKey, subjectAgent);
        assertEq(r.clauses[0].versions[0], 1);
        assertEq(r.clauses[0].enforcement, T.ENFORCED_ACCOUNT);
    }

    // ------------------------------------------------------------- derived bindings on the wallet path

    /// The agent operates under its own binding derived from the principal's root binding; the account
    /// requires the agent's own (derived) adoption, account-enforced.
    function deriveSetup() internal returns (ASFGuardedAccount dacct, bytes32 root, bytes32 child) {
        T.BindingInput memory p = input(keccak256("root"));
        p.enforcement = T.ENFORCED_ACCOUNT;
        p = withGuardian(p, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        root = adoptAs(user, p);
        T.BindingInput memory c = input(keccak256("child"));
        c.enforcement = T.ENFORCED_ACCOUNT;
        c.parentBindingId = root;
        child = adoptAs(agent, c);
        T.Clause memory cl = clauseFor(agent, subjectAgent, scopeWallet, 1);
        cl.enforcement = T.ENFORCED_ACCOUNT;
        dacct = new ASFGuardedAccount(reg, user, agent, one(cl));
        vm.startPrank(user);
        dacct.presentBindings(ids1(child));
        dacct.setDeriskAllowed(address(desk), LendingDesk.repay.selector, true);
        dacct.setDeriskAllowed(address(desk), LendingDesk.cancelOrder.selector, true);
        vm.stopPrank();
    }

    function dexec(ASFGuardedAccount dacct, bytes memory data) internal {
        vm.prank(agent);
        dacct.execute(address(desk), 0, data);
    }

    function test_N52_a_parents_derisk_only_suspension_keeps_the_derived_bindings_unwinding_open() public {
        (ASFGuardedAccount dacct, bytes32 root, bytes32 child) = deriveSetup();
        dexec(dacct, abi.encodeCall(LendingDesk.borrow, (100)));
        dexec(dacct, abi.encodeCall(LendingDesk.placeOrder, ()));
        // the guardian suspends the ROOT with no new risk + de-risk only
        vm.prank(guardian);
        reg.suspend(root, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, keccak256("response"), keccak256("alert"));
        (T.Verdict v, T.Reason[] memory reasons, uint8[] memory sets) = dacct.status();
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.ParentNotSatisfied);
        assertEq(sets[0], T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, "the set in force comes from the ancestor");
        assertEq(reg.bindingOf(root).restrictions, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY);
        // new exposure is blocked through the derived binding...
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.placeOrder, ()));
        // ...while the de-risking calls still go through, although the child's own record carries no set
        assertEq(reg.bindingOf(child).restrictions, 0, "the derived record itself is Active with an empty set");
        dexec(dacct, abi.encodeCall(LendingDesk.repay, (40)));
        dexec(dacct, abi.encodeCall(LendingDesk.cancelOrder, ()));
        assertEq(desk.debt(address(dacct)), 60);
        assertEq(desk.orders(address(dacct)), 0);
        // the guardian lifts its suspension: everything reopens
        vm.prank(guardian);
        reg.resume(root, bytes32(0));
        dexec(dacct, abi.encodeCall(LendingDesk.borrow, (1)));
        assertEq(desk.debt(address(dacct)), 61);
    }

    function test_N53_a_parents_full_stop_or_termination_closes_the_derived_bindings_derisking_path() public {
        (ASFGuardedAccount dacct, bytes32 root,) = deriveSetup();
        dexec(dacct, abi.encodeCall(LendingDesk.borrow, (100)));
        // full stop on the root: even repay through the derived binding reverts
        vm.prank(user);
        reg.suspend(root, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
        vm.prank(user);
        reg.resume(root, bytes32(0));
        dexec(dacct, abi.encodeCall(LendingDesk.repay, (1)));
        // termination of the root: ParentNotSatisfied with an empty set; nothing goes through
        vm.prank(user);
        reg.terminate(root, bytes32(0));
        (T.Verdict v, T.Reason[] memory reasons, uint8[] memory sets) = dacct.status();
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.ParentNotSatisfied);
        assertEq(sets[0], 0);
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
    }

    function test_N54_sets_of_the_child_and_of_the_parent_combine_and_full_stop_dominates() public {
        (ASFGuardedAccount dacct, bytes32 root, bytes32 child) = deriveSetup();
        dexec(dacct, abi.encodeCall(LendingDesk.borrow, (100)));
        // root: de-risk only; child: essential only. The union keeps the de-risking path open.
        vm.prank(guardian);
        reg.suspend(root, T.RESTRICT_DERISK_ONLY, bytes32(0), bytes32(0));
        vm.prank(agent);
        reg.suspend(child, T.RESTRICT_ESSENTIAL_ONLY, bytes32(0), bytes32(0));
        (, T.Reason[] memory reasons, uint8[] memory sets) = dacct.status();
        assertReason(reasons[0], T.Reason.Suspended);
        assertEq(sets[0], T.RESTRICT_DERISK_ONLY | T.RESTRICT_ESSENTIAL_ONLY);
        dexec(dacct, abi.encodeCall(LendingDesk.repay, (10)));
        // child: full stop while the root still says de-risk only. Full stop dominates: repay reverts.
        vm.prank(agent);
        reg.resume(child, bytes32(0));
        vm.prank(agent);
        reg.suspend(child, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
        // and the other way round: root full stop, child de-risk only
        vm.prank(agent);
        reg.resume(child, bytes32(0));
        vm.prank(guardian);
        reg.resume(root, bytes32(0));
        vm.prank(user);
        reg.suspend(root, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(agent);
        reg.suspend(child, T.RESTRICT_DERISK_ONLY, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        dacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (1)));
    }

    /// A wallet whose requirement names the guardian: the owner (adopter) cannot escape the guardian's stop by
    /// terminating the stopped binding and presenting a fresh one.
    function test_N63_a_guardians_stop_follows_the_principal_to_a_fresh_binding_on_the_wallet_path() public {
        T.Clause memory c = clauseFor(user, subjectAgent, bytes32(0), 1);
        c.enforcement = T.ENFORCED_ACCOUNT;
        c.interveners = new T.Intervener[](1);
        c.interveners[0] = T.Intervener({account: guardian, rights: T.RIGHT_SUSPEND | T.RIGHT_RESUME});
        ASFGuardedAccount gacct = new ASFGuardedAccount(reg, user, agent, one(c));
        T.BindingInput memory i = input(keccak256("wallet-g"));
        i.enforcement = T.ENFORCED_ACCOUNT;
        i = withGuardian(i, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        bytes32 b = adoptAs(user, i);
        vm.startPrank(user);
        gacct.presentBindings(ids1(b));
        gacct.setDeriskAllowed(address(desk), LendingDesk.repay.selector, true);
        vm.stopPrank();
        vm.prank(agent);
        gacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (100)));

        // the guardian stops with no new risk + de-risk only
        vm.prank(guardian);
        reg.suspend(b, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, keccak256("resp"), keccak256("alert"));
        // the owner terminates the stopped binding, adopts afresh (naming the guardian again, as the clause requires)
        // and presents the fresh binding: new exposure stays blocked, with the stop's own set reported
        vm.prank(user);
        reg.terminate(b, keccak256("replaced"));
        T.BindingInput memory j = input(keccak256("wallet-g-fresh"));
        j.enforcement = T.ENFORCED_ACCOUNT;
        j = withGuardian(j, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        bytes32 fresh = adoptAs(user, j);
        vm.prank(user);
        gacct.presentBindings(ids1(fresh));
        (T.Verdict v, T.Reason[] memory reasons, uint8[] memory sets) = gacct.status();
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.StoppedByIntervener);
        assertEq(sets[0], T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY);
        assertEq(reg.bindingOf(fresh).restrictions, 0, "the fresh record itself carries no set");
        vm.prank(agent);
        vm.expectRevert();
        gacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        // ...while repayment, a de-risking call, still goes through under the stop's set
        vm.prank(agent);
        gacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.repay, (40)));
        assertEq(desk.debt(address(gacct)), 60);
        // the owner cannot lift the stop; the guardian lifts it through the terminated record and the wallet reopens
        vm.prank(user);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(b, bytes32(0));
        vm.prank(guardian);
        reg.resume(b, keccak256("alert over"));
        (T.Verdict v2,,) = gacct.status();
        assertVerdict(v2, T.Verdict.Satisfied);
        vm.prank(agent);
        gacct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        assertEq(desk.debt(address(gacct)), 61);
    }
}
