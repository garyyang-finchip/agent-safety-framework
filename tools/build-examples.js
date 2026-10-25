#!/usr/bin/env node
'use strict';
// Links and hashes the worked examples (assets/erc-asf/examples):
//   * specifications: contentHash = keccak256(JCS(document)); specId from metadata.registration
//   * bindings: fills specification.specId / contentHash from the named specification example,
//     subject.key, scope.key and derived.parentBindingId (from the parent example), then computes
//     paramsHash, authorityRef, enforcement bit set and the bindingId of the example registration
//   * requirement sets: fills specification.specId per clause
//   * profiles: profileId and descriptor hash
// Writes assets/erc-asf/examples/manifest.json. Deterministic: running it twice changes nothing.
//
//   node tools/build-examples.js

const fs = require('fs');
const path = require('path');
const C = require('./lib/canonical');

const ROOT = path.join(__dirname, '..');
const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
// --dir: the examples directory to link (default: the ERC assets). The Sepolia run copies the assets'
// examples under deployments/ and relinks them with the real chain, registries and accounts:
//   --chain-id 11155111 --spec-registry 0x.. --binding-registry 0x.. --publisher 0x.. --map placeholder=real,...
// The examples are authored for Sepolia (chain 11155111). When --chain-id names another chain (an Anvil
// rehearsal, say), every `eip155:11155111:` account reference and `eip155:11155111/` asset reference in
// the documents is rewritten to that chain before linking, so that the keys match the on-chain derivation.
// --from-chain-id overrides the source chain if the examples were authored for another one.
const EX = path.resolve(arg('--dir', path.join(ROOT, 'assets', 'erc-asf', 'examples')));
const BINDING_REGISTRY = (arg('--binding-registry', '0x00000000000000000000000000000000000a5f02')).toLowerCase();
const CHAIN_ID = arg('--chain-id', null);
const FROM_CHAIN_ID = arg('--from-chain-id', '11155111');
const SPEC_REGISTRY = arg('--spec-registry', null);
const PUBLISHER = arg('--publisher', null);
const MAP = (arg('--map', '') || '').split(',').filter(Boolean).map((kv) => kv.split('=').map((x) => x.trim().toLowerCase()));

function readJson(p) {
  let text = fs.readFileSync(p, 'utf8');
  if (CHAIN_ID && String(CHAIN_ID) !== String(FROM_CHAIN_ID)) {
    text = text.split(`eip155:${FROM_CHAIN_ID}:`).join(`eip155:${CHAIN_ID}:`);
    text = text.split(`eip155:${FROM_CHAIN_ID}/`).join(`eip155:${CHAIN_ID}/`);
  }
  for (const [from, to] of MAP) text = text.split(from).join(to);
  const doc = JSON.parse(text);
  if (doc.kind === 'safety-specification' && doc.metadata && doc.metadata.registration) {
    const r = doc.metadata.registration;
    if (CHAIN_ID) r.chainId = Number(CHAIN_ID);
    if (SPEC_REGISTRY) r.registry = SPEC_REGISTRY.toLowerCase();
    if (PUBLISHER) r.publisher = PUBLISHER.toLowerCase();
    if (doc.publisher && PUBLISHER) doc.publisher.ref = C.accountRef(r.chainId, r.publisher);
  }
  return doc;
}
function writeJson(p, doc) { fs.writeFileSync(p, JSON.stringify(doc, null, 2) + '\n'); }
function listJson(dir) { return fs.readdirSync(dir).filter((f) => f.endsWith('.json')).sort(); }
function addressOf(accountRef) { return '0x' + accountRef.split(':')[2].slice(2); }

const manifest = { generatedBy: 'tools/build-examples.js', bindingRegistry: BINDING_REGISTRY, profiles: {}, specifications: {}, bindings: {}, requirements: {}, responses: {} };

// ------------------------------------------------------------------------------------ profiles
for (const f of listJson(path.join(EX, 'profiles'))) {
  const doc = readJson(path.join(EX, 'profiles', f));
  manifest.profiles[doc.identifier] = {
    file: `profiles/${f}`,
    family: doc.family,
    profileId: C.idOf(doc.identifier),
    descriptorHash: C.canonicalHash(doc),
  };
}

