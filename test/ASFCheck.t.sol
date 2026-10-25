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
        // required interveners are checked after enforcement and before the ancestor walk
        c.enforcement = T.ENFORCED_COLLECTIVE;
        c.interveners = requiring(guardian, T.RIGHT_SUSPEND);
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.EnforcementMismatch);
        c.enforcement = 0;
        (, r,) = reg.checkBinding(id, c);
        assertReason(r, T.Reason.IntervenerMismatch);
    }

    function requiring(address account, uint8 rights) internal pure returns (T.Intervener[] memory iv) {
        iv = new T.Intervener[](1);
        iv[0] = T.Intervener({account: account, rights: rights});
    }

    function test_N50_response_sets_in_force_are_the_union_of_the_chain_and_empty_when_the_chain_is_broken() public {
        bytes32 root = adoptAs(user, withGuardian(input(keccak256("root")), T.RIGHT_SUSPEND | T.RIGHT_RESUME));
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = root;
        bytes32 child = adoptAs(agent, c);
        T.BindingInput memory g = input(keccak256("grandchild"));
        g.parentBindingId = child;
        bytes32 grandchild = adoptAs(rando, g);

        // the root's response set reaches every descendant unchanged
        vm.prank(guardian);
        reg.suspend(root, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, bytes32(0), bytes32(0));
        (, T.Reason r, uint8 x) = reg.checkBinding(grandchild, clause());
        assertReason(r, T.Reason.ParentNotSatisfied);
        assertEq(x, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY);

        // a suspension of the child adds its own requirements: the sets combine, the reason is the child's own state
        vm.prank(agent);
        reg.suspend(child, T.RESTRICT_ESSENTIAL_ONLY, bytes32(0), bytes32(0));
        (, r, x) = reg.checkBinding(child, clause());
        assertReason(r, T.Reason.Suspended);
        assertEq(x, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY | T.RESTRICT_ESSENTIAL_ONLY, "child set united with the root's");
        (, r, x) = reg.checkBinding(grandchild, clause());
        assertReason(r, T.Reason.ParentNotSatisfied);
        assertEq(x, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY | T.RESTRICT_ESSENTIAL_ONLY, "grandchild sees both ancestors");

        // a full stop anywhere in the chain is in the union, so it dominates for consumers
        vm.prank(agent);
        reg.resume(child, bytes32(0));
        vm.prank(agent);
        reg.suspend(child, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        (, r, x) = reg.checkBinding(grandchild, clause());
        assertEq(x & T.RESTRICT_FULL_STOP, T.RESTRICT_FULL_STOP);
        assertEq(x & T.RESTRICT_DERISK_ONLY, T.RESTRICT_DERISK_ONLY);

        // a terminated record in the chain empties the set: a chain that is not in force keeps no path open
        vm.prank(agent);
        reg.terminate(child, bytes32(0));
        (, r, x) = reg.checkBinding(grandchild, clause());
        assertReason(r, T.Reason.ParentNotSatisfied);
        assertEq(x, 0, "the root is still suspended de-risk only, but the parent is terminated");
        (, r, x) = reg.checkBinding(child, clause());
        assertReason(r, T.Reason.Terminated);
        assertEq(x, 0);

        // an expired record in the chain empties the set as well
        bytes32 shortRoot;
        {
            T.BindingInput memory sr = input(keccak256("short root"));
            sr.validUntil = uint64(block.timestamp + 1 days);
            shortRoot = adoptAs(user, sr);
            T.BindingInput memory sc = input(keccak256("short child"));
            sc.parentBindingId = shortRoot;
            sc.validUntil = uint64(block.timestamp + 1 days);
            bytes32 shortChild = adoptAs(agent, sc);
            vm.prank(user);
            reg.suspend(shortRoot, T.RESTRICT_DERISK_ONLY, bytes32(0), bytes32(0));
            (, r, x) = reg.checkBinding(shortChild, clause());
            assertReason(r, T.Reason.ParentNotSatisfied);
            assertEq(x, T.RESTRICT_DERISK_ONLY);
            vm.warp(block.timestamp + 1 days);
            (, r, x) = reg.checkBinding(shortChild, clause());
            assertReason(r, T.Reason.Expired);
            assertEq(x, 0);
        }
    }

    function test_N51_required_interveners_must_be_named_with_at_least_the_required_rights() public {
        bytes32 plain = adoptAs(user, input(keccak256("plain")));
        bytes32 guarded = adoptAs(user, withGuardian(input(keccak256("guarded")), T.RIGHT_SUSPEND));
        T.Clause memory c = clause();

        // a named account must be an intervener with at least the required rights
        c.interveners = requiring(guardian, T.RIGHT_SUSPEND);
        (T.Verdict v, T.Reason r,) = reg.checkBinding(plain, c);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.IntervenerMismatch);
        (v, r,) = reg.checkBinding(guarded, c);
        assertVerdict(v, T.Verdict.Satisfied);
        c.interveners = requiring(guardian, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        (, r,) = reg.checkBinding(guarded, c);
        assertReason(r, T.Reason.IntervenerMismatch);

        // the adopter is never an intervener: requiring it fails, so the requirement cannot be met by self-control
        c.interveners = requiring(user, T.RIGHT_SUSPEND);
        (, r,) = reg.checkBinding(guarded, c);
        assertReason(r, T.Reason.IntervenerMismatch);

        // a zero account is not a wildcard: it is a malformed requirement (independence from the adopter cannot
        // be established by "some intervener", since the adopter chooses them all)
        c.interveners = requiring(address(0), T.RIGHT_SUSPEND);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.checkBinding(guarded, c);

        // several required interveners: all must be present
        T.Intervener[] memory two = new T.Intervener[](2);
        two[0] = T.Intervener({account: guardian, rights: T.RIGHT_SUSPEND});
        two[1] = T.Intervener({account: rando, rights: T.RIGHT_RESUME});
        c.interveners = two;
        (, r,) = reg.checkBinding(guarded, c);
        assertReason(r, T.Reason.IntervenerMismatch);
        T.BindingInput memory i = input(keccak256("two"));
        i.interveners = two;
        bytes32 both = adoptAs(user, i);
        (v,,) = reg.checkBinding(both, c);
        assertVerdict(v, T.Verdict.Satisfied);

        // malformed required rights are rejected as a malformed requirement
        c.interveners = requiring(guardian, 0);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.checkBinding(guarded, c);
        c.interveners = requiring(guardian, 8);
        vm.expectRevert(ASFErrors.InvalidRequirement.selector);
        reg.requirementId(one(c));
    }

    function test_N57_a_clause_that_names_interveners_closes_the_resume_right() public {
        T.Clause memory c = clause();
        c.interveners = requiring(guardian, T.RIGHT_SUSPEND);

        // the binding names the required guardian and, in addition, an account of the adopter's choosing with
        // the resume right: that account could lift the guardian's suspension, so the clause is not met
        T.Intervener[] memory iv = new T.Intervener[](2);
        iv[0] = T.Intervener({account: guardian, rights: T.RIGHT_SUSPEND});
        iv[1] = T.Intervener({account: rando, rights: T.RIGHT_RESUME});
        T.BindingInput memory i = input(keccak256("puppet"));
        i.interveners = iv;
        bytes32 puppet = adoptAs(user, i);
        (T.Verdict v, T.Reason r,) = reg.checkBinding(puppet, c);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(r, T.Reason.IntervenerMismatch);

        // extra interveners without the resume right are allowed: they can only stop
        iv[1] = T.Intervener({account: rando, rights: T.RIGHT_SUSPEND | T.RIGHT_TERMINATE});
        i = input(keccak256("extra-stopper"));
        i.interveners = iv;
        (v,,) = reg.checkBinding(adoptAs(user, i), c);
        assertVerdict(v, T.Verdict.Satisfied);

        // a named account may hold more rights than required, resume included
        bytes32 richer = adoptAs(user, withGuardian(input(keccak256("richer")), T.RIGHT_ALL));
        (v,,) = reg.checkBinding(richer, c);
        assertVerdict(v, T.Verdict.Satisfied);

        // the escalation shape: the clause names the guardian (suspend) and an executor (resume); the binding
        // grants exactly that, so the executor, and only the executor, can lift the guardian's stop
        T.Intervener[] memory two = new T.Intervener[](2);
        two[0] = T.Intervener({account: guardian, rights: T.RIGHT_SUSPEND});
        two[1] = T.Intervener({account: rando, rights: T.RIGHT_RESUME});
        c.interveners = two;
        (v,,) = reg.checkBinding(puppet, c);
        assertVerdict(v, T.Verdict.Satisfied, "the same binding is fine once the clause names the resume holder");
        vm.prank(guardian);
        reg.suspend(puppet, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(user);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(puppet, bytes32(0));
        vm.prank(rando);
        reg.resume(puppet, bytes32(0));
        (v,,) = reg.checkBinding(puppet, c);
        assertVerdict(v, T.Verdict.Satisfied);

        // a clause without required interveners does not constrain the resume right
        (v,,) = reg.checkBinding(puppet, clause());
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
        (T.Verdict all,,) = reg.check(one(c), ids1(id));
        assertVerdict(all, T.Verdict.Unknown);
        T.RequirementSet memory anyOf = one(c);
        anyOf.combinator = T.Combinator.Any;
        (T.Verdict any,,) = reg.check(anyOf, ids1(id));
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
        (T.Verdict v, T.Reason[] memory reasons,) = reg.check(r, ids3(a, b, c));
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[2], T.Reason.Suspended);
        (v,,) = reg.check(r, ids3(a, b, a));
        assertVerdict(v, T.Verdict.Satisfied);

        r.combinator = T.Combinator.Any;
        (v,,) = reg.check(r, ids3(bytes32(0), c, b));
        assertVerdict(v, T.Verdict.Satisfied);
        (v,,) = reg.check(r, ids3(bytes32(0), c, c));
        assertVerdict(v, T.Verdict.NotSatisfied);

        r.combinator = T.Combinator.KOf;
        r.k = 2;
        (v,,) = reg.check(r, ids3(a, b, c));
        assertVerdict(v, T.Verdict.Satisfied);
        (v,,) = reg.check(r, ids3(a, c, c));
        assertVerdict(v, T.Verdict.NotSatisfied);
        r.k = 3;
        (v,,) = reg.check(r, ids3(a, b, c));
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
        (T.Verdict v,,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Satisfied);
        toggle.setBroken(true);
        (v,,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Unknown, "one satisfied plus one unknown could still reach k = 2");
        r.k = 1;
        (v,,) = reg.check(r, ids2(a, t));
        assertVerdict(v, T.Verdict.Satisfied, "k = 1 is already met without the unknown clause");
        (v,,) = reg.check(r, ids2(bytes32(0), t));
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
