// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {IASFSpecificationRegistry} from "asf/interfaces/IASFSpecificationRegistry.sol";

/// Test group 1 — Safety Specification registry: identity, versions, publisher control, deprecation.
contract ASFSpecificationRegistryTest is ASFBase {
    function test_registration_is_attributable_and_deterministic() public view {
        assertEq(specId, specs.computeSpecId(publisher, SALT));
        assertTrue(specs.specificationExists(specId));
        assertEq(specs.publisherOf(specId), publisher);
        assertEq(specs.latestVersion(specId), 1);
        T.SpecificationVersion memory v = specs.versionOf(specId, 1);
        assertEq(v.contentHash, HASH1);
        assertEq(v.locator, "ipfs://spec-v1");
        assertEq(v.requiredProfiles.length, 1);
        assertFalse(v.deprecated);
        // a different publisher with the same salt gets a different id: nobody can squat another's name
        assertTrue(specs.computeSpecId(rando, SALT) != specId);
    }

    function test_N01_zero_content_hash_reverts() public {
        vm.prank(publisher);
        vm.expectRevert(ASFErrors.ZeroContentHash.selector);
        specs.registerSpecification(keccak256("x"), bytes32(0), "ipfs://x", new bytes32[](0));
    }

    function test_N02_same_salt_twice_reverts() public {
        vm.prank(publisher);
        vm.expectRevert(ASFErrors.SpecificationExists.selector);
        specs.registerSpecification(SALT, HASH2, "ipfs://again", new bytes32[](0));
    }

    function test_N03_publishVersion_by_non_publisher_reverts() public {
        vm.prank(rando);
        vm.expectRevert(ASFErrors.NotPublisher.selector);
        specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
    }

    function test_versions_are_immutable_and_sequential() public {
        vm.prank(publisher);
        uint32 v2 = specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
        assertEq(v2, 2);
        assertEq(specs.latestVersion(specId), 2);
        assertEq(specs.versionOf(specId, 1).contentHash, HASH1, "v1 unchanged by v2");
        assertEq(specs.versionOf(specId, 2).contentHash, HASH2);
    }

    function test_locator_changes_hash_does_not() public {
        vm.prank(publisher);
        specs.setLocator(specId, 1, "ar://moved");
        T.SpecificationVersion memory v = specs.versionOf(specId, 1);
        assertEq(v.locator, "ar://moved");
        assertEq(v.contentHash, HASH1);
    }

    function test_N04_setLocator_unknown_version_reverts() public {
        vm.prank(publisher);
        vm.expectRevert(ASFErrors.UnknownVersion.selector);
        specs.setLocator(specId, 2, "ar://nope");
        vm.prank(publisher);
        vm.expectRevert(ASFErrors.UnknownVersion.selector);
        specs.setLocator(specId, 0, "ar://nope");
    }

    function test_N05_deprecate_by_non_publisher_reverts_and_deprecation_is_informative() public {
        vm.prank(rando);
        vm.expectRevert(ASFErrors.NotPublisher.selector);
        specs.deprecateVersion(specId, 1, keccak256("why"));
        vm.prank(publisher);
        specs.deprecateVersion(specId, 1, keccak256("why"));
        assertTrue(specs.versionOf(specId, 1).deprecated);
        assertEq(specs.versionOf(specId, 1).contentHash, HASH1, "content untouched");
        // an adoption of the deprecated version is still possible and still checks: the publisher's
        // opinion is a signal to consumers, not a change of anybody's accepted conditions
        bytes32 id = adoptAs(user, input(keccak256("s")));
        (T.Verdict v,,) = reg.checkBinding(id, clause());
        assertVerdict(v, T.Verdict.Satisfied);
    }

    function test_N06_frozen_specification_rejects_every_write() public {
        vm.prank(publisher);
        specs.setPublisher(specId, address(0));
        assertEq(specs.publisherOf(specId), address(0));
        vm.startPrank(publisher);
        vm.expectRevert(ASFErrors.SpecificationFrozen.selector);
        specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
        vm.expectRevert(ASFErrors.SpecificationFrozen.selector);
        specs.setLocator(specId, 1, "ar://x");
        vm.expectRevert(ASFErrors.SpecificationFrozen.selector);
        specs.deprecateVersion(specId, 1, bytes32(0));
        vm.expectRevert(ASFErrors.SpecificationFrozen.selector);
        specs.setPublisher(specId, publisher);
        vm.stopPrank();
        // the frozen version remains readable and adoptable
        assertEq(specs.versionOf(specId, 1).contentHash, HASH1);
    }

    function test_N07_unknown_specification_reverts_on_reads() public {
        bytes32 ghost = keccak256("ghost");
        vm.expectRevert(ASFErrors.UnknownSpecification.selector);
        specs.publisherOf(ghost);
        vm.expectRevert(ASFErrors.UnknownSpecification.selector);
        specs.latestVersion(ghost);
        vm.expectRevert(ASFErrors.UnknownSpecification.selector);
        specs.versionOf(ghost, 1);
        assertFalse(specs.specificationExists(ghost));
    }

    function test_publisher_transfer() public {
        vm.prank(publisher);
        specs.setPublisher(specId, rando);
        assertEq(specs.publisherOf(specId), rando);
        vm.prank(publisher);
        vm.expectRevert(ASFErrors.NotPublisher.selector);
        specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0));
        vm.prank(rando);
        assertEq(specs.publishVersion(specId, HASH2, "ipfs://spec-v2", new bytes32[](0)), 2);
    }

    function test_supports_interface() public view {
        assertTrue(specs.supportsInterface(0x01ffc9a7));
        assertTrue(specs.supportsInterface(type(IASFSpecificationRegistry).interfaceId));
        assertFalse(specs.supportsInterface(0xffffffff));
    }
}
