// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {ASFSpecificationRegistry} from "asf/ASFSpecificationRegistry.sol";
import {ASFBindingRegistry} from "asf/ASFBindingRegistry.sol";
import {IASFSpecificationRegistry} from "asf/interfaces/IASFSpecificationRegistry.sol";
import {IASFBindingRegistry} from "asf/interfaces/IASFBindingRegistry.sol";

/// Shared fixture: two registries, one published specification (v1), helper builders.
abstract contract ASFBase is Test {
    /// Block time at the start of every test (the fixture warps to it in setUp). Tests that move time derive
    /// their targets from this constant rather than from `block.timestamp`, which the via-IR pipeline may treat
    /// as invariant within a call.
    uint256 internal constant START = 1_760_000_000;

    ASFSpecificationRegistry specs;
    ASFBindingRegistry reg;

    address publisher = address(0x9B1);
    address user = address(0xA11CE);      // principal: adopts for an assistant on its wallet
    address agent = address(0xA6E7);      // the assistant
    address guardian = address(0x6A2D);   // intervener
    address rando = address(0xBAD);

    bytes32 SALT = keccak256("personal-assistant-safety");
    bytes32 HASH1 = keccak256("spec v1 content");
    bytes32 HASH2 = keccak256("spec v2 content");
    bytes32 specId;
    bytes32 subjectAgent;
    bytes32 scopeWallet;

    function setUp() public virtual {
        vm.warp(START);
        specs = new ASFSpecificationRegistry();
        reg = new ASFBindingRegistry();
        bytes32[] memory profiles = new bytes32[](1);
        profiles[0] = keccak256("asf:profile:authority/bounded-spend@1");
        vm.prank(publisher);
        specId = specs.registerSpecification(SALT, HASH1, "ipfs://spec-v1", profiles);
        subjectAgent = ASFKeys.accountSubjectKey(agent);
        scopeWallet = ASFKeys.refScopeKey(ASFKeys.accountRef(block.chainid, user));
    }

    // ------------------------------------------------------------------------------ builders

    function input(bytes32 salt) internal view returns (T.BindingInput memory i) {
        i.subjectKey = subjectAgent;
        i.scopeKey = scopeWallet;
        i.specRegistry = address(specs);
        i.specId = specId;
        i.version = 1;
        i.contentHash = HASH1;
        i.paramsHash = keccak256("params");
        i.paramsLocator = "ipfs://binding-params";
        i.authorityRef = keccak256("erc7715:permission:0x01");
        i.enforcement = T.ENFORCED_ACCOUNT | T.ENFORCED_CONTRACT;
        i.validFrom = 0;
        i.validUntil = 0;
        i.parentBindingId = bytes32(0);
        i.salt = salt;
        i.interveners = new T.Intervener[](0);
    }

    function withGuardian(T.BindingInput memory i, uint8 rights) internal view returns (T.BindingInput memory) {
        T.Intervener[] memory iv = new T.Intervener[](1);
        iv[0] = T.Intervener({account: guardian, rights: rights});
        i.interveners = iv;
        return i;
    }

    function adoptAs(address who, T.BindingInput memory i) internal returns (bytes32 id) {
        vm.prank(who);
        id = reg.adopt(i);
    }

    function clause() internal view returns (T.Clause memory c) {
        c.specRegistry = address(specs);
        c.specId = specId;
        c.versions = new uint32[](0);
        c.adopter = address(0);
        c.subjectKey = bytes32(0);
        c.scopeKey = bytes32(0);
        c.enforcement = 0;
    }

    function clauseFor(address adopter, bytes32 subjectKey, bytes32 scopeKey, uint32 version) internal view returns (T.Clause memory c) {
        c = clause();
        c.adopter = adopter;
        c.subjectKey = subjectKey;
        c.scopeKey = scopeKey;
        if (version != 0) {
            c.versions = new uint32[](1);
            c.versions[0] = version;
        }
    }

    function one(T.Clause memory c) internal pure returns (T.RequirementSet memory r) {
        r.combinator = T.Combinator.All;
        r.k = 0;
        r.clauses = new T.Clause[](1);
        r.clauses[0] = c;
    }

    function ids1(bytes32 a) internal pure returns (bytes32[] memory x) { x = new bytes32[](1); x[0] = a; }
    function ids2(bytes32 a, bytes32 b) internal pure returns (bytes32[] memory x) { x = new bytes32[](2); x[0] = a; x[1] = b; }
    function ids3(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32[] memory x) { x = new bytes32[](3); x[0] = a; x[1] = b; x[2] = c; }

    function assertVerdict(T.Verdict got, T.Verdict want) internal pure {
        assertEq(uint8(got), uint8(want), "verdict");
    }

    function assertVerdict(T.Verdict got, T.Verdict want, string memory why) internal pure {
        assertEq(uint8(got), uint8(want), why);
    }

    function assertReason(T.Reason got, T.Reason want) internal pure {
        assertEq(uint8(got), uint8(want), "reason");
    }
}
