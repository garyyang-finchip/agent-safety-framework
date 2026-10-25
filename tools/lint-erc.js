#!/usr/bin/env node
'use strict';
// Lints the ERC text with eipw (the validator used by the ethereum/ERCs repository) in a scratch directory
// that mirrors the repository layout: ERCS/eip-<number>.md next to stub files for the proposals it links to.
//
//   node tools/lint-erc.js [--number 9999] [--source ERCS/erc-asf.md]

const fs = require('fs');
const os = require('os');
const path = require('path');
const eipw = require('eipw-lint-js');

const args = process.argv.slice(2);
const arg = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const NUMBER = arg('--number', '9999');
const SOURCE = path.resolve(arg('--source', path.join(__dirname, '..', 'ERCS', 'erc-asf.md')));

// Statuses of linked proposals (as published), used to satisfy the status lints offline.
const STUBS = {
  165: { title: 'Standard Interface Detection', status: 'Final', type: 'Standards Track', category: 'ERC' },
  4337: { title: 'Account Abstraction Using Alt Mempool', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  7710: { title: 'Smart Contract Delegation', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  7715: { title: 'Request Permissions from Wallets', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  8004: { title: 'Trustless Agents', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  8354: { title: 'Confidential Agent Policy Verdicts', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  8436: { title: 'Agent Collective Decision Framework', status: 'Draft', type: 'Standards Track', category: 'ERC' },
  8444: { title: 'Agentic Resource Discovery (ARD) Onchain', status: 'Draft', type: 'Standards Track', category: 'ERC' },
};

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asf-eipw-'));
const ercs = path.join(dir, 'ERCS');
fs.mkdirSync(ercs);
let text = fs.readFileSync(SOURCE, 'utf8');
text = text.replace(/^eip: .*$/m, `eip: ${NUMBER}`).replace(/\.\.\/assets\/erc-asf\//g, `../assets/eip-${NUMBER}/`);
const target = path.join(ercs, `eip-${NUMBER}.md`);
fs.writeFileSync(target, text);
for (const [n, meta] of Object.entries(STUBS)) {
  fs.writeFileSync(path.join(ercs, `eip-${n}.md`), `---\neip: ${n}\ntitle: ${meta.title}\nauthor: Stub (@stub)\nstatus: ${meta.status}\ntype: ${meta.type}\ncategory: ${meta.category}\ncreated: 2020-01-01\n---\n\n## Abstract\n\nStub for offline linting.\n`);
}

(async () => {
  const result = await eipw.lint([target]);
  let errors = 0;
  let warnings = 0;
  let spelling = 0;
  const words = new Set();
  for (const snippet of result) {
    const level = snippet.level;
    const id = snippet.id;
    if (id === 'markdown-spell') {
      spelling++;
      const m = /the word `([^`]+)`/.exec(snippet.title || '');
      if (m) words.add(m[1]);
      continue;
    }
    if (level === 'Error') errors++; else warnings++;
    console.log(snippet.formatted || eipw.format(snippet));
  }
  if (spelling) console.log(`eipw spelling findings (review only, not gating): ${[...words].sort().join(', ')}`);
  console.log(`eipw: ${errors} error(s), ${warnings} other finding(s) for ERCS/erc-${NUMBER}.md`);
  fs.rmSync(dir, { recursive: true, force: true });
  process.exit(errors ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