// ------------------------------------------------------------------------------ specifications
const specsByName = {};
for (const f of listJson(path.join(EX, 'specifications'))) {
  const doc = readJson(path.join(EX, 'specifications', f));
  const reg = doc.metadata.registration;
  const specId = C.specId(reg.chainId, reg.registry, reg.publisher, reg.salt);
  const entry = {
    file: `specifications/${f}`,
    version: doc.version,
    chainId: reg.chainId,
    registry: reg.registry,
    publisher: reg.publisher,
    salt: reg.salt,
    specId,
    contentHash: C.canonicalHash(doc),
    requiredProfiles: doc.profiles.required.map((p) => ({ identifier: p, profileId: C.idOf(p) })),
  };
  for (const c of doc.constraints) {
    if (!manifest.profiles[c.profile]) throw new Error(`${f}: unknown profile ${c.profile}`);
    const channelIds = new Set(doc.enforcement.channels.map((ch) => ch.id));
    for (const ch of c.enforcedBy) if (!channelIds.has(ch)) throw new Error(`${f}: constraint ${c.id} names unknown channel ${ch}`);
  }
  manifest.specifications[doc.name] = entry;
  specsByName[doc.name] = { doc, entry };
  writeJson(path.join(EX, 'specifications', f), doc);
}

// ------------------------------------------------------------------------------------ bindings
const bindingFiles = listJson(path.join(EX, 'bindings'));
const bindingDocs = {};
for (const f of bindingFiles) bindingDocs[f] = readJson(path.join(EX, 'bindings', f));

// parents first (a derived binding names its parent example in metadata.parentExample)
const order = bindingFiles.slice().sort((a, b) => (bindingDocs[a].metadata?.parentExample ? 1 : 0) - (bindingDocs[b].metadata?.parentExample ? 1 : 0));
for (const f of order) {
  const doc = bindingDocs[f];
  const spec = specsByName[doc.specification.name];
  if (!spec) throw new Error(`${f}: unknown specification ${doc.specification.name}`);
  if (spec.doc.version !== doc.specification.version) throw new Error(`${f}: version mismatch`);
  doc.specification.registry = C.accountRef(spec.entry.chainId, spec.entry.registry);
  doc.specification.specId = spec.entry.specId;
  doc.specification.contentHash = spec.entry.contentHash;
  doc.subject.key = C.subjectKey(doc.subject.ref);
  doc.scope.key = C.scopeKey(doc.scope.object);
  for (const p of Object.keys(doc.parameters)) if (!manifest.profiles[p]) throw new Error(`${f}: unknown profile ${p}`);
  for (const p of spec.entry.requiredProfiles) {
    if (!doc.parameters[p.identifier]) throw new Error(`${f}: required profile ${p.identifier} has no parameters`);
  }
  let parentBindingId = '0x' + '0'.repeat(64);
  if (doc.derived) {
    const parent = manifest.bindings[doc.metadata.parentExample];
    if (!parent) throw new Error(`${f}: parent example ${doc.metadata?.parentExample} not built`);
    parentBindingId = parent.bindingId;
    doc.derived.parentBindingId = parentBindingId;
  }
  const adopter = addressOf(doc.adopter.ref);
  const enforcement = C.enforcementMask(doc.mechanisms.map((m) => m.location));
  const bindingInput = {
    subjectKey: doc.subject.key,
    scopeKey: doc.scope.key,
    specRegistry: spec.entry.registry,
    specId: spec.entry.specId,
    version: doc.specification.version,
    salt: doc.metadata.salt,
  };
  const bindingId = C.bindingId(spec.entry.chainId, BINDING_REGISTRY, adopter, bindingInput);
  manifest.bindings[f] = {
    file: `bindings/${f}`,
    adopter,
    subjectRef: doc.subject.ref,
    subjectKey: doc.subject.key,
    scopeKey: doc.scope.key,
    specification: { registry: spec.entry.registry, specId: spec.entry.specId, version: doc.specification.version, contentHash: spec.entry.contentHash },
    paramsHash: C.canonicalHash(doc),
    authorityRef: C.canonicalHash(doc.authorityBasis),
    enforcement,
    enforcementLocations: doc.mechanisms.map((m) => m.location),
    validFrom: doc.validity?.from ?? 0,
    validUntil: doc.validity?.until ?? 0,
    parentBindingId,
    interveners: (doc.interveners || []).map((iv) => ({ account: addressOf(iv.ref), rights: C.rightsMask(iv.rights) })),
    intervenerCount: (doc.interveners || []).length, // for Solidity readers, which cannot take array lengths from JSON
    salt: doc.metadata.salt,
    bindingId,
  };
  writeJson(path.join(EX, 'bindings', f), doc);
}

