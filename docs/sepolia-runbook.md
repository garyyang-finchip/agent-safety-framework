# Sepolia evidence runbook

The evidence run exercises the whole framework on Sepolia with the worked examples and the two closed-loop consumers. It was rehearsed end to end on a local Anvil chain (36 transactions across five phases). Three keys take part:

- **Deployer** (`PRIVATE_KEY`): deploys everything, plays the specification publisher, the principal of the guarded account, the swarm organizer and the task publisher; funds the two other keys; pays most gas.
- **Agent** (`AGENT_PK`): the assistant operating the guarded account (through the operator probe), swarm member A, and the worker who fulfills the tender. Receives 0.004 ETH from the deployer in phase 1.
- **Guardian** (`GUARDIAN_PK`): may suspend the principal's binding; also submits to the tender as the unbound account. Receives 0.002 ETH in phase 1.

Prerequisites: Foundry, Node 22, `npm install`, a Sepolia RPC URL, the deployer funded with at least 0.05 Sepolia ETH. Take every gas limit from live estimates: Sepolia's current schedule costs several times Anvil's.

```
export SEPOLIA_RPC_URL=...
export PRIVATE_KEY=0x...            # deployer
export AGENT_PK=0x...
export GUARDIAN_PK=0x...
export TASK_TOKEN=0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7   # live TASK-KERNEL v3.0 TaskToken on Sepolia
export DEPLOYMENTS=deployments/sepolia.json
export MANIFEST=deployments/sepolia/examples/manifest.json
export LOCATOR_BASE=https://raw.githubusercontent.com/garyyang-finchip/agent-safety-framework/main/deployments/sepolia/examples/
mkdir -p deployments && echo '{}' > deployments/sepolia.json
```

## Phase 1: deploy

```
forge script script/SepoliaEvidence.s.sol --sig "deployCore()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Deploys `ASFSpecificationRegistry`, `ASFBindingRegistry`, the `LendingDesk` target, the `ASFGuardedAccount` (requirement: the deployer's own adoption of Personal Assistant Safety v1 for the agent, account-enforced) with its `OperatorProbe`, and the `ASFTaskTenderAdapter` bound to the live `TaskToken` (without `TASK_TOKEN` a local fixture is deployed instead). Writes `deployments/sepolia.json`.

## Phase 2: relink the examples with the real addresses

The example documents carry placeholder addresses. Copy them under `deployments/` and relink so that the hashes that go on chain are the hashes of the files that will be published:

```
cp -r assets/erc-asf/examples deployments/sepolia/examples
D=deployments/sepolia.json; j() { python3 -c "import json;print(json.load(open('$D'))['$1'])"; }
node tools/build-examples.js --dir deployments/sepolia/examples --chain-id 11155111 \
  --spec-registry $(j specRegistry) --binding-registry $(j bindingRegistry) --publisher $(j deployer) \
  --map "0x00000000000000000000000000000000000a11ce=$(j deployer),0x000000000000000000000000000000000000a6e7=$(j agent),0x0000000000000000000000000000000000006a2d=$(j guardian),0x00000000000000000000000000000000000060a9=$(j deployer),0x00000000000000000000000000000000000000aa=$(j agent),0x0000000000000000000000000000000000006a4d=$(j guardedAccount)"
node tools/validate.js
```

Commit and push `deployments/sepolia/examples` before phase 3 so that `LOCATOR_BASE` resolves to the exact bytes whose hashes go on chain. (The `manifest.json` written next to the examples must also be pushed: the script reads it.)

## Phase 3: publish and adopt

```
forge script script/SepoliaEvidence.s.sol --sig "publishAndAdopt()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Publishes the two specifications (the script checks that the on-chain `specId` equals the manifest's), creates the principal's binding for the agent on the guarded account (guardian may suspend) and presents it to the account, the organizer's binding for the swarm, the agent's derived member binding, and the agent's own worker binding. Binding identifiers are written to the deployments file.

## Phase 4: guard loop

```
forge script script/SepoliaEvidence.s.sol --sig "guardLoop()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

borrow (ok) -> guardian suspends under `DeriskOnly` -> borrow refused (recorded by the probe's `Attempt` event with the revert data) -> repay ok -> principal resumes -> borrow ok.

## Phase 5: tender loop

```
forge script script/SepoliaEvidence.s.sol --sig "tenderLoop()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Mints a tender on the live `TaskToken` with the adapter as acceptance authority (reward 0.001 ETH, two completions, 7-day judgment window), funds it with 0.002 ETH, the agent and the guardian each submit, `judge` accepts and pays the agent and rejects the guardian.

## Phase 6: lifecycle

```
forge script script/SepoliaEvidence.s.sol --sig "lifecycle()" --rpc-url $SEPOLIA_RPC_URL --broadcast
```

`FullStop` suspension refuses even repay; resume; the swarm binding is terminated and the derived member binding fails with `ParentNotSatisfied` while its own record stays `Active`; version 1 of the swarm specification is deprecated.

## Record

After the run: copy the broadcast records' transaction hashes, block numbers and gas into `docs/sepolia-evidence.md`, verify the seven contracts on Sourcify or Etherscan from the standard JSON input, and update the address table in `README.md`. The three keys are session-generated; the deployer keeps publishing control of the two specifications and the adopter role of the principal's and organizer's bindings until a later round moves them.
