// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {IASFBindingRegistry} from "asf/interfaces/IASFBindingRegistry.sol";
import {NotARegistry} from "./mocks/ToggleSpecRegistry.sol";

/// Test group 2 — Safety Binding creation and lifecycle: attributable adopter, pinned version,
/// no re-creation, validity, interveners, derived bindings, state machine.
contract ASFBindingLifecycleTest is ASFBase {
    // ---------------------------------------------------------------------------- creation

    function test_adopter_is_msg_sender_and_record_is_complete() public {
        T.BindingInput memory i = input(keccak256("b1"));
        bytes32 expected = reg.computeBindingId(user, i);
        vm.prank(user);
        vm.expectEmit(true, true, true, true, address(reg));
        emit IASFBindingRegistry.BindingCreated(expected, user, subjectAgent, scopeWallet, address(specs), specId, 1, HASH1, bytes32(0));
        bytes32 id = reg.adopt(i);
        assertEq(id, expected);
        T.Binding memory b = reg.bindingOf(id);
        assertEq(b.adopter, user, "the adopter is the calling account, never a parameter");
        assertEq(b.subjectKey, subjectAgent);
        assertEq(b.scopeKey, scopeWallet);
        assertEq(b.specRegistry, address(specs));
        assertEq(b.specId, specId);
        assertEq(b.version, 1);
        assertEq(b.contentHash, HASH1);
        assertEq(b.paramsHash, keccak256("params"));
        assertEq(b.paramsLocator, "ipfs://binding-params");
        assertEq(b.authorityRef, keccak256("erc7715:permission:0x01"));
        assertEq(b.enforcement, T.ENFORCED_ACCOUNT | T.ENFORCED_CONTRACT);
        assertEq(b.createdAt, uint64(block.timestamp));
        assertEq(uint8(b.state), uint8(T.BindingState.Active));
        assertEq(b.restrictions, 0);
        assertEq(b.responseRef, bytes32(0));
        assertEq(b.depth, 0);
        // indexed under (subject, adopter) and (scope, adopter)
        assertEq(reg.countBySubject(subjectAgent, user), 1);
        assertEq(reg.bindingsBySubject(subjectAgent, user, 0, 10)[0], id);
        assertEq(reg.countByScope(scopeWallet, user), 1);
        assertEq(reg.bindingsByScope(scopeWallet, user, 0, 0)[0], id);
        // the same declaration by a third party is a different record under a different adopter key
        assertEq(reg.countBySubject(subjectAgent, rando), 0);
        bytes32 other = adoptAs(rando, i);
        assertTrue(other != id, "a stranger cannot produce the principal's binding id");
        assertEq(reg.bindingOf(other).adopter, rando);
        assertEq(reg.countBySubject(subjectAgent, user), 1, "the principal's index is untouched");
    }

    function test_N08_spec_registry_without_interface_reverts() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.specRegistry = address(new NotARegistry());
        vm.prank(user);
        vm.expectRevert(ASFErrors.SpecRegistryNotSupported.selector);
        reg.adopt(i);
        i.specRegistry = address(0xDEAD); // no code at all
        vm.prank(user);
        vm.expectRevert(ASFErrors.SpecRegistryNotSupported.selector);
        reg.adopt(i);
    }

    function test_N09_unknown_version_reverts() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.version = 2;
        vm.prank(user);
        vm.expectRevert(ASFErrors.UnknownVersion.selector);
        reg.adopt(i);
        i.version = 1;
        i.specId = keccak256("ghost");
        vm.prank(user);
        vm.expectRevert(ASFErrors.UnknownVersion.selector);
        reg.adopt(i);
    }

    function test_N10_content_hash_mismatch_reverts() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.contentHash = HASH2;
        vm.prank(user);
        vm.expectRevert(ASFErrors.ContentHashMismatch.selector);
        reg.adopt(i);
        i.contentHash = bytes32(0);
        vm.prank(user);
        vm.expectRevert(ASFErrors.ContentHashMismatch.selector);
        reg.adopt(i);
    }

    function test_N11_no_re_creation_even_after_termination() public {
        T.BindingInput memory i = input(keccak256("b"));
        bytes32 id = adoptAs(user, i);
        vm.prank(user);
        vm.expectRevert(ASFErrors.BindingExists.selector);
        reg.adopt(i);
        vm.prank(user);
        reg.suspend(id, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.prank(user);
        vm.expectRevert(ASFErrors.BindingExists.selector);
        reg.adopt(i);
        vm.prank(user);
        reg.terminate(id, bytes32(0));
        vm.prank(user);
        vm.expectRevert(ASFErrors.BindingExists.selector);
        reg.adopt(i); // a terminated record is never reset; a fresh adoption needs a fresh salt
        i.salt = keccak256("b2");
        assertTrue(adoptAs(user, i) != id);
    }

    function test_N12_malformed_validity_reverts() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.validUntil = uint64(block.timestamp); // exclusive end at creation = already expired
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidValidity.selector);
        reg.adopt(i);
        i.validUntil = uint64(block.timestamp - 1);
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidValidity.selector);
        reg.adopt(i);
        i.validFrom = uint64(block.timestamp + 20 days);
        i.validUntil = uint64(block.timestamp + 10 days);
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidValidity.selector);
        reg.adopt(i);
    }

    function test_backdated_validFrom_is_recorded_but_adoption_starts_at_creation() public {
        T.BindingInput memory i = input(keccak256("b"));
        i.validFrom = uint64(block.timestamp - 30 days);
        bytes32 id = adoptAs(user, i);
        T.Binding memory b = reg.bindingOf(id);
        assertEq(b.validFrom, uint64(block.timestamp - 30 days), "the declaration is kept as made");
        assertEq(b.createdAt, uint64(block.timestamp), "but the adoption exists only from here");
    }

    function test_N13_intervener_rules() public {
        T.BindingInput memory i = input(keccak256("b"));
        // zero account
        i = withGuardian(i, T.RIGHT_SUSPEND);
        i.interveners[0].account = address(0);
        vm.prank(user);
        vm.expectRevert(ASFErrors.ZeroIntervener.selector);
        reg.adopt(i);
        // the adopter listed as its own intervener
        i.interveners[0].account = user;
        vm.prank(user);
        vm.expectRevert(ASFErrors.DuplicateIntervener.selector);
        reg.adopt(i);
        // rights out of range
        i.interveners[0].account = guardian;
        i.interveners[0].rights = 0;
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidRights.selector);
        reg.adopt(i);
        i.interveners[0].rights = 8;
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidRights.selector);
        reg.adopt(i);
        // duplicate account
        T.Intervener[] memory two = new T.Intervener[](2);
        two[0] = T.Intervener(guardian, T.RIGHT_SUSPEND);
        two[1] = T.Intervener(guardian, T.RIGHT_TERMINATE);
        i.interveners = two;
        vm.prank(user);
        vm.expectRevert(ASFErrors.DuplicateIntervener.selector);
        reg.adopt(i);
        // too many
        T.Intervener[] memory many = new T.Intervener[](17);
        for (uint256 k = 0; k < 17; k++) many[k] = T.Intervener(address(uint160(0x1000 + k)), T.RIGHT_SUSPEND);
        i.interveners = many;
        vm.prank(user);
        vm.expectRevert(ASFErrors.TooManyInterveners.selector);
        reg.adopt(i);
    }

    // ---------------------------------------------------------------------------- lifecycle

    function test_state_machine_happy_path_with_events() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.prank(user);
        vm.expectEmit(true, false, false, true, address(reg));
        emit IASFBindingRegistry.BindingStateChanged(id, T.BindingState.Active, T.BindingState.Suspended, T.RESTRICT_NO_NEW_RISK, keccak256("response-1"), user, keccak256("incident-1"));
        reg.suspend(id, T.RESTRICT_NO_NEW_RISK, keccak256("response-1"), keccak256("incident-1"));
        T.Binding memory b = reg.bindingOf(id);
        assertEq(uint8(b.state), uint8(T.BindingState.Suspended));
        assertEq(b.restrictions, T.RESTRICT_NO_NEW_RISK);
        assertEq(b.responseRef, keccak256("response-1"));

        vm.warp(block.timestamp + 1 hours);
        vm.prank(user);
        reg.resume(id, keccak256("resolved"));
        b = reg.bindingOf(id);
        assertEq(uint8(b.state), uint8(T.BindingState.Active));
        assertEq(b.restrictions, 0, "resume clears the response requirements");
        assertEq(b.responseRef, bytes32(0));
        assertEq(b.stateChangedAt, uint64(block.timestamp));

        vm.prank(user);
        reg.terminate(id, keccak256("done"));
        b = reg.bindingOf(id);
        assertEq(uint8(b.state), uint8(T.BindingState.Terminated));
        // the record survives termination: history is kept, only the adoption ended
        assertEq(b.adopter, user);
        assertEq(reg.countBySubject(subjectAgent, user), 1);
    }

    function test_N14_suspend_requires_a_non_empty_in_range_response_set() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidRestriction.selector);
        reg.suspend(id, 0, bytes32(0), bytes32(0));
        vm.prank(user);
        vm.expectRevert(ASFErrors.InvalidRestriction.selector);
        reg.suspend(id, 32, bytes32(0), bytes32(0));
        // several response requirements combine in one suspension
        vm.prank(user);
        reg.suspend(id, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY | T.RESTRICT_ESSENTIAL_ONLY, keccak256("resp"), bytes32(0));
        T.Binding memory b = reg.bindingOf(id);
        assertEq(b.restrictions, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY | T.RESTRICT_ESSENTIAL_ONLY);
        assertEq(b.responseRef, keccak256("resp"));
    }

    function test_N15_strangers_cannot_transition() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.startPrank(rando);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.suspend(id, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.terminate(id, bytes32(0));
        vm.expectRevert(ASFErrors.NotAdopter.selector);
        reg.setParamsLocator(id, "ar://hijack");
        vm.stopPrank();
        assertEq(reg.rightsOf(id, rando), 0);
        assertEq(reg.rightsOf(id, user), T.RIGHT_ALL);
    }

    function test_N16_intervener_rights_are_exactly_the_granted_ones() public {
        bytes32 id = adoptAs(user, withGuardian(input(keccak256("b")), T.RIGHT_SUSPEND));
        assertEq(reg.rightsOf(id, guardian), T.RIGHT_SUSPEND);
        assertEq(reg.intervenersOf(id).length, 1);
        vm.prank(guardian);
        reg.suspend(id, T.RESTRICT_DERISK_ONLY, bytes32(0), keccak256("alert"));
        // a suspend-only guardian can neither resume nor terminate
        vm.prank(guardian);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(id, bytes32(0));
        vm.prank(guardian);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.terminate(id, bytes32(0));
        // the adopter resumes
        vm.prank(user);
        reg.resume(id, bytes32(0));
        assertEq(uint8(reg.bindingOf(id).state), uint8(T.BindingState.Active));
    }

    function test_N17_invalid_transitions_revert() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.startPrank(user);
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.resume(id, bytes32(0)); // not suspended
        reg.suspend(id, T.RESTRICT_SHRINK, bytes32(0), bytes32(0));
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.suspend(id, T.RESTRICT_SHRINK, bytes32(0), bytes32(0)); // already suspended
        reg.terminate(id, bytes32(0));
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.suspend(id, T.RESTRICT_SHRINK, bytes32(0), bytes32(0));
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.resume(id, bytes32(0));
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.terminate(id, bytes32(0));
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.setParamsLocator(id, "ar://late");
        vm.stopPrank();
    }

    function test_N18_unknown_binding_reverts() public {
        bytes32 ghost = keccak256("ghost");
        vm.expectRevert(ASFErrors.UnknownBinding.selector);
        reg.bindingOf(ghost);
        vm.expectRevert(ASFErrors.UnknownBinding.selector);
        reg.intervenersOf(ghost);
        vm.prank(user);
        vm.expectRevert(ASFErrors.UnknownBinding.selector);
        reg.suspend(ghost, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        assertEq(reg.rightsOf(ghost, user), 0);
    }

    function test_params_locator_update_keeps_hash() public {
        bytes32 id = adoptAs(user, input(keccak256("b")));
        vm.prank(user);
        reg.setParamsLocator(id, "ar://moved");
        T.Binding memory b = reg.bindingOf(id);
        assertEq(b.paramsLocator, "ar://moved");
        assertEq(b.paramsHash, keccak256("params"));
    }

    // ---------------------------------------------------------------------- derived bindings

    function test_derived_binding_pins_the_same_version_and_inherits_depth() public {
        T.BindingInput memory p = input(keccak256("parent"));
        p.validUntil = uint64(block.timestamp + 30 days);
        bytes32 parent = adoptAs(user, p);
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = parent;
        c.validUntil = uint64(block.timestamp + 10 days);
        c.subjectKey = keccak256("sub-agent");
        bytes32 child = adoptAs(agent, c);
        T.Binding memory b = reg.bindingOf(child);
        assertEq(b.parentBindingId, parent);
        assertEq(b.depth, 1);
        (T.Verdict v,,) = reg.checkBinding(child, clause());
        assertVerdict(v, T.Verdict.Satisfied);
    }

    function test_N19_parent_must_be_active() public {
        bytes32 parent = adoptAs(user, input(keccak256("parent")));
        vm.prank(user);
        reg.suspend(parent, T.RESTRICT_FULL_STOP, bytes32(0), bytes32(0));
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = parent;
        vm.prank(agent);
        vm.expectRevert(ASFErrors.ParentNotActive.selector);
        reg.adopt(c);
        c.parentBindingId = keccak256("ghost");
        vm.prank(agent);
        vm.expectRevert(ASFErrors.ParentNotActive.selector);
        reg.adopt(c);
    }

    function test_N20_parent_must_pin_the_same_specification_version() public {
        vm.prank(publisher);
        specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
        bytes32 parent = adoptAs(user, input(keccak256("parent")));
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = parent;
        c.version = 2;
        c.contentHash = HASH2;
        vm.prank(agent);
        vm.expectRevert(ASFErrors.ParentMismatch.selector);
        reg.adopt(c);
    }

    function test_N21_child_window_cannot_exceed_the_parent() public {
        T.BindingInput memory p = input(keccak256("parent"));
        p.validUntil = uint64(block.timestamp + 10 days);
        bytes32 parent = adoptAs(user, p);
        T.BindingInput memory c = input(keccak256("child"));
        c.parentBindingId = parent;
        c.validUntil = 0; // open-ended child under a bounded parent
        vm.prank(agent);
        vm.expectRevert(ASFErrors.ParentWindowExceeded.selector);
        reg.adopt(c);
        c.validUntil = uint64(block.timestamp + 11 days);
        vm.prank(agent);
        vm.expectRevert(ASFErrors.ParentWindowExceeded.selector);
        reg.adopt(c);
        c.validUntil = uint64(block.timestamp + 10 days); // equal is allowed
        adoptAs(agent, c);
    }

    function test_N22_depth_is_bounded() public {
        bytes32 prev = adoptAs(user, input(keccak256("root")));
        for (uint256 d = 1; d <= T.MAX_DEPTH; d++) {
            T.BindingInput memory c = input(keccak256(abi.encode("level", d)));
            c.parentBindingId = prev;
            prev = adoptAs(user, c);
            assertEq(reg.bindingOf(prev).depth, uint8(d));
        }
        T.BindingInput memory tooDeep = input(keccak256("too deep"));
        tooDeep.parentBindingId = prev;
        vm.prank(user);
        vm.expectRevert(ASFErrors.DepthExceeded.selector);
        reg.adopt(tooDeep);
    }

    function test_supports_interface() public view {
        assertTrue(reg.supportsInterface(0x01ffc9a7));
        assertTrue(reg.supportsInterface(type(IASFBindingRegistry).interfaceId));
        assertFalse(reg.supportsInterface(0xffffffff));
    }

    function test_index_pagination() public {
        for (uint256 k = 0; k < 5; k++) adoptAs(user, input(keccak256(abi.encode("p", k))));
        assertEq(reg.countBySubject(subjectAgent, user), 5);
        assertEq(reg.bindingsBySubject(subjectAgent, user, 0, 2).length, 2);
        assertEq(reg.bindingsBySubject(subjectAgent, user, 4, 2).length, 1);
        assertEq(reg.bindingsBySubject(subjectAgent, user, 5, 2).length, 0);
        assertEq(reg.bindingsBySubject(subjectAgent, user, 0, 0).length, 5, "limit 0 = all");
        assertEq(reg.bindingsByScope(scopeWallet, user, 1, 10).length, 4);
    }
}