// -------------------------------------------------------------------------------- requirements
for (const f of listJson(path.join(EX, 'requirements'))) {
  const doc = readJson(path.join(EX, 'requirements', f));
  for (const c of doc.clauses) {
    const spec = specsByName[c.specification.name];
    if (!spec) throw new Error(`${f}: unknown specification ${c.specification.name}`);
    c.specification.registry = C.accountRef(spec.entry.chainId, spec.entry.registry);
    c.specification.specId = spec.entry.specId;
  }
  // the on-chain struct for the concrete (non-"self") clauses
  const concrete = doc.clauses.every((c) => c.adopter !== 'self' && c.subject !== 'self');
  let onChain = null;
  if (concrete) {
    onChain = {
      combinator: C.COMBINATOR[doc.combinator],
      k: doc.combinator === 'k-of' ? doc.k : 0,
      clauses: doc.clauses.map((c) => ({
        specRegistry: addressOf(c.specification.registry),
        specId: c.specification.specId,
        versions: c.versions || [],
        adopter: c.adopter && c.adopter !== 'any' ? addressOf(c.adopter) : '0x' + '0'.repeat(40),
        subjectKey: c.subject && c.subject !== 'any' ? C.subjectKey(c.subject) : '0x' + '0'.repeat(64),
        scopeKey: c.scope && c.scope !== 'any' ? C.scopeKey(c.scope) : '0x' + '0'.repeat(64),
        enforcement: C.enforcementMask(c.enforcement || []),
        interveners: (c.interveners || []).map((iv) => ({ account: addressOf(iv.ref), rights: C.rightsMask(iv.rights) })),
      })),
    };
  }
  manifest.requirements[f] = {
    file: `requirements/${f}`,
    documentHash: C.canonicalHash(doc),
    concrete,
    onChain,
    requirementId: onChain ? C.requirementId(onChain) : null,
  };
  writeJson(path.join(EX, 'requirements', f), doc);
}

// ----------------------------------------------------------------------------------- responses
const RESTRICTION_BITS = C.RESTRICTION;
if (fs.existsSync(path.join(EX, 'responses'))) {
  for (const f of listJson(path.join(EX, 'responses'))) {
    const doc = readJson(path.join(EX, 'responses', f));
    const bits = doc.restrictions.reduce((acc, r) => {
      if (!(r in RESTRICTION_BITS)) throw new Error(`${f}: unknown restriction ${r}`);
      return acc | RESTRICTION_BITS[r];
    }, 0);
    if (doc.binding && doc.binding.example) {
      const b = manifest.bindings[doc.binding.example];
      if (!b) throw new Error(`${f}: unknown binding example ${doc.binding.example}`);
      doc.binding.id = b.bindingId;
      writeJson(path.join(EX, 'responses', f), doc);
    }
    manifest.responses[f] = { file: `responses/${f}`, restrictions: doc.restrictions, restrictionsBits: bits, responseRef: C.canonicalHash(doc) };
  }
}

writeJson(path.join(EX, 'manifest.json'), manifest);
console.log(`examples linked: ${Object.keys(manifest.profiles).length} profiles, ${Object.keys(manifest.specifications).length} specifications, ${Object.keys(manifest.bindings).length} bindings, ${Object.keys(manifest.requirements).length} requirement sets, ${Object.keys(manifest.responses).length} responses`);
