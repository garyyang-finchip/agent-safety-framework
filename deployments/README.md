# Deployments

Records of the two evidence runs of `script/SepoliaEvidence.s.sol` on Sepolia (see `docs/sepolia-runbook.md` for the procedure, `docs/sepolia-evidence.md` and `docs/sepolia-evidence-rev7.md` for the results). Each run has a deployments file, a transactions file and an examples directory of its own; the earlier records and the locators pinned on chain stay as they are.

Revision 7 (2026-10-27, 43 transactions, the current contracts):

- `sepolia-rev7.json`: addresses, specification identifiers, binding identifiers and tender identifiers written by the phases of the run.
- `sepolia-rev7.transactions.json`: the 43 transactions (phase, sender, nonce, hash, block, status, gas used, gas limit, effective gas price, logs), the contract addresses, the Sourcify verification and the way the run was executed.
- `sepolia-rev7/examples/`: the worked examples relinked with the real chain, registries and accounts, and the tender documents (`tender/`); the hashes on chain are the hashes of these files, served from this repository as the specification, parameter, task and result locators.

Revision 5 (2026-10-26, 36 transactions):

- `sepolia.json`: addresses, specification identifiers and binding identifiers written by the phases of the run.
- `sepolia.transactions.json`: the 36 transactions, the failed first attempt, the contract addresses, the Sourcify verification and the way the run was executed.
- `sepolia/examples/`: the worked examples relinked with the real chain, registries and accounts of that run.

Anvil rehearsal records (`anvil.json`, `anvil/`) are local and ignored by git.
