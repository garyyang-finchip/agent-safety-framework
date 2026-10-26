# Deployments

Records of the evidence run of `script/SepoliaEvidence.s.sol` on Sepolia (see `docs/sepolia-runbook.md` for the procedure and `docs/sepolia-evidence.md` for the results).

- `sepolia.json`: addresses, specification identifiers and binding identifiers written by the phases of the run.
- `sepolia.transactions.json`: the 36 transactions of the run (phase, sender, nonce, hash, block, status, gas used, gas limit, effective gas price, logs), the failed first attempt, the contract addresses, the Sourcify verification and the way the run was executed.
- `sepolia/examples/`: the worked examples relinked with the real chain, registries and accounts; the hashes that go on chain are the hashes of these files, so they are committed before the publish phase and served from this repository as the specification and parameter locators.

Anvil rehearsal records (`anvil.json`, `anvil/`) are local and ignored by git.
