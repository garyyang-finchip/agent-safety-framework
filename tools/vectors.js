#!/usr/bin/env node
'use strict';
// Generates the test vectors of the ERC assets (assets/erc-asf/vectors/*.json). The Foundry suite
// (test/ASFVectors.t.sol) reads the same files and checks every value against the Solidity side.
//
//   node tools/vectors.js          (requires `forge build` first for the interface ids)

const fs = require('fs');
const path = require('path');
const C = require('./lib/canonical');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'assets', 'erc-asf', 'vectors');
const ART = path.join(ROOT, 'out');
const EX = path.join(ROOT, 'assets', 'erc-asf', 'examples');

function readArtifact(file, name) {
  const p = path.join(ART, file, `${name}.json`);
  if (!fs.existsSync(p)) throw new Error(`artifact missing: ${p} (run forge build)`);
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}
function write(name, doc) {
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, name), JSON.stringify(doc, null, 2) + '\n');
  console.log(`wrote vectors/${name}`);
}

// ----------------------------------------------------------------------------- interface ids
const specAbi = readArtifact('IASFSpecificationRegistry.sol', 'IASFSpecificationRegistry').abi;
const bindAbi = readArtifact('IASFBindingRegistry.sol', 'IASFBindingRegistry').abi;
write('interface-ids.json', {
  IASFSpecificationRegistry: C.interfaceId(specAbi),
  IASFBindingRegistry: C.interfaceId(bindAbi),
  IERC165: '0x01ffc9a7',
  note: 'XOR of the selectors of all functions declared in the interface (ERC-165), excluding supportsInterface.',
});

// ------------------------------------------------------------------------------- identifiers
const profiles = Object.keys(JSON.parse(fs.readFileSync(path.join(EX, 'manifest.json'), 'utf8')).profiles).sort();
const identifiers = {
  profileIds: Object.fromEntries(profiles.map((p) => [p, C.idOf(p)])),
  familyIds: Object.fromEntries(C.FAMILIES.map((f) => [`asf:family:${f}`, C.idOf(`asf:family:${f}`)])),
  enforcementBits: C.ENFORCEMENT,
  rightsBits: C.RIGHTS,
  restrictionBits: C.RESTRICTION,
  combinator: C.COMBINATOR,
  bindingState: { none: 0, active: 1, suspended: 2, terminated: 3 },
  verdict: { unknown: 0, satisfied: 1, 'not-satisfied': 2 },
  reason: {
    none: 0, 'no-binding': 1, terminated: 2, suspended: 3, 'not-yet-valid': 4, expired: 5, 'spec-mismatch': 6,
    'version-mismatch': 7, 'adopter-mismatch': 8, 'subject-mismatch': 9, 'scope-mismatch': 10,
    'enforcement-mismatch': 11, 'parent-not-satisfied': 12, 'spec-registry-unavailable': 13,
  },
  note: 'profileId / familyId = keccak256(UTF-8(identifier)). Bit sets and enumerations as in ASFTypes.sol.',
};
write('identifiers.json', identifiers);

// ------------------------------------------------------------------------------------ keys
const CHAIN = 11155111;
const agent = '0x000000000000000000000000000000000000a6e7';
const principal = '0x00000000000000000000000000000000000a11ce';
const guardian = '0x0000000000000000000000000000000000006a2d';
const executor = '0x0000000000000000000000000000000000ac0df0';
const accountRef = C.accountRef(CHAIN, agent);
const scopeObj = { ref: C.accountRef(CHAIN, principal) };
const richScope = { task: 'x:task-tender:eip155:11155111:0x0000000000000000000000000000000000007a5c:17', phase: 'execution' };
write('keys.json', {
  chainId: CHAIN,
  account: agent,
  accountRef,
  subjectKey: C.subjectKey(accountRef),
  refScope: { object: scopeObj, jcs: C.canonicalString(scopeObj), scopeKey: C.scopeKey(scopeObj) },
  richScope: { object: richScope, jcs: C.canonicalString(richScope), scopeKey: C.scopeKey(richScope) },
  note: 'subjectKey = keccak256(UTF-8(ref)); scopeKey = keccak256(UTF-8(JCS(scope object))). The one-member {"ref": ...} form is derivable on chain by ASFKeys.refScopeKey.',
});

