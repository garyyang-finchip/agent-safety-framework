// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFTypes as T} from "asf/ASFTypes.sol";
import {IASFSpecificationRegistry} from "asf/interfaces/IASFSpecificationRegistry.sol";

/// Test double: a specification registry that answers like the reference one for a single version and
/// that can be switched into a failing state (supportsInterface reverts) to exercise the Unknown verdict.
contract ToggleSpecRegistry {
    bool public broken;
    bytes32 public specId;
    bytes32 public contentHash;

    constructor(bytes32 specId_, bytes32 contentHash_) {
        specId = specId_;
        contentHash = contentHash_;
    }

    function setBroken(bool b) external { broken = b; }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        require(!broken, "toggle: broken");
        return interfaceId == 0x01ffc9a7 || interfaceId == type(IASFSpecificationRegistry).interfaceId;
    }

    function versionOf(bytes32 id, uint32 version) external view returns (T.SpecificationVersion memory v) {
        require(id == specId && version == 1, "toggle: unknown version");
        v.contentHash = contentHash;
        v.locator = "ipfs://toggle";
        v.publishedAt = 1;
    }
}

/// Test double: a contract that is not a specification registry at all.
contract NotARegistry {
    function supportsInterface(bytes4) external pure returns (bool) { return false; }
}
