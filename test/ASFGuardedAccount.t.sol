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
        i = withGuardian(i, T.RIGHT_SUSPEND);
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
        (T.Verdict v,) = acct.status();
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
        // adding full stop to the same set closes the de-risking path as well
        vm.prank(user);
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
        vm.prank(user);
        reg.suspend(bindingId, T.RESTRICT_NO_NEW_RISK, bytes32(0), bytes32(0));
        vm.prank(agent);
        vm.expectRevert();
        acct.execute(address(desk), 0, abi.encodeCall(LendingDesk.borrow, (1)));
        vm.prank(user);
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
        (T.Verdict v, T.Reason[] memory reasons) = acct.status();
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
        (, T.Reason[] memory reasons) = acct.status();
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
}
