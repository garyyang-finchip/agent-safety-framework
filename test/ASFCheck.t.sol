// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {ToggleSpecRegistry} from "./mocks/ToggleSpecRegistry.sol";

/// Test group 3 — the registry-level check: clause semantics, reasons, time, ancestors, requirement
/// combinators, Unknown on dependency failure, and the "no automatic upgrade" rule.
contract ASFCheckTest is ASFBase {
    function test_satisfied_clause_reports_no_reason() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        (T.Verdict v, T.Reason r, uint8 x) = reg.checkBinding(id, clauseFor(user, subjectAgent, scopeWallet, 1));
        assertVerdict(v, T.Verdict.Satisfied);
        assertReason(r, T.Reason.None);
        assertEq(x, 0);
    }

    function test_N23_no_binding_supplied_or_unknown_id() public view {
        (T.Verdict v, T.Reason r,) = reg.checkBinding(bytes32(0), clause());
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.NoBinding);
        (v, r,) = reg.checkBinding(keccak256("ghost"), clause());
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.NoBinding);
    }

    function test_N24_state_reasons_and_restriction_surface() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.prank(user);
        reg.suspend(id, T.RESTRICT_DERISK_ONLY, bytes32(0), bytes32(0));
        (T.Verdict v, T.Reason r, uint8 x) = reg.checkBinding(id, clause());
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.Suspended);
        assertEq(x, T.RESTRICT_DERISK_ONLY, "consumers learn which response requirements apply");
        vm.prank(user);
        reg.terminate(id, bytes32(0));
        (v, r,) = reg.checkBinding(id, clause());
        assertReason(r, T.Reason.Terminated);
    }

    function test_N25_time_window_is_half_open() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.validFrom = uint64(block.timestamp + 1 days);
        i.validUntil = uint64(block.timestamp + 2 days);
        bytes32 id = adoptAs(user, i);
        (T.Verdict v, T.Reason r,) = reg.checkBinding(id, clause());
        assertReason(r, T.Reason.NotYetValid);
        vm.warp(block.timestamp + 1 days);
        (v, r,) = reg.checkBinding(id, clause());
        assertVerdict(v, T.Verdict.Satisfied);
        vm.warp(block.timestamp + 1 days - 1);
        (v, r,) = reg.checkBinding(id, clause());
        assertVerdict(v, T.Verdict.Satisfied);
        vm.warp(block.timestamp + 1); // == validUntil: exclusive end
        (v, r,) = reg.checkBinding(id, clause());
        assertReason(r, T.Reason.Expired);
    }

    function test_N26_clause_mismatches_in_evaluation_order() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        T.Clause memory c = clause();
        c.specId = keccak256("other spec");
        (, T.Reason r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.SpecMismatch);
        c = clause();
        c.specRegistry = address(0xBEEF);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.SpecMismatch);
        c = clauseFor(address(0), bytes32(0), bytes32(0), 2);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.VersionMismatch);
        c = clauseFor(rando, bytes32(0), bytes32(0), 0);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.AdopterMismatch);
        c = clauseFor(address(0), keccak256("someone else"), bytes32(0), 0);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.SubjectMismatch);
        c = clauseFor(address(0), bytes32(0), keccak256("another scope"), 0);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.ScopeMismatch);
        c = clause();
        c.enforcement = T.ENFORCED_COLLECTIVE; // binding declares ACCOUNT|CONTRACT only
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.EnforcementMismatch);
        c.enforcement = T.ENFORCED_ACCOUNT; // a subset of what is declared is fine
        (T.Verdict v,,) = reg.checkBinding(id, c);
        assertVerdict(v, T.Verdict.Satisfied);
    }

    function test_N27_a_new_specification_version_never_upgrades_a_binding() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.prank(publisher);
        specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
        assertEq(reg.bindingOf(id).version, 1, "still pinned to v1");
        (, T.Reason r,) = reg.checkBinding(id, clauseFor(address(0), bytes32(0), bytes32(0), 2));
        assertReason(r, T.Reason.VersionMismatch);
        // a clause that admits either version is satisfied by the v1 adoption
        T.Clause memory c = clause();
        c.versions = new uint32[](2);
        c.versions[0] = 1;
        c.versions[1] = 2;
        (T.Verdict v,,) = reg.checkBinding(id, c);
        assertVerdict(v, T.Verdict.Satisfied);
    }

    function test_N28_ancestor_failure_propagates_to_derived_bindings() public {
        bytes32 parent = adoptAs(user, input(keccak256("parent")));
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = parent;
        bytes32 child = adoptAs(agent, c);
        T.BindingInput memory g = input(keccak256("grandchild"));
        g.parentBindingId = child;
        bytes32 grandchild = adoptAs(rando, g);

        vm.prank(user);
        reg.suspend(parent, T.RESTRICT_NO_NEW_RISK, bytes32(0), bytes32(0));
        (T.Verdict v, T.Reason r, uint8 x) = reg.checkBinding(grandchild, clause());
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.ParentNotSatisfied);
        assertEq(x, T.RESTRICT_NO_NEW_RISK, "the ancestor's response requirements are surfaced");
        (, r,) = reg.checkBinding(child, clause());
        assertReason(r, T.Reason.ParentNotSatisfied);

        vm.prank(user);
        reg.resume(parent, bytes32(0));
        (v,,) = reg.checkBinding(grandchild, clause());
        assertVerdict(v, T.Verdict.Satisfied);

        vm.prank(user);
        reg.terminate(parent, bytes32(0));
        (, r,) = reg.checkBinding(child, clause());
        assertReason(r, T.Reason.ParentNotSatisfied);
        assertEq(uint8(reg.bindingOf(child).state), uint8(T.BindingState.Active), "the child's own record is untouched");
    }

    function test_N29_unknown_when_the_specification_registry_is_unavailable() public {
        bytes32 tSpec = keccak256("toggle spec");
        ToggleSpecRegistry toggle = new ToggleSpecRegistry(tSpec, HASH1);
        T.BindingInput memory i = input(keccak256("t"));
        i.specRegistry = address(toggle);
        i.specId = tSpec;
        bytes32 id = adoptAs(user, i);
        T.Clause memory c = clause();
        c.specRegistry = address(toggle);
        c.specId = tSpec;
        (T.Verdict v,,) = reg.checkBinding(id, c);
        assertVerdict(v, T.Verdict.Satisfied);
        toggle.setBroken(true);
        (T.Verdict v2, T.Reason r2,) = reg.checkBinding(id, c);
        assertVerdict(v2, T.Verdict.Unknown);
        assertReason(r2, T.Reason.SpecRegistryUnavailable);
        // Unknown never satisfies, under any combinator
        (T.Verdict all,) = reg.check(one(c), ids1(id));
        assertVerdict(all, T.Verdict.Unknown);
        T.RequirementSet memory anyOf = one(c);
        anyOf.combinator = T.Combinator.Any;
        (T.Verdict any,) = reg.check(anyOf, ids1(id));
        assertVerdict(any, T.Verdict.Unknown);
    }

    // ------------------------------------------------------------------------ requirement sets

    function test_N30_requirement_validation() public {
        T.RequirementSet memory r;
        r.clauses = new T.Clause[](0);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(r);
        r = one(clause());
        r.k = 1; // k must be zero unless KOf
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(r);
        r = one(clause());
        r.combinator = T.Combinator.KOf;
        r.k = 0;
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(r);
        r.k = 2; // more than the clause count
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(r);
        r = one(clause());
        r.clauses[0].specId = bytes32(0);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(r);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.checkBinding(bytes32(0), r.clauses[0]);
        // length mismatch between clauses and candidates
        r = one(clause());
        vm.expectRevert(ASFErrors.LengthMismatch.selector);
        reg.check(r, new bytes32[](2));
    }

    function test_N31_combinators() public {
        bytes32 a = adoptAs(user, input(keccak256("a")));
        bytes32 b = adoptAs(user, input(keccak256("b")));
        bytes32 c = adoptAs(user, input(keccak256("c")));
        vm.prank(user);
        reg.suspend(c, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));

        T.RequirementSet memory r;
        r.clauses = new T.Clause[](3);
        r.clauses[0] = clause();
        r.clauses[1] = clause();
        r.clauses[2] = clause();

        r.combinator = T.Combinator.All;
        (T.Verdict v, T.Reason[] memory reasons) = reg.check(r, ids3(a, b, c));
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[2], T.Reason.Suspended);
        (v,) = reg.check(r, ids3(a, b, a));
        assertVerdict(v, T.Verdict.Satisfied);

        r.combinator = T.Combinator.Any;
        (v,) = reg.check(r, ids3(bytes32(0), c, b));
        assertVerdict(v, T.Verdict.Satisfied);
        (v,) = reg.check(r, ids3(bytes32(0), c, c));
        assertVerdict(v, T.Verdict.NotSatisfied);

        r.combinator = T.Combinator.KOf;
        r.k = 2;
        (v,) = reg.check(r, ids3(a, b, c));
        assertVerdict(v, T.Verdict.Satisfied);
        (v,) = reg.check(r, ids3(a, c, c));
        assertVerdict(v, T.Verdict.NotSatisfied);
        r.k = 3;
        (v,) = reg.check(r, ids3(a, b, c));
        assertVerdict(v, T.Verdict.NotSatisfied);
        // the id of a requirement is the hash of its canonical ABI encoding
        assertEq(reg.requirementId(r), keccak256(abi.encode(r)));
    }

    function test_N32_unknown_counts_toward_neither_side_in_KOf() public {
        bytes32 tSpec = keccak256("toggle spec");
        ToggleSpecRegistry toggle = new ToggleSpecRegistry(tSpec, HASH1);
        T.BindingInput memory i = input(keccak256("t"));
        i.specRegistry = address(toggle);
        i.specId = tSpec;
        bytes32 t = adoptAs(user, i);
        bytes32 a = adoptAs(user, input(keccak256("a")));
        T.Clause memory tc = clause();
        tc.specRegistry = address(toggle);
        tc.specId = tSpec;
        T.RequirementSet memory r;
        r.combinator = T.Combinator.KOf;
        r.k = 2;
        r.clauses = new T.Clause[](2);
        r.clauses[0] = clause();
        r.clauses[1] = tc;
        (T.Verdict v,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Satisfied);
        toggle.setBroken(true);
        (v,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Unknown, "one satisfied plus one unknown could still reach k = 2");
        r.k = 1;
        (v,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Satisfied, "k = 1 is already met without the unknown clause");
        (v,) = reg.check(r, ids2(bytes32(0), t));
        assertVerdict(v, T.Verdict.Unknown);
    }

    function test_subject_and_scope_keys_match_the_reference_derivation() public view {
        // "eip155:31337:0x000000000000000000000000000000000000a6e7"
        string memory ref = ASFKeys.accountRef(block.chainid, agent);
        assertEq(ref, "eip155:31337:0x000000000000000000000000000000000000a6e7");
        assertEq(subjectAgent, keccak256(bytes(ref)));
        assertEq(ASFKeys.refScopeKey("x"), keccak256(bytes('{"ref":"x"}')));
    }
}
