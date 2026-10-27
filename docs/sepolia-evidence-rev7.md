# Sepolia evidence run, revision 7

This record is of revision 7 of the reference implementation (`IASFBindingRegistry` `0xcff7f826`; the registry's evaluation and lifecycle in two externally linked libraries). It is the second run of `script/SepoliaEvidence.s.sol` on Sepolia; the first, with the revision-5 contracts, is recorded in `docs/sepolia-evidence.md` and `deployments/sepolia.transactions.json` and stays as it was. The two runs share the three accounts and the live `TaskToken`; nothing else.

The run was executed on 2026-10-27 between blocks 12003345 (06:32:00 UTC) and 12003478 (06:58:36 UTC): 43 transactions across the six transaction phases of the runbook (deploy, publish and adopt, guard loop, tender loop, stop loop, lifecycle), all with status 1, 84,788,765 gas in total, 0.00848 ETH in fees at a priority fee of 0.1 gwei over a base fee of a few tens of wei. The machine-readable record with every transaction hash, block, gas and effective price is `deployments/sepolia-rev7.transactions.json`; the addresses and identifiers written by the phases are `deployments/sepolia-rev7.json`; the example documents whose hashes went on chain, including the tender documents, are `deployments/sepolia-rev7/examples/`. They were produced by the relink phase before the publish phase and are committed with this record; the locators pinned on chain point at them on the `main` branch of this repository.

The same three session-generated keys took part as in the first run: the deployer `0xf12AFe29c9Ec5f66f669D7E388E0baE7Dc2f3eCe` (publisher of both specifications, principal of the guarded account, swarm organizer, task publisher), the agent `0x08FcB3bd9c4F171b1cba69Be2CA9e79e80f9eA6e` (operator of the guarded account through the probe, swarm member A, worker) and the guardian `0xc3e6965d427Abc91c1E33c78a986df2dBaDC660E` (suspend and resume rights on the principal's binding; the unbound submitter in the tender loop). No funding transfers were needed; the balances left by the first run covered the fees (the deployer started at nonce 26, the agent at 8, the guardian at 3).

## Contracts

| Contract | Address | Deployment | Gas used |
|---|---|---|---|
| `ASFEvaluation` (external library) | `0x9b12f62D69EAfc9a240b9AB889cC1647Bf9C56db` | [`0x7d5db9a9…`](https://sepolia.etherscan.io/tx/0x7d5db9a976dd59373a27695779bb12f229cecc9f0858d68d3e907962354bc713) through the deterministic CREATE2 factory `0x4e59b44847b379578588920ca78fbf26c0b4956c` | 6,279,442 |
| `ASFLifecycle` (external library) | `0x6a6F645eC9F161735Cc22D441aFD1f513f3b143b` | [`0x403397af…`](https://sepolia.etherscan.io/tx/0x403397af08e543a3348bf9f872374935d032108be3939f82a2961d099a720293) through the same factory | 8,789,530 |
| `ASFSpecificationRegistry` | `0x9110b622a17F83065f1e9773D961EB10672932e5` | [`0x807c07b9…`](https://sepolia.etherscan.io/tx/0x807c07b95936a8db1639bab348b73bb5d1cd6f8a00d22a25c0fc73c34f11f3d7) | 5,248,776 |
| `ASFBindingRegistry` | `0x136E2a88e1B518342CD997423BDa69Dd2c68e919` | [`0x63ebc97d…`](https://sepolia.etherscan.io/tx/0x63ebc97d963d0ae91f935cf385ad7c472d75c051c3b91a7ac8524a661c2a0d49) | 12,018,098 |
| `LendingDesk` (target) | `0x655B256CC0f942fff44b977A50B00bE7391C7341` | [`0x47b850d6…`](https://sepolia.etherscan.io/tx/0x47b850d6ec1f1b2ff9a8c8e5b38bd1d735a7e2a0e8bc5bc340a86012d205ffee) | 1,010,339 |
| `ASFGuardedAccount` | `0xc88A3FdbC5a4934D335b24416cC9fbF4046e88b0` | [`0xac13d6ed…`](https://sepolia.etherscan.io/tx/0xac13d6ed80c8e4743d5f9c5b87c570c0c5c681f6fd8d6fc5210353f8fd46a8e0) | 11,826,673 |
| `OperatorProbe` | `0xA5cA2A45E0160c6fCAf00Fa846E9cD4C6241a18c` | [`0x186aae67…`](https://sepolia.etherscan.io/tx/0x186aae6712b15df0b477396e921516815f76868b39f0bdf087350244e1b558ad) | 1,824,426 |
| `ASFTaskTenderAdapter` | `0x015393ECe2E3072055A3Fbe8Fc7f2979B7C7F3Ed` | [`0xaa55a434…`](https://sepolia.etherscan.io/tx/0xaa55a4348a539d06fffed5906fafd82aad29873fc2ee7d7d0107532740d6d886) | 11,066,805 |
| `TaskToken` (live TASK-KERNEL v3.0, not ours) | `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` | — | — |

The registry's runtime code is 7,637 bytes (`ASFLifecycle` 5,546, `ASFEvaluation` 3,923); its deployment used 12,018,098 gas, 72% of the per-transaction cap, against 15,146,485 for the revision-5 registry with one library.

All eight contracts are verified on Sourcify (API v2, 2026-10-27 07:15 UTC) with a runtime and a creation match: solc 0.8.30+commit.73712a01, optimizer 200 runs, via IR, EVM version cancun, metadata without a bytecode hash, `ASFEvaluation` and `ASFLifecycle` linked at their addresses for the registry. The sources submitted were the files of this repository at the paths of the standard JSON input, fetched from the `main` branch and checked against the local hashes before submission. Lookup: `https://sourcify.dev/server/v2/contract/11155111/<address>`. Independently of Sourcify, the runtime code read back from Sepolia for each contract equals the `deployedBytecode` of a standard-JSON compilation of the same sources once the library's own address (`ASFLifecycle`, bytes 19–38) and the immutables (`ASFGuardedAccount`: registry and owner; `OperatorProbe`: operator and account; `ASFTaskTenderAdapter`: registry and `TaskToken`) are substituted, and it equals byte for byte the code of the Anvil mirror the transactions were produced on.

Specification identifiers: Personal Assistant Safety v1 `0x5ed86852f9fd8c449303e7ef3db3fe10f6a412f25c9321ac125d56ab6f2b0e2a`, Swarm Shared Funds v1 `0x57dadd226d5a5c86379dc5f33ded4e9efceec1c2a9e1c4aeecd952e3c42d6888`. Binding identifiers: principal's binding for the agent `0xf06dd518f079330ba17fbef76f4af0413cee95a6b38b5e691af3f8a8163a6b5f`, swarm charter `0x9db519934b7b8f6aee1a5ad6f1ed37eb4165c95bbd40019fea77357504b01ccf`, derived member binding `0x30683308f51b555ee7a0d5244bf1d74d56b28b5069d5e00810c6c9994e4fe389`, worker's own binding `0xc634bead52eeaddff2e2947dd31e27ec04d2749e45475b5074d165529f2736f4`, the worker's fresh binding adopted under the stop `0xebff208f99362014ac9b56de7af4c912d33a2e83496d0b93f18f923166cb05ce`. The on-chain `specId` of each specification equals the manifest's, as the script checks before adopting. The identifiers differ from the first run's because the registries are new contracts and the example documents carry their addresses.

## How the run was executed

As in the first run (see `docs/sepolia-evidence.md` for the gas schedule and the per-transaction cap of Sepolia's Glamsterdam upgrade, which decided the split of the registry into externally linked libraries), the transactions were produced by `forge script` against a local Anvil mirror of the Sepolia state: chain id 11155111, the live `TaskToken` code and storage, the three accounts with their live balances and nonces. The 43 transactions were signed with the three keys at the mirror's nonces, with gas limits taken from live estimates (Sepolia used 5.3 times the mirror's gas in total), and relayed to Sepolia as raw transactions through a public RPC endpoint in twenty batches: the two deployment batches, then every step whose effect depends on the order of two different senders sent alone and confirmed before the next. The live `TaskToken`'s next token id (21) and the three nonces were read from Sepolia before the tender phase. No transaction failed and no nonce was skipped.

Every application log of the 43 Sepolia receipts equals the corresponding log of the mirror. Sepolia's receipts carry four logs the mirror's do not: the EIP-7708 transfer logs (emitted from the system address `0xffff…fffe` with the ERC-20 `Transfer` topic) for the three ETH movements of the tender, 0.002 ETH from the deployer to the `TaskToken` and on to the kernel's escrow in transaction 25, and 0.001 ETH from the escrow to the agent in transactions 28 and 37. Anvil does not emit them.

## Phase 1: deploy (transactions 0–10, blocks 12003345 and 12003374)

Both libraries, both registries and the lending-desk target in one block; the guarded account, its operator probe, the three configuration calls (`setOperator(probe)` [`0xc30f8d11…`](https://sepolia.etherscan.io/tx/0xc30f8d11c11c2725857e92d76038b84f2e646c8fc98734fa21558ea8ee82f0db), `setDeriskAllowed(desk, repay, true)` [`0x45b169c1…`](https://sepolia.etherscan.io/tx/0x45b169c18a785101ba81a8b6454e321487ec0750ea1c548f54404c1fd1cceaae), `setDeriskAllowed(desk, cancelOrder, true)` [`0x356e4d21…`](https://sepolia.etherscan.io/tx/0x356e4d21e7e672701486905fd5380c8e26f8d381713b57312f1e59be7f299f6e)) and the tender adapter in the next. The adapter is bound to the live `TaskToken`; its template requires the fulfiller's own adoption of Personal Assistant Safety v1 with the deployer as an intervener holding the suspend and resume rights.

## Phase 2: relink

The example documents under `deployments/sepolia-rev7/examples/` were relinked with the chain id, the registries and the three accounts (`tools/build-examples.js --dir deployments/sepolia-rev7/examples --chain-id 11155111`), validated against the schemas, and their hashes written to `manifest.json`; the tender documents of `script/tender/` were copied next to them. The specification and binding parameter locators and the task and result locators point at the raw files of this repository on the `main` branch.

## Phase 3: publish and adopt (transactions 11–17, blocks 12003402 and 12003410)

| # | Sender | Transaction | Effect |
|---|---|---|---|
| 11 | deployer | [`0xadcb6824…`](https://sepolia.etherscan.io/tx/0xadcb68240e8530d163eb408bee6024adb868accd129adff2db6a407518f13014) | `registerSpecification`: Personal Assistant Safety v1 |
| 12 | deployer | [`0x67c1114a…`](https://sepolia.etherscan.io/tx/0x67c1114aacceff5c020eae32931a80c716e5b48ae92695a1b3f32c63a51029b9) | `registerSpecification`: Swarm Shared Funds v1 |
| 13 | deployer | [`0xb7cc87ff…`](https://sepolia.etherscan.io/tx/0xb7cc87ff2b7a58cc69caedf8808037895b9adeca8a360ddcc97cb066bbfd0f08) | `adopt`: the principal's binding for the agent on the guarded account, guardian with suspend and resume rights, validity window 2025-10-09 to 2027-12-28 |
| 14 | deployer | [`0x17478f9c…`](https://sepolia.etherscan.io/tx/0x17478f9c01f2b69428f509a33daa627e97df7c9e189559207093c9f57f838131) | `presentBindings([bindingPersonalAssistant])` on the guarded account |
| 15 | deployer | [`0x71a13707…`](https://sepolia.etherscan.io/tx/0x71a137071fd580bfee104346522f42710b7c89d49b0b74a9f07e9b2b721cc2cb) | `adopt`: the organizer's binding for the swarm (charter), collective enforcement |
| 16 | agent | [`0x9987b26a…`](https://sepolia.etherscan.io/tx/0x9987b26a788dc2fbf45abe299e869a59476c6169f79fb117cdc91f550abaeb4a) | `adopt`: member A's binding derived from the charter (same pinned version, validity inside the parent's) |
| 17 | agent | [`0x35f8f590…`](https://sepolia.etherscan.io/tx/0x35f8f5908d21f1fa834389150a16b5c1332e8eb883108e44c73e867b9bc79c05) | `adopt`: the worker's own binding, naming the deployer (task publisher) as intervener with the suspend and resume rights |

## Phase 4: guard loop (transactions 18–23, blocks 12003414–12003428)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 18 | agent | [`0xf985a187…`](https://sepolia.etherscan.io/tx/0xf985a187ade1b2093d8d7d30e553fe77764a33fac8d8701e799b7b9a8c4ed511) | `borrow(100)` through probe and account: executed (`Attempt` ok, `Executed`, `Borrowed`) |
| 19 | guardian | [`0x7298090d…`](https://sepolia.etherscan.io/tx/0x7298090d3b88c54493105c4d1abdac1c3c718e3a5db6567f1ae32d569454d58f) | `suspend` with bits 9 (`RESTRICT_NO_NEW_RISK | RESTRICT_DERISK_ONLY`) and the `responseRef` `0x0a212ad7…` of `guardian-derisk-only.response.json`. The suspension is an intervener's, so the registry first records the guardian's standing stop against the deployer for the agent and the specification, `StopRecorded(deployer, subjectKey(agent), specRegistry, Personal Assistant Safety, guardian, bindingPersonalAssistant, 9, responseRef)`, then `BindingStateChanged(Active -> Suspended, 9, responseRef, actor = guardian)` |
| 20 | agent | [`0x4c74888b…`](https://sepolia.etherscan.io/tx/0x4c74888b2c5ad0d5a7187627014bc3188d486d470d27c8c006f51a37159f2d16) | `borrow(1)`: refused; the probe's `Attempt` event carries ok = false and the revert data `BindingNotSatisfied(NotSatisfied, [Suspended])` |
| 21 | agent | [`0xcee3c506…`](https://sepolia.etherscan.io/tx/0xcee3c506a1fda6a819edcb655457e9a768b33f50b0eed5b998d2d2470f286419) | `repay(40)`: executed under de-risk only (`Executed` with `underDerisk`, `Repaid`) |
| 22 | guardian | [`0xe4225a0c…`](https://sepolia.etherscan.io/tx/0xe4225a0cf015c84eaa245765c6c12407f7025eb4b605b9efd4eb27397132b3e8) | `resume`: the stop is the guardian's, so the guardian's own resume lifts it, `StopLifted(…, intervener = guardian, actor = guardian)`, then `BindingStateChanged(Suspended -> Active)`. The principal could not have lifted either the suspension or the stop |
| 23 | agent | [`0xe5f9410d…`](https://sepolia.etherscan.io/tx/0xe5f9410d6a959c5b5ba1ca2f3fdf59aeda40a33ff46460f0d03125205345863e) | `borrow(1)`: executed |

## Phase 5: tender loop (transactions 24–29, blocks 12003435–12003446)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 24 | deployer | [`0x7468b84e…`](https://sepolia.etherscan.io/tx/0x7468b84e18a55bebc4313cfc9b569f4d28125ef8fe18a5f9f05024084157c7cc) | task #21 minted on the live `TaskToken` with the adapter as acceptance authority (reward 0.001 ETH, two completions, 7-day judgment window; the sha256 and locator of `tender/task.json`) |
| 25 | deployer | [`0xf0fb68fe…`](https://sepolia.etherscan.io/tx/0xf0fb68fe028c3c10302fa130d6cc6ede2490370de6f3fe3fc011021270bff38d) | task #21 funded with 0.002 ETH (`TenderFunded`; the kernel moves the value into its escrow) |
| 26 | agent | [`0x5cc3c102…`](https://sepolia.etherscan.io/tx/0x5cc3c1023331ad93d4574d7323dd42bb9c346e86fa56a9333d5097eea777543b) | submission 1 (`result-worker.json`) |
| 27 | guardian | [`0x3056f2e3…`](https://sepolia.etherscan.io/tx/0x3056f2e30cb771cc9f6f5bab04c413bc7c623b53660fa9a75acdfc2871c823d4) | submission 2 (`result-unbound.json`) by the account that holds no binding |
| 28 | deployer | [`0x335f7ea3…`](https://sepolia.etherscan.io/tx/0x335f7ea3e53202d2545a3404cef6f3ff84da6f4185924d37103c03a3f1dc65df) | `judge(21, 1)`: `Judged(verdict = Satisfied, bindingIds = [bindingWorkerSelf], reasons = [None])`; the kernel's `acceptFulfillment` paid 0.001 ETH to the agent (`FulfillmentAccepted`) |
| 29 | deployer | [`0xd0f5ce90…`](https://sepolia.etherscan.io/tx/0xd0f5ce905c3d0c9bc07ba1e6a65eab2a69135da33bbec6a8e0a9c70ba6967183) | `judge(21, 2)`: `Judged(verdict = NotSatisfied, bindingIds = [0], reasons = [NoBinding])`; the kernel recorded the rejection (`FulfillmentRejected`) |

## Phase 6: stop loop (transactions 30–37, blocks 12003450–12003466)

The phase added for revisions 6 and 7 (Section 8.5 of the text): the task publisher's suspension of the worker's binding is a standing stop that the worker cannot escape by terminating the binding and adopting a fresh one, and that only the publisher lifts.

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 30 | deployer | [`0x201f18de…`](https://sepolia.etherscan.io/tx/0x201f18def0e46fabaf6aaa5702a17956f0d8699976a9c456892fbda88ed22fb7) | the publisher suspends `bindingWorkerSelf` with bits 16 (`RESTRICT_FULL_STOP`), a zero `responseRef` and the `reasonRef` `keccak256("report: deliverable misrepresented")`: `StopRecorded(agent, subjectKey(agent), specRegistry, Personal Assistant Safety, deployer, bindingWorkerSelf, 16, 0)`, then `BindingStateChanged(Active -> Suspended, 16, 0, actor = deployer)` |
| 31 | agent | [`0xda29c145…`](https://sepolia.etherscan.io/tx/0xda29c1458b07ac43d8216339f09df407b6feb398b7c1e8bde1f6554ac0b4d1e5) | the worker terminates `bindingWorkerSelf` (`reasonRef` `keccak256("replaced")`): `BindingStateChanged(Suspended -> Terminated)`; the record keeps `suspendedBy` = deployer and `restrictions` = 16, and the stop stands |
| 32 | agent | [`0x0f551ace…`](https://sepolia.etherscan.io/tx/0x0f551ace2a9e046df7d4e03b72d242b1e07e0d5ac9d48688cd0d6c43b48e8eac) | the worker adopts a fresh binding under the next salt, same document, same interveners (`bindingWorkerSelfFresh`): `Active`, satisfied on its own terms |
| 33 | agent | [`0x67af77dc…`](https://sepolia.etherscan.io/tx/0x67af77dc9fdd9e23e6d782f305af6856503dd5733475039a3595eced9ea4fbb8) | submission 3 (`result-worker-after-stop.json`) |
| 34 | agent | [`0xf125e2ae…`](https://sepolia.etherscan.io/tx/0xf125e2ae49b948bf9ff89069f279ca43fda1c9fd3b3d834e45e124e0ff91b914) | the worker calls `judge(21, 3)` itself: `Judged(verdict = NotSatisfied, bindingIds = [bindingWorkerSelfFresh], reasons = [StoppedByIntervener])`; the fresh binding is active and satisfies every other test of the clause, but the clause names the deployer and the deployer's stop stands, so the kernel recorded the rejection (`FulfillmentRejected`) |
| 35 | deployer | [`0xb4fe9c50…`](https://sepolia.etherscan.io/tx/0xb4fe9c50718f5beeaa3068e66dc24008247b1dff6287e9312a2e01005019294d) | the publisher lifts its stop: `liftStop(agent, subjectKey(agent), specRegistry, Personal Assistant Safety, deployer, keccak256("report withdrawn"))`, `StopLifted(…, intervener = deployer, actor = deployer, reasonRef)`. The terminated record is untouched; `Terminated` accepts no `resume` |
| 36 | agent | [`0x21424726…`](https://sepolia.etherscan.io/tx/0x2142472605549a683fc304c143c1b1a03745754cccbe8cebc52ad5620b9fcfef) | submission 4 (`result-worker-after-lift.json`) |
| 37 | agent | [`0x004bc200…`](https://sepolia.etherscan.io/tx/0x004bc200b2da3189f0fb730d86b5dc4ec0300779aef0622040736e00237497ba) | the worker calls `judge(21, 4)`: `Judged(verdict = Satisfied, bindingIds = [bindingWorkerSelfFresh], reasons = [None])`; the kernel paid 0.001 ETH to the agent, the tender's second and last completion (`FulfillmentAccepted`) |

## Phase 7: lifecycle (transactions 38–42, blocks 12003470–12003478)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 38 | deployer | [`0x41917a8e…`](https://sepolia.etherscan.io/tx/0x41917a8e25dd12b0b5de9028e08af65b30c134678e715e1fe2bc59105629277d) | the principal suspends its own binding with bits 16 (`RESTRICT_FULL_STOP`) and the `responseRef` `0x151f65ad…` of `principal-full-stop.response.json`; the adopter's own suspension records no stop (one log) |
| 39 | agent | [`0xae429388…`](https://sepolia.etherscan.io/tx/0xae42938806d27e06500b815512dba1d84acaf1b8f4b631cff40973b99e8fc99a) | `repay(1)`: refused, `BindingNotSatisfied(NotSatisfied, [Suspended])`; full stop closes de-risking too |
| 40 | deployer | [`0x451cff7d…`](https://sepolia.etherscan.io/tx/0x451cff7db2dd5aefafd66cc0cc2add53afbc852ae19cc2b8b094d69ea96ce22b) | `resume` (the principal lifts its own suspension) |
| 41 | deployer | [`0xbe7152b1…`](https://sepolia.etherscan.io/tx/0xbe7152b13459d4e2e2f44c204f7229a3cffc5ec015a7f35f526dca6255d2ba74) | `terminate(bindingSwarmCharter)` |
| 42 | deployer | [`0x061533b6…`](https://sepolia.etherscan.io/tx/0x061533b67247372ed4d05a3099aedb128b55d1ee37871799972bb6415f292516) | `deprecateVersion(Swarm Shared Funds, 1)` |

## State after the run

Read from Sepolia at block 12003525 with `eth_call`; every value equals the mirror's except the timestamps, which are Sepolia's block times.

- `bindingOf(bindingPersonalAssistant)`: `Active`, `restrictions` 0, `responseRef` 0, `suspendedBy` 0.
- `bindingOf(bindingSwarmCharter)`: `Terminated`.
- `bindingOf(bindingSwarmMemberA)`: `Active` with `parentBindingId` = the charter; the record itself is untouched by the parent's termination.
- `bindingOf(bindingWorkerSelf)`: `Terminated`, `restrictions` 16, `suspendedBy` = deployer: the record still shows the stop it was recorded through.
- `bindingOf(bindingWorkerSelfFresh)`: `Active`, `restrictions` 0, `suspendedBy` 0.
- `stopOf(agent, subjectKey(agent), specRegistry, Personal Assistant Safety, deployer)`: empty (lifted in transaction 35); `stopOf(deployer, subjectKey(agent), specRegistry, Personal Assistant Safety, guardian)`: empty (lifted in transaction 22). `stopLifterOf(deployer)` and `stopLifterOf(guardian)`: zero, no lifter was named.
- `checkBinding(bindingSwarmMemberA, {specRegistry, Swarm Shared Funds})`: `NotSatisfied`, `ParentNotSatisfied`, response set 0.
- `checkBinding(bindingWorkerSelf, {specRegistry, Personal Assistant Safety, interveners: [(deployer, suspend | resume)]})`: `NotSatisfied`, `Terminated`.
- `checkBinding(bindingWorkerSelfFresh, …same clause…)`: `Satisfied`; `checkBinding(bindingPersonalAssistant, {specRegistry, Personal Assistant Safety})`: `Satisfied`.
- `ASFTaskTenderAdapter.evaluate(agent)`: `Satisfied` through `bindingWorkerSelfFresh`; `evaluate(guardian)`: `NotSatisfied`, `NoBinding`.
- `versionOf(Swarm Shared Funds, 1).deprecated` = true; `versionOf(Personal Assistant Safety, 1).deprecated` = false; `latestVersion(Swarm Shared Funds)` = 1.
- `ASFGuardedAccount.status()`: `Satisfied`, reasons `[None]`, response sets `[0]`; `presentedBindings()` = `[bindingPersonalAssistant]`.
- `supportsInterface(0xcff7f826)` on the binding registry: true (`0x2db6eb8a` and `0x1ff33bef`, the revision-6 and revision-5 identifiers: false); `supportsInterface(0x9bddde77)` on the specification registry: true.
- `countBySubject(subjectKey(agent), agent)` = 3: the member binding, the terminated worker binding and the fresh one.
- `TaskToken.nextId` = 22; task #21 has four submissions, two completions (1 and 4 accepted, 2 and 3 rejected) and an escrow balance of 0 after both rewards.

Balances after the run: deployer 0.01293 ETH, agent 0.01326 ETH (two rewards of 0.001 ETH less gas), guardian 0.00581 ETH.

## Reproducing the checks

```
forge build
# runtime code on chain versus the local build (addresses in deployments/sepolia-rev7.json):
cast code 0x136E2a88e1B518342CD997423BDa69Dd2c68e919 --rpc-url $SEPOLIA_RPC_URL
# the stop that was lifted in transaction 35 (all zero now):
cast call 0x136E2a88e1B518342CD997423BDa69Dd2c68e919 "stopOf(address,bytes32,address,bytes32,address)" \
  0x08FcB3bd9c4F171b1cba69Be2CA9e79e80f9eA6e 0x10c46d6e66c66fda3fdb02443d1dfbc8f8fb8750e105fc89704db2fab36706da \
  0x9110b622a17F83065f1e9773D961EB10672932e5 0x5ed86852f9fd8c449303e7ef3db3fe10f6a412f25c9321ac125d56ab6f2b0e2a \
  0xf12AFe29c9Ec5f66f669D7E388E0baE7Dc2f3eCe --rpc-url $SEPOLIA_RPC_URL
# the terminated worker binding still showing the stop it carried:
cast call 0x136E2a88e1B518342CD997423BDa69Dd2c68e919 "bindingOf(bytes32)" 0xc634bead52eeaddff2e2947dd31e27ec04d2749e45475b5074d165529f2736f4 --rpc-url $SEPOLIA_RPC_URL
```

The hashes pinned on chain are the content hashes of the files under `deployments/sepolia-rev7/examples/`: Keccak-256 over the JCS-canonical form of each document (`tools/lib/canonical.js`), as `deployments/sepolia-rev7/examples/manifest.json` lists them next to the identifiers; the task and result documents under `tender/` are hashed with sha256 over the file bytes, as the kernel expects.

The deployer keeps publishing control of the two specifications and the adopter role of the principal's and organizer's bindings; the keys are session-generated and hold no other value.
