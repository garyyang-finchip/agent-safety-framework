# Sepolia evidence runbook

The evidence run exercises the whole framework on Sepolia with the worked examples and the two closed-loop consumers. It has been executed twice, each time after an end-to-end rehearsal on a local Anvil chain: with the revision-5 contracts on 2026-10-26 (36 transactions across five transaction phases, all successful; record in `docs/sepolia-evidence.md`, `deployments/sepolia.json`, `deployments/sepolia.transactions.json` and `deployments/sepolia/`), and with the revision-7 contracts on 2026-10-27, after the script had gained the standing-stop loop of Section 8.5 as a sixth transaction phase (43 transactions, all successful; record in `docs/sepolia-evidence-rev7.md`, `deployments/sepolia-rev7.json`, `deployments/sepolia-rev7.transactions.json` and `deployments/sepolia-rev7/`). Three keys take part:

- **Deployer** (`PRIVATE_KEY`): deploys everything, plays the specification publisher, the principal of the guarded account, the swarm organizer and the task publisher; funds the two other keys when they run low; pays most gas.
- **Agent** (`AGENT_PK`): the assistant operating the guarded account (through the operator probe), swarm member A, and the worker who fulfills the tender. Phase 1 sends it 0.012 ETH from the deployer when its balance is below 0.006 ETH.
- **Guardian** (`GUARDIAN_PK`): may suspend and resume the principal's binding (the example names it with both rights, because a suspension it records cannot be lifted by the principal); also submits to the tender as the unbound account. Phase 1 sends it 0.006 ETH when its balance is below 0.003 ETH.

Prerequisites: Foundry, Node 22, `npm install`, a Sepolia RPC URL, the deployer funded with at least 0.05 Sepolia ETH (the first run used 0.0072 ETH in fees at a 0.1 gwei priority fee, plus the 0.018 ETH it forwarded to the two other keys and the 0.002 ETH that funds the tender; the second run used 0.0085 ETH in fees and the 0.002 ETH of the tender, and reused the two funded keys without a transfer).

