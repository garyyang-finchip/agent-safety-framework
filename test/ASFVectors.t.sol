// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {IASFSpecificationRegistry} from "asf/interfaces/IASFSpecificationRegistry.sol";
import {IASFBindingRegistry} from "asf/interfaces/IASFBindingRegistry.sol";

/// Test group 6 — ethers <-> solc cross-checks of the vectors under assets/erc-asf/vectors.
contract ASFVectorsTest is ASFBase {
    string constant V = "assets/erc-asf/vectors/";

    function read(string memory f) internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/", V, f));
    }

    function test_interface_ids_match_the_vectors() public view {
        string memory j = read("interface-ids.json");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IASFSpecificationRegistry")), type(IASFSpecificationRegistry).interfaceId, "spec registry id");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IASFBindingRegistry")), type(IASFBindingRegistry).interfaceId, "binding registry id");
    }

    function test_identifier_hashes() public view {
        string memory j = read("identifiers.json");
        string memory id = "asf:profile:authority/bounded-spend@1";
        assertEq(vm.parseJsonBytes32(j, string.concat('.profileIds["', id, '"]')), keccak256(bytes(id)));
        assertEq(vm.parseJsonUint(j, ".enforcementBits.account"), T.ENFORCED_ACCOUNT);
        assertEq(vm.parseJsonUint(j, ".enforcementBits.collective"), T.ENFORCED_COLLECTIVE);
        assertEq(vm.parseJsonUint(j, ".rightsBits.terminate"), T.RIGHT_TERMINATE);
        assertEq(vm.parseJsonUint(j, '.restrictionBits["derisk-only"]'), T.RESTRICT_DERISK_ONLY);
        assertEq(vm.parseJsonUint(j, '.reason["spec-registry-unavailable"]'), uint8(T.Reason.SpecRegistryUnavailable));
        assertEq(vm.parseJsonUint(j, '.verdict["not-satisfied"]'), uint8(T.Verdict.NotSatisfied));
    }

    function test_keys_match_the_on_chain_derivation() public view {
        string memory j = read("keys.json");
        uint256 chainId = vm.parseJsonUint(j, ".chainId");
        address account = vm.parseJsonAddress(j, ".account");
        assertEq(ASFKeys.accountRef(chainId, account), vm.parseJsonString(j, ".accountRef"));
        assertEq(keccak256(bytes(ASFKeys.accountRef(chainId, account))), vm.parseJsonBytes32(j, ".subjectKey"));
        string memory ref = vm.parseJsonString(j, ".refScope.object.ref");
        assertEq(ASFKeys.refScopeKey(ref), vm.parseJsonBytes32(j, ".refScope.scopeKey"));
        // a multi-member scope is canonicalized off chain; the hash of the given JCS string must match
        assertEq(keccak256(bytes(vm.parseJsonString(j, ".richScope.jcs"))), vm.parseJsonBytes32(j, ".richScope.scopeKey"));
    }

    function test_canonicalization_vector() public view {
        string memory j = read("canonicalization.json");
        assertEq(keccak256(bytes(vm.parseJsonString(j, ".jcs"))), vm.parseJsonBytes32(j, ".contentHash"));
    }

    function test_spec_and_binding_ids_follow_the_abi_encoding() public view {
        string memory s = read("spec-id.json");
        bytes32 specId = keccak256(abi.encode(
            vm.parseJsonUint(s, ".chainId"), vm.parseJsonAddress(s, ".registry"), vm.parseJsonAddress(s, ".publisher"), vm.parseJsonBytes32(s, ".salt")));
        assertEq(specId, vm.parseJsonBytes32(s, ".specId"));

        string memory b = read("binding-id.json");
        bytes32 bindingId = keccak256(abi.encode(
            vm.parseJsonUint(b, ".chainId"),
            vm.parseJsonAddress(b, ".registry"),
            vm.parseJsonAddress(b, ".adopter"),
            vm.parseJsonBytes32(b, ".subjectKey"),
            vm.parseJsonBytes32(b, ".scopeKey"),
            vm.parseJsonAddress(b, ".specRegistry"),
            vm.parseJsonBytes32(b, ".specId"),
            uint32(vm.parseJsonUint(b, ".version")),
            vm.parseJsonBytes32(b, ".salt")));
        assertEq(bindingId, vm.parseJsonBytes32(b, ".bindingId"));
        assertEq(vm.parseJsonBytes32(b, ".specId"), specId, "the binding vector pins the spec vector");
    }

    function test_requirement_id_matches_the_registry() public view {
        string memory j = read("requirement.json");
        T.RequirementSet memory r;
        r.combinator = T.Combinator(uint8(vm.parseJsonUint(j, ".requirement.combinator")));
        r.k = uint16(vm.parseJsonUint(j, ".requirement.k"));
        r.clauses = new T.Clause[](3);
        for (uint256 i = 0; i < 3; i++) {
            string memory p = string.concat(".requirement.clauses[", vm.toString(i), "]");
            uint256[] memory vs = vm.parseJsonUintArray(j, string.concat(p, ".versions"));
            uint32[] memory versions = new uint32[](vs.length);
            for (uint256 k = 0; k < vs.length; k++) versions[k] = uint32(vs[k]);
            uint256 ni = vm.parseJsonUint(j, string.concat(p, ".intervenerCount"));
            T.Intervener[] memory iv = new T.Intervener[](ni);
            for (uint256 k = 0; k < ni; k++) {
                string memory q = string.concat(p, ".interveners[", vm.toString(k), "]");
                iv[k] = T.Intervener({
                    account: vm.parseJsonAddress(j, string.concat(q, ".account")),
                    rights: uint8(vm.parseJsonUint(j, string.concat(q, ".rights")))
                });
            }
            r.clauses[i] = T.Clause({
                specRegistry: vm.parseJsonAddress(j, string.concat(p, ".specRegistry")),
                specId: vm.parseJsonBytes32(j, string.concat(p, ".specId")),
                versions: versions,
                adopter: vm.parseJsonAddress(j, string.concat(p, ".adopter")),
                subjectKey: vm.parseJsonBytes32(j, string.concat(p, ".subjectKey")),
                scopeKey: vm.parseJsonBytes32(j, string.concat(p, ".scopeKey")),
                enforcement: uint16(vm.parseJsonUint(j, string.concat(p, ".enforcement"))),
                interveners: iv
            });
        }
        assertEq(abi.encode(r), vm.parseJsonBytes(j, ".encoded"), "abi encoding");
        assertEq(reg.requirementId(r), vm.parseJsonBytes32(j, ".requirementId"), "requirement id");
    }
}
