'use strict';
// Canonicalization, identifiers and ABI helpers of the Agent Safety and Security Framework.
const canonicalize = require('canonicalize');
const { keccak256, toUtf8Bytes, AbiCoder, Interface, getAddress } = require('ethers');

/** RFC 8785 canonical JSON string of a document. */
function canonicalString(doc) {
  return canonicalize(doc);
}

/** contentHash / paramsHash / scopeKey / authorityRef = keccak256(UTF-8(JCS(document))). */
function canonicalHash(doc) {
  return keccak256(toUtf8Bytes(canonicalString(doc)));
}

/** profileId / familyId = keccak256(UTF-8(identifier)). */
function idOf(identifier) {
  return keccak256(toUtf8Bytes(identifier));
}

/** Account reference "eip155:<chainId>:<0x + lowercase hex address>" (the on-chain derivation of ASFKeys). */
function accountRef(chainId, address) {
  return `eip155:${chainId}:${getAddress(address).toLowerCase()}`;
}

/** subjectKey = keccak256(UTF-8(subject reference string)). */
function subjectKey(ref) {
  return keccak256(toUtf8Bytes(ref));
}

/** scopeKey = keccak256(UTF-8(JCS(scope object))). */
function scopeKey(scope) {
  return canonicalHash(scope);
}

/** specId = keccak256(abi.encode(chainId, registry, publisher, salt)). */
function specId(chainId, registry, publisher, salt) {
  return keccak256(AbiCoder.defaultAbiCoder().encode(
    ['uint256', 'address', 'address', 'bytes32'], [chainId, registry, publisher, salt]));
}

/** bindingId = keccak256(abi.encode(chainId, registry, adopter, subjectKey, scopeKey, specRegistry, specId, version, salt)). */
function bindingId(chainId, registry, adopter, b) {
  return keccak256(AbiCoder.defaultAbiCoder().encode(
    ['uint256', 'address', 'address', 'bytes32', 'bytes32', 'address', 'bytes32', 'uint32', 'bytes32'],
    [chainId, registry, adopter, b.subjectKey, b.scopeKey, b.specRegistry, b.specId, b.version, b.salt]));
}

const REQUIREMENT_TYPE = 'tuple(uint8 combinator,uint16 k,tuple(address specRegistry,bytes32 specId,uint32[] versions,address adopter,bytes32 subjectKey,bytes32 scopeKey,uint16 enforcement)[] clauses)';

/** ABI encoding of a RequirementSet struct exactly as Solidity's abi.encode(requirement). */
function encodeRequirement(req) {
  return AbiCoder.defaultAbiCoder().encode([REQUIREMENT_TYPE], [[
    req.combinator,
    req.k,
    req.clauses.map((c) => [c.specRegistry, c.specId, c.versions, c.adopter, c.subjectKey, c.scopeKey, c.enforcement]),
  ]]);
}

/** requirementId = keccak256(abi.encode(requirement)). */
function requirementId(req) {
  return keccak256(encodeRequirement(req));
}

/** ERC-165 interface id: XOR of all function selectors of an ABI (excluding supportsInterface). */
function interfaceId(abi) {
  const iface = new Interface(abi);
  let acc = 0n;
  iface.forEachFunction((f) => {
    if (f.name === 'supportsInterface') return;
    acc ^= BigInt(f.selector);
  });
  return '0x' + acc.toString(16).padStart(8, '0');
}

const ENFORCEMENT = { self: 1, account: 2, runtime: 4, custodian: 8, contract: 16, collective: 32 };
const RIGHTS = { suspend: 1, resume: 2, terminate: 4 };
const RESTRICTION = { 'no-new-risk': 1, shrink: 2, 'essential-only': 4, 'derisk-only': 8, 'full-stop': 16 };
const COMBINATOR = { all: 0, any: 1, 'k-of': 2 };
const FAMILIES = [
  'identity-authority',
  'information-privacy',
  'execution-supply-chain',
  'behavior-goals',
  'assets-economic',
  'multi-agent-system',
  'human-public',
  'governance-accountability',
];
const DOMAINS = ['assets-economic', 'information-privacy', 'control-rules', 'credit-eligibility', 'third-party-public'];

/** Bit set from an array of enforcement location names. */
function enforcementMask(locations) {
  return locations.reduce((acc, l) => {
    if (!(l in ENFORCEMENT)) throw new Error(`unknown enforcement location ${l}`);
    return acc | ENFORCEMENT[l];
  }, 0);
}

function rightsMask(rights) {
  return rights.reduce((acc, r) => {
    if (!(r in RIGHTS)) throw new Error(`unknown right ${r}`);
    return acc | RIGHTS[r];
  }, 0);
}

module.exports = {
  canonicalString,
  canonicalHash,
  idOf,
  accountRef,
  subjectKey,
  scopeKey,
  specId,
  bindingId,
  encodeRequirement,
  requirementId,
  interfaceId,
  enforcementMask,
  rightsMask,
  ENFORCEMENT,
  RIGHTS,
  RESTRICTION,
  COMBINATOR,
  FAMILIES,
  DOMAINS,
  REQUIREMENT_TYPE,
};
