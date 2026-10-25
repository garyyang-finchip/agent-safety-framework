'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../lib/canonical');

test('account reference and subject key follow the on-chain derivation', () => {
  const ref = C.accountRef(31337, '0x000000000000000000000000000000000000A6E7');
  assert.equal(ref, 'eip155:31337:0x000000000000000000000000000000000000a6e7');
  assert.equal(C.subjectKey(ref).length, 66);
});

test('scope key canonicalizes member order', () => {
  const a = C.scopeKey({ task: 't', phase: 'p' });
  const b = C.scopeKey({ phase: 'p', task: 't' });
  assert.equal(a, b);
  assert.equal(C.canonicalString({ ref: 'x' }), '{"ref":"x"}');
});

test('enforcement and rights masks', () => {
  assert.equal(C.enforcementMask(['account', 'contract']), 18);
  assert.equal(C.enforcementMask([]), 0);
  assert.equal(C.rightsMask(['suspend', 'resume', 'terminate']), 7);
  assert.throws(() => C.enforcementMask(['cloud']));
});

test('requirement id is stable under re-encoding', () => {
  const req = { combinator: 0, k: 0, clauses: [{ specRegistry: '0x' + '0'.repeat(39) + '1', specId: '0x' + '0'.repeat(63) + '1', versions: [1], adopter: '0x' + '0'.repeat(40), subjectKey: '0x' + '0'.repeat(64), scopeKey: '0x' + '0'.repeat(64), enforcement: 2 }] };
  assert.equal(C.requirementId(req), C.requirementId(JSON.parse(JSON.stringify(req))));
});