// -------------------------------------------------------------------------- canonicalization
const minimal = {
  kind: 'safety-specification', asf: '1.0', name: 'Vector Specification', version: 1,
  protects: [{ domain: 'assets-economic' }],
  applicability: {},
  constraints: [{ id: 'c', profile: 'asf:profile:authority/bounded-spend@1', family: 'identity-authority', statement: 'cap', scope: 'action', enforcedBy: ['ch'] }],
  authority: { whoMayAdopt: ['principal'], whoMayEnforce: ['account'], authorityBasis: ['permission'] },
  evidence: [],
  enforcement: { channels: [{ id: 'ch', description: 'account', location: 'account', coverage: 'full' }] },
  failureHandling: { unknown: 'wait', denied: 'refuse', dependencyFailure: 'degrade' },
  remedies: { suspensionModes: ['full-stop'] },
  profiles: { required: ['asf:profile:authority/bounded-spend@1'] },
};
write('canonicalization.json', {
  document: minimal,
  jcs: C.canonicalString(minimal),
  contentHash: C.canonicalHash(minimal),
  note: 'contentHash = keccak256(UTF-8(JCS(document))) (RFC 8785).',
});

// --------------------------------------------------------------------------------- spec id
const specRegistry = '0x00000000000000000000000000000000000a5f01';
const bindingRegistry = '0x00000000000000000000000000000000000a5f02';
const publisher = '0x00000000000000000000000000000000000009b1';
const salt1 = '0x' + '0'.repeat(63) + '1';
const specId = C.specId(CHAIN, specRegistry, publisher, salt1);
write('spec-id.json', { chainId: CHAIN, registry: specRegistry, publisher, salt: salt1, specId,
  note: 'specId = keccak256(abi.encode(chainId, registry, publisher, salt)).' });

// ------------------------------------------------------------------------------ binding id
const bindingInput = {
  subjectKey: C.subjectKey(accountRef),
  scopeKey: C.scopeKey(scopeObj),
  specRegistry,
  specId,
  version: 1,
  salt: '0x' + '0'.repeat(62) + '11',
};
write('binding-id.json', {
  chainId: CHAIN, registry: bindingRegistry, adopter: principal, ...bindingInput,
  bindingId: C.bindingId(CHAIN, bindingRegistry, principal, bindingInput),
  note: 'bindingId = keccak256(abi.encode(chainId, registry, adopter, subjectKey, scopeKey, specRegistry, specId, version, salt)).',
});

// ------------------------------------------------------------------------------ requirement
const requirement = {
  combinator: C.COMBINATOR['k-of'],
  k: 2,
  clauses: [
    { specRegistry, specId, versions: [1, 2], adopter: principal, subjectKey: C.subjectKey(accountRef), scopeKey: '0x' + '0'.repeat(64), enforcement: C.enforcementMask(['account', 'contract']) },
    { specRegistry, specId, versions: [], adopter: '0x' + '0'.repeat(40), subjectKey: '0x' + '0'.repeat(64), scopeKey: C.scopeKey(richScope), enforcement: 0 },
    { specRegistry, specId, versions: [1], adopter: '0x' + '0'.repeat(40), subjectKey: '0x' + '0'.repeat(64), scopeKey: '0x' + '0'.repeat(64), enforcement: C.enforcementMask(['collective']),
      interveners: [
        { account: guardian, rights: C.rightsMask(['suspend']) },
        { account: executor, rights: C.rightsMask(['resume']) },
      ] },
  ],
};
for (const c of requirement.clauses) {
  if (!c.interveners) c.interveners = [];
  c.intervenerCount = c.interveners.length; // for the Solidity cross-check, which cannot read array lengths from JSON
}
write('requirement.json', {
  requirement,
  abiType: C.REQUIREMENT_TYPE,
  encoded: C.encodeRequirement(requirement),
  requirementId: C.requirementId(requirement),
  note: 'requirementId = keccak256(abi.encode(requirement)); enumerations are encoded as uint8. Required interveners are named accounts with the rights they must hold; a clause that names interveners also closes the resume right to the accounts it names.',
});

// ---------------------------------------------------------------------------- example hashes
const manifest = JSON.parse(fs.readFileSync(path.join(EX, 'manifest.json'), 'utf8'));
write('examples.json', {
  specifications: Object.fromEntries(Object.entries(manifest.specifications).map(([n, e]) => [n, { file: e.file, specId: e.specId, contentHash: e.contentHash }])),
  bindings: Object.fromEntries(Object.entries(manifest.bindings).map(([f, e]) => [f, { paramsHash: e.paramsHash, authorityRef: e.authorityRef, enforcement: e.enforcement, bindingId: e.bindingId, parentBindingId: e.parentBindingId }])),
  requirements: Object.fromEntries(Object.entries(manifest.requirements).map(([f, e]) => [f, { documentHash: e.documentHash, requirementId: e.requirementId }])),
  profiles: Object.fromEntries(Object.entries(manifest.profiles).map(([id, e]) => [id, { profileId: e.profileId, descriptorHash: e.descriptorHash }])),
  responses: Object.fromEntries(Object.entries(manifest.responses || {}).map(([f, e]) => [f, { restrictionsBits: e.restrictionsBits, responseRef: e.responseRef }])),
});
