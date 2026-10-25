#!/usr/bin/env node
'use strict';
// Validates every worked example against the JSON Schemas of the assets and re-checks the manifest hashes.
//
//   node tools/validate.js

const fs = require('fs');
const path = require('path');
const Ajv = require('ajv/dist/2020');
const addFormats = require('ajv-formats');
const C = require('./lib/canonical');

const ROOT = path.join(__dirname, '..');
const SCHEMAS = path.join(ROOT, 'assets', 'erc-asf', 'schemas');
const EX = path.join(ROOT, 'assets', 'erc-asf', 'examples');

const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);
for (const f of fs.readdirSync(SCHEMAS)) {
  const s = JSON.parse(fs.readFileSync(path.join(SCHEMAS, f), 'utf8'));
  ajv.addSchema(s, f);
}

const byKind = {
  'profile-descriptor': 'profile-descriptor.schema.json',
  'safety-specification': 'safety-specification.schema.json',
  'safety-binding': 'safety-binding.schema.json',
  'requirement-set': 'requirement-set.schema.json',
};

let failures = 0;
let count = 0;
for (const dir of ['profiles', 'specifications', 'bindings', 'requirements']) {
  for (const f of fs.readdirSync(path.join(EX, dir)).filter((x) => x.endsWith('.json')).sort()) {
    const doc = JSON.parse(fs.readFileSync(path.join(EX, dir, f), 'utf8'));
    const schema = byKind[doc.kind];
    const ok = ajv.validate(schema, doc);
    count++;
    if (!ok) {
      failures++;
      console.log(`FAIL ${dir}/${f}`);
      for (const e of ajv.errors) console.log(`   ${e.instancePath || '/'} ${e.message}`);
    }
  }
}

// manifest consistency
const manifest = JSON.parse(fs.readFileSync(path.join(EX, 'manifest.json'), 'utf8'));
for (const [name, e] of Object.entries(manifest.specifications)) {
  const doc = JSON.parse(fs.readFileSync(path.join(EX, e.file), 'utf8'));
  if (C.canonicalHash(doc) !== e.contentHash) { failures++; console.log(`FAIL manifest contentHash of ${name}`); }
  if (doc.name !== name) { failures++; console.log(`FAIL manifest name of ${e.file}`); }
}
for (const [f, e] of Object.entries(manifest.bindings)) {
  const doc = JSON.parse(fs.readFileSync(path.join(EX, e.file), 'utf8'));
  if (C.canonicalHash(doc) !== e.paramsHash) { failures++; console.log(`FAIL manifest paramsHash of ${f}`); }
  if (C.subjectKey(doc.subject.ref) !== doc.subject.key) { failures++; console.log(`FAIL subject key of ${f}`); }
  if (C.scopeKey(doc.scope.object) !== doc.scope.key) { failures++; console.log(`FAIL scope key of ${f}`); }
  if (doc.specification.contentHash !== manifest.specifications[doc.specification.name].contentHash) { failures++; console.log(`FAIL spec pin of ${f}`); }
}
for (const [f, e] of Object.entries(manifest.requirements)) {
  const doc = JSON.parse(fs.readFileSync(path.join(EX, e.file), 'utf8'));
  if (C.canonicalHash(doc) !== e.documentHash) { failures++; console.log(`FAIL manifest documentHash of ${f}`); }
  if (e.onChain && C.requirementId(e.onChain) !== e.requirementId) { failures++; console.log(`FAIL requirementId of ${f}`); }
}

console.log(`validated ${count} example documents against ${Object.keys(byKind).length} schemas; manifest re-checked; ${failures} failure(s)`);
process.exit(failures ? 1 : 0);