Sepolia's gas schedule since the Glamsterdam upgrade (2026-10-06) prices state and code roughly ten times higher than Anvil's default schedule, and a transaction may use at most 16,777,216 gas (EIP-7825). Two consequences for this run: gas limits must come from live estimates, never from an Anvil rehearsal (the first Sepolia attempt of the first run, sent with Anvil's limit, ran out of gas); and the binding registry delegates its check to the externally linked library `ASFEvaluation` and, since revision 6, its writes (`adopt`, `suspend`, `resume`, `terminate`, `liftStop`, `setStopLifter`) to `ASFLifecycle`; `forge script` deploys the libraries through the deterministic CREATE2 factory before the registry. The revision-5 registry alone took about 15.1 million gas to deploy, 90% of the cap; the current registry is 7,637 bytes of runtime code and took 12,018,098 gas (72% of the cap) in the second run, with the two libraries at 3,923 and 5,546 bytes. Deployment cost grows by about 1,400 gas per byte of deployed code, so any change that grows a contract's code should be checked against the cap with `eth_estimateGas` before a run.

The setup below names the files of the second run (`sepolia-rev7`); every run uses a fresh deployments file and examples directory of its own, so that the earlier records and the locators pinned on chain stay as they are. A further run takes a new name.

```
export SEPOLIA_RPC_URL=...
export PRIVATE_KEY=0x...            # deployer
export AGENT_PK=0x...
export GUARDIAN_PK=0x...
export TASK_TOKEN=0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7   # live TASK-KERNEL v3.0 TaskToken on Sepolia
export DEPLOYMENTS=deployments/sepolia-rev7.json
export MANIFEST=deployments/sepolia-rev7/examples/manifest.json
export LOCATOR_BASE=https://raw.githubusercontent.com/garyyang-finchip/agent-safety-framework/main/deployments/sepolia-rev7/examples/
mkdir -p deployments/sepolia-rev7 && echo '{}' > deployments/sepolia-rev7.json
```

## Phase 1: deploy

```
forge script script/SepoliaEvidence.s.sol --sig "deployCore()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Deploys the `ASFEvaluation` and `ASFLifecycle` libraries (through the CREATE2 factory, so their addresses do not depend on the deployer's nonce), `ASFSpecificationRegistry`, `ASFBindingRegistry` linked to both, the `LendingDesk` target, the `ASFGuardedAccount` (requirement: the deployer's own adoption of Personal Assistant Safety v1 for the agent, account-enforced) with its `OperatorProbe`, and the `ASFTaskTenderAdapter` bound to the live `TaskToken` (without `TASK_TOKEN` a local fixture is deployed instead). The adapter's template requires the fulfiller's own adoption of the same specification with the deployer (the task publisher) as an intervener holding the suspend and resume rights. The agent and the guardian are funded only when their balances are below the thresholds above. Writes the deployments file.

## Phase 2: relink the examples with the real addresses

The example documents carry placeholder addresses. Copy them under `deployments/`, together with the tender documents of `script/tender/` (the task document and the four fulfillment results whose SHA-256 digests the tender and stop loops put on the `TaskToken`), and relink so that the hashes that go on chain are the hashes of the files that will be published (the `mkdir -p` of the setup block must have run first, otherwise `cp -r` creates the run directory as the examples directory itself):

```
cp -r assets/erc-asf/examples deployments/sepolia-rev7/examples
cp -r script/tender deployments/sepolia-rev7/examples/tender
D=deployments/sepolia-rev7.json; j() { python3 -c "import json;print(json.load(open('$D'))['$1'])"; }
node tools/build-examples.js --dir deployments/sepolia-rev7/examples --chain-id 11155111 \
  --spec-registry $(j specRegistry) --binding-registry $(j bindingRegistry) --publisher $(j deployer) \
  --map "0x00000000000000000000000000000000000a11ce=$(j deployer),0x000000000000000000000000000000000000a6e7=$(j agent),0x0000000000000000000000000000000000006a2d=$(j guardian),0x00000000000000000000000000000000000060a9=$(j deployer),0x00000000000000000000000000000000000000aa=$(j agent),0x0000000000000000000000000000000000006a4d=$(j guardedAccount)"
node tools/validate.js
```

Commit and push the relinked directory before phase 3 so that `LOCATOR_BASE` resolves to the exact bytes whose hashes go on chain. (The `manifest.json` written next to the examples must also be pushed: the script reads it.) In the second run the directory was committed together with the record after the relay instead; the hashes on chain are the hashes of the committed files either way (the manifest lists them).

## Phase 3: publish and adopt

```
forge script script/SepoliaEvidence.s.sol --sig "publishAndAdopt()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Publishes the two specifications (the script checks that the on-chain `specId` equals the manifest's), creates the principal's binding for the agent on the guarded account (guardian may suspend and resume) and presents it to the account, the organizer's binding for the swarm, the agent's derived member binding, and the agent's own worker binding (which names the deployer as an intervener with the suspend and resume rights, as the tender requires). Interveners are read from the relinked manifest. Binding identifiers are written to the deployments file.

## Phase 4: guard loop

```
forge script script/SepoliaEvidence.s.sol --sig "guardLoop()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

borrow (ok) -> guardian suspends with the response set of `guardian-derisk-only.response.json` (`RESTRICT_NO_NEW_RISK | RESTRICT_DERISK_ONLY`, bits 9) and its `responseRef` -> borrow refused (recorded by the probe's `Attempt` event with the revert data) -> repay ok -> guardian resumes (the principal could not: the suspension was the guardian's) -> borrow ok. The bits and the response reference are read from the relinked `manifest.json`.

## Phase 5: tender loop

```
forge script script/SepoliaEvidence.s.sol --sig "tenderLoop()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Mints a tender on the live `TaskToken` with the adapter as acceptance authority (reward 0.001 ETH, two completions, 7-day judgment window; the task document is `tender/task.json`, its digest and locator on the token), funds it with 0.002 ETH, the agent submits `tender/result-worker.json` and the guardian submits `tender/result-unbound.json`, `judge` accepts and pays the agent and rejects the guardian.

## Phase 6: stop loop

```
forge script script/SepoliaEvidence.s.sol --sig "stopLoop()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

The publisher suspends the worker's binding with `RESTRICT_FULL_STOP` (an urgent stop, zero `responseRef`), which records a standing stop against the worker for the subject and the specification. The worker terminates the stopped record, adopts a fresh binding under the next salt (same document, same interveners), submits `tender/result-worker-after-stop.json` and calls `judge` itself: rejected with `StoppedByIntervener`, the stop standing against the adopter rather than against the record. The script checks that `stopOf` points at the terminated binding and that the terminated record keeps `suspendedBy`. The publisher then lifts its stop (`liftStop`, `StopLifted`), the worker submits `tender/result-worker-after-lift.json` and is accepted and paid as the tender's second completion.

## Phase 7: lifecycle

```
forge script script/SepoliaEvidence.s.sol --sig "lifecycle()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

The principal suspends with the response set of `principal-full-stop.response.json` (`RESTRICT_FULL_STOP`, bits 16): even repay is refused; resume; the swarm binding is terminated and the derived member binding fails with `ParentNotSatisfied` while its own record stays `Active`; version 1 of the swarm specification is deprecated.

## Rehearsal on Anvil

The same phases run against a local Anvil chain with its default funded keys; this is how the runs are rehearsed (36 transactions for the revision-5 script, 44 for the current one: the local run deploys the fixture `TaskToken` as one more transaction and skips the funding transfers, since Anvil's keys are funded). The only differences are the chain id (which `build-examples.js --chain-id 31337` also writes into every `eip155:` reference of the copied examples), a local locator base and the fixture `TaskToken` that `deployCore` deploys when `TASK_TOKEN` is unset:

```
anvil --port 8545 &
export PRIVATE_KEY=<anvil key 0> AGENT_PK=<anvil key 1> GUARDIAN_PK=<anvil key 2>
export DEPLOYMENTS=deployments/anvil.json MANIFEST=deployments/anvil/examples/manifest.json LOCATOR_BASE=http://localhost/examples/
mkdir -p deployments/anvil && echo '{}' > deployments/anvil.json
forge script script/SepoliaEvidence.s.sol --sig "deployCore()" --rpc-url http://127.0.0.1:8545 --broadcast
cp -r assets/erc-asf/examples deployments/anvil/examples
cp -r script/tender deployments/anvil/examples/tender
D=deployments/anvil.json; j() { python3 -c "import json;print(json.load(open('$D'))['$1'])"; }
node tools/build-examples.js --dir deployments/anvil/examples --chain-id 31337 \
  --spec-registry $(j specRegistry) --binding-registry $(j bindingRegistry) --publisher $(j deployer) \
  --map "0x00000000000000000000000000000000000a11ce=$(j deployer),0x000000000000000000000000000000000000a6e7=$(j agent),0x0000000000000000000000000000000000006a2d=$(j guardian),0x00000000000000000000000000000000000060a9=$(j deployer),0x00000000000000000000000000000000000000aa=$(j agent),0x0000000000000000000000000000000000006a4d=$(j guardedAccount)"
for ph in publishAndAdopt guardLoop tenderLoop stopLoop lifecycle; do
  forge script script/SepoliaEvidence.s.sol --sig "$ph()" --rpc-url http://127.0.0.1:8545 --broadcast
done
```

`deployments/anvil*` is a rehearsal record and is not kept in the repository.

## Execution against Sepolia

`forge script ... --broadcast` against a Sepolia RPC runs each phase in order and takes its gas limits from the node's estimates. Both recorded runs were executed differently, for the reason given above: the transactions of all phases were produced against a local Anvil mirror of the Sepolia state (chain id 11155111, the live `TaskToken` code and storage, the three accounts at their live nonces and balances), signed at those nonces with gas limits taken from live estimates, and relayed to Sepolia as raw transactions, batch by batch, with every transaction whose effect depends on the order of two senders confirmed before the next was sent. Calldata and addresses are identical either way; the evidence records and the transaction files state the execution path next to the receipts. A mirror is only valid while nothing else moves the state it copied: the live `TaskToken`'s next token id and the three nonces are checked against Sepolia before the phases that depend on them are relayed (the tender loop above all, which mints the next token id). The receipts of a relayed run differ from the mirror's in gas used (Sepolia's schedule) and in the EIP-7708 transfer logs Sepolia emits for ETH movements, which Anvil does not; the application logs are the same.

## Record

The record of a run is its deployments file (addresses and identifiers), its transactions file (every transaction with hash, block, status, gas and effective price, and the Sourcify verification) and its evidence document (the phases, the decoded events, the state read back after the run, and how to reproduce the checks): `deployments/sepolia.json`, `deployments/sepolia.transactions.json` and `docs/sepolia-evidence.md` for the revision-5 run; `deployments/sepolia-rev7.json`, `deployments/sepolia-rev7.transactions.json` and `docs/sepolia-evidence-rev7.md` for the revision-7 run. The deployed contracts of both runs are verified on Sourcify from the standard JSON input with the libraries linked at their addresses; `README.md` carries the address tables. The three keys are session-generated; the deployer keeps publishing control of the specifications and the adopter role of the principal's and organizer's bindings until a later round moves them.
