# Sepolia evidence run

This record is of revision 5 of the reference implementation (`IASFBindingRegistry` `0x1ff33bef`, one linked library). Revision 6 changed the registry and its libraries (standing stops, Section 8.5 of the text) and is not part of this run.

The evidence run of `script/SepoliaEvidence.s.sol` was executed on Sepolia on 2026-10-26 between blocks 11994931 (02:13:48 UTC) and 11995051 (02:38:00 UTC): 36 transactions across the five phases of the runbook, all with status 1, 72,160,025 gas in total, 0.00722 ETH in fees at a priority fee of 0.1 gwei over a base fee of a few tens of wei. The machine-readable record with every transaction hash, block, gas and effective price is `deployments/sepolia.transactions.json`; the addresses and identifiers written by the phases are `deployments/sepolia.json`; the example documents whose hashes went on chain are `deployments/sepolia/examples/`, served from this repository as the specification and parameter locators.

Three session-generated keys took part, as described in the runbook: the deployer `0xf12AFe29c9Ec5f66f669D7E388E0baE7Dc2f3eCe` (publisher of both specifications, principal of the guarded account, swarm organizer, task publisher), the agent `0x08FcB3bd9c4F171b1cba69Be2CA9e79e80f9eA6e` (operator of the guarded account through the probe, swarm member A, worker) and the guardian `0xc3e6965d427Abc91c1E33c78a986df2dBaDC660E` (suspend and resume rights on the principal's binding; the unbound submitter in the tender loop). The deployer was funded with 0.05 ETH; it funded the agent with 0.012 ETH and the guardian with 0.006 ETH in phase 1.

## Contracts

| Contract | Address | Deployment | Gas used |
|---|---|---|---|
| `ASFEvaluation` (external library) | `0x663B84f1BfcE37bE4a78358b0301B5d5E5079269` | [`0x8b797dd4…`](https://sepolia.etherscan.io/tx/0x8b797dd463ac3cb116dfc3430d42487f56746ddba76fe4b7fca3fa0d99de04ec) through the deterministic CREATE2 factory `0x4e59b44847b379578588920ca78fbf26c0b4956c` | 6,005,651 |
| `ASFSpecificationRegistry` | `0x1939665F5905d0d9135Da4f27e36f1B8c84E014b` | [`0xe3ce298e…`](https://sepolia.etherscan.io/tx/0xe3ce298ed2f93bca27415855176e1599d70364b635f3a5c9df160b1037220c1d) | 5,248,776 |
| `ASFBindingRegistry` | `0xc3e1A1Cb021Ab96EBBeD3279018840016114A5c4` | [`0x2a1d18df…`](https://sepolia.etherscan.io/tx/0x2a1d18df71e7586df7ec79ca018a7782667bc93b754b00fbae0c903d1dae6397) | 15,146,485 |
| `LendingDesk` (target) | `0x78A466eb7A5FB8E101b02bf3EAee9E6f9C701d9E` | [`0x7cca4a67…`](https://sepolia.etherscan.io/tx/0x7cca4a6773bc6eb6ed81ba9d197c9aa76ec1a5c6c86286f99b2e208c98e59111) | 1,010,339 |
| `ASFGuardedAccount` | `0x40AaD5106A7a13B15892E53099f6bD06bCF80aD3` | [`0x8f25bd3b…`](https://sepolia.etherscan.io/tx/0x8f25bd3b939eebb880b537a370f3314b85bca0cb5c4757078863435a7c2cb671) | 10,065,125 |
| `OperatorProbe` | `0xD68B1bB09399Ca6acc802Bf2E2A4346ec810da77` | [`0xd1a3fdd9…`](https://sepolia.etherscan.io/tx/0xd1a3fdd9f1f14a246e20b1195b48a896e0b89a54c8d0d2698f8bee17ba9c7e04) | 1,824,426 |
| `ASFTaskTenderAdapter` | `0x51772fabFB757Fb5A4186c0435Ec4fa76D75CE4e` | [`0x04b22fcc…`](https://sepolia.etherscan.io/tx/0x04b22fcc23ab61b002cb7f17f58fdeb726a2f5386b46293dda7f37111e742735) | 10,987,806 |
| `TaskToken` (live TASK-KERNEL v3.0, not ours) | `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` | — | — |

All seven contracts are verified on Sourcify (API v2, 2026-10-26 03:03 UTC) with a runtime and a creation match: solc 0.8.30+commit.73712a01, optimizer 200 runs, via IR, EVM version cancun, metadata without a bytecode hash, and `ASFEvaluation` linked at its address for the registry. Sourcify forwarded the verifications to Blockscout (`eth-sepolia.blockscout.com`) and Routescan. Lookup: `https://sourcify.dev/server/v2/contract/11155111/<address>`. Independently of Sourcify, the runtime code read back from Sepolia for each contract equals the `deployedBytecode` of the local `forge build` once the linked library address and the immutables are substituted; the comparison is reproducible from `deployments/sepolia.transactions.json` and the compiler settings in `foundry.toml`.

Specification identifiers: Personal Assistant Safety v1 `0x9a6fdb5d3c923d152c70b099de725b3a672b851b8c10978bbe651fa8b383e30d`, Swarm Shared Funds v1 `0xb4ca2e72024eb3b38c408f5ad314728b91391b431977988520f860d45263e07a`. Binding identifiers: principal's binding for the agent `0xaa3ca3619275fa23c5a1f05251d45147195b017b7c3f3fea73c2c072b89866e0`, swarm charter `0x4a22a8a6c480537cd2bcc1f4cc475b47e54e0f3bc875374671d2b2a2f8989c6a`, derived member binding `0x9415d132202a591234e7e67596649dec866841a948c66ab1685f54e05405b4ed`, worker's own binding `0x3aa2ecd83340f675d589feeeb2b34dcb9e85ee16e6349a0ee06d7c8f1c032a53`. The on-chain `specId` of each specification equals the manifest's, as the script checks before adopting.

## How the run was executed

Sepolia has been running the Glamsterdam upgrade since 2026-10-06. Two of its changes decided how this run had to be executed. The gas schedule prices state and code roughly ten times higher than the schedule Anvil models: a plain value transfer cost 204,600 gas, the 519-byte `LendingDesk` 1,010,339 gas, and deployment cost grows by about 1,400 gas per byte of deployed code. And a transaction may use at most 16,777,216 gas (EIP-7825), which `eth_estimateGas` and `eth_call` enforce as well.

The first attempt, deploying `ASFSpecificationRegistry` with the gas limit of the Anvil rehearsal (1,308,630), ran out of gas: transaction [`0xbccdcab9…`](https://sepolia.etherscan.io/tx/0xbccdcab96d8b13cde613d1d5d2fc342909c90cfba59ad0817a10dcc2f66b3f37), block 11994546, status 0, 0.00131 ETH burned, nonce 0 of the deployer consumed. The revision-4 `ASFBindingRegistry` (13.3 KB of runtime code) was then found to need about 20.9 million gas to deploy, above the per-transaction cap, so it could not be deployed on Sepolia at all. The registry's evaluation (Section 10.1 of the ERC, the combinators, the requirement validation and the response-set rule over a derivation chain) was moved into `ASFEvaluation`, a library linked externally and called with the registry's storage, and the project was switched to via-IR compilation. The registry's runtime code fell to 9,660 bytes and its deployment to 15,146,485 gas, 90% of the cap; the ABI, the interface identifier (`0x1ff33bef`), the `requirementId` encoding and every test result are unchanged by the split, and the library never writes to the registry's storage. Foundry deploys such a library through the deterministic CREATE2 factory, which is why `ASFEvaluation`'s address does not depend on the deployer's nonce.

The transactions were then produced by `forge script` against a local Anvil mirror of the Sepolia state: chain id 11155111, the live `TaskToken` code and storage copied from Sepolia, the three accounts with their live balances and nonces (the deployer at nonce 1). Each transaction's calldata and every contract address therefore equal the mirror's. The 36 transactions were signed with the three keys at the mirror's nonces, with gas limits taken from live estimates, and relayed to Sepolia as raw transactions through a public RPC endpoint, phase by phase: transactions whose effect depends on the order of two different senders (the guard loop, the two submissions, the lifecycle) were sent one at a time and confirmed before the next. No transaction failed and no nonce was skipped. The record in `deployments/sepolia.transactions.json` states this execution path.

## Phase 1: deploy (transactions 0–11, block 11994931 and 11994982)

Library, both registries and the lending-desk target in one block; the guarded account, its operator probe, the three configuration calls (`setOperator(probe)`, `setDeriskAllowed(desk, repay, true)`, `setDeriskAllowed(desk, cancelOrder, true)`), the tender adapter and the two funding transfers in the next. The adapter is bound to the live `TaskToken`; its template requires the fulfiller's own adoption of Personal Assistant Safety v1 with the deployer as an intervener holding the suspend right.

## Phase 2: relink

The example documents under `deployments/sepolia/examples/` were relinked with the chain id, the registries and the three accounts (`tools/build-examples.js --chain-id 11155111`), validated against the schemas, and their hashes written to `manifest.json`; the specification and binding parameter locators point at the raw files of this repository on the `main` branch.

## Phase 3: publish and adopt (transactions 12–18, blocks 11994992 and 11994998)

| # | Sender | Transaction | Effect |
|---|---|---|---|
| 12 | deployer | [`0x5a9f2c50…`](https://sepolia.etherscan.io/tx/0x5a9f2c505138faaa4a6f38992aa14e31ebdae84348a2d0018320baa790bf56a8) | `registerSpecification`: Personal Assistant Safety v1 |
| 13 | deployer | [`0xc1b4ff16…`](https://sepolia.etherscan.io/tx/0xc1b4ff16f9abd2da7e1a39fc9de0a0ae4dd0dce9a4d65653ba6c8db7ad729bb0) | `registerSpecification`: Swarm Shared Funds v1 |
| 14 | deployer | [`0x6e38bc57…`](https://sepolia.etherscan.io/tx/0x6e38bc57a088f339b480be49d64f1646e723f9b831edcdca99562f8726f09f0e) | `adopt`: the principal's binding for the agent on the guarded account, guardian with suspend and resume rights, validity window 2025-10-09 to 2027-12-28 |
| 15 | deployer | [`0xc98599dc…`](https://sepolia.etherscan.io/tx/0xc98599dcf600eee530fe3af8abb0c024fec8313817363aea2efc941a14a57e20) | `presentBindings([bindingPersonalAssistant])` on the guarded account |
| 16 | deployer | [`0x18348cd6…`](https://sepolia.etherscan.io/tx/0x18348cd6da7d01c3d2a92cab7e056e6259d24533f515e0aed46bc517cc1d640a) | `adopt`: the organizer's binding for the swarm (charter), collective enforcement, executor `0x…ac0df0` as intervener |
| 17 | agent | [`0x56d56960…`](https://sepolia.etherscan.io/tx/0x56d569605261f15e3b540aef819bc254848e87733337606970670e21f79cb25e) | `adopt`: member A's binding derived from the charter (same pinned version, validity inside the parent's) |
| 18 | agent | [`0x72a86377…`](https://sepolia.etherscan.io/tx/0x72a86377388c6601c14eb807a908efaa9ac68c9cdf06e959f5e7d4ba3515784c) | `adopt`: the worker's own binding, naming the deployer (task publisher) as intervener with the suspend right |

## Phase 4: guard loop (transactions 19–24, blocks 11995003–11995020)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 19 | agent | [`0xea2e4bf6…`](https://sepolia.etherscan.io/tx/0xea2e4bf65130670446935cefb0b00f5101d27e8bee6fcf6d755e3abe707a8d83) | `borrow(100)` through probe and account: executed (`Attempt` ok, `Executed`, `Borrowed`) |
| 20 | guardian | [`0xa5323a76…`](https://sepolia.etherscan.io/tx/0xa5323a76814009b6ac448267d148bc17b03b9e797f9dcc75dd8a1a15a9228966) | `suspend` with bits 9 (`RESTRICT_NO_NEW_RISK | RESTRICT_DERISK_ONLY`) and the `responseRef` `0xae4dd825…` of `guardian-derisk-only.response.json`; `BindingStateChanged(Active -> Suspended, 9, responseRef, by = guardian)` |
| 21 | agent | [`0x02cb5a95…`](https://sepolia.etherscan.io/tx/0x02cb5a95d7db5792df336d4ae267649031d89b113382e8e2a3d9bc629d2dac04) | `borrow(1)`: refused; the probe's `Attempt` event carries ok = false and the revert data `BindingNotSatisfied(NotSatisfied, [Suspended])` |
| 22 | agent | [`0x21935f34…`](https://sepolia.etherscan.io/tx/0x21935f3412c413fef9e511e360812eac02750a5c61c6af0631caced7645107b3) | `repay(40)`: executed under de-risk only (`Executed` with `underDerisk`, `Repaid`) |
| 23 | guardian | [`0xcdd67926…`](https://sepolia.etherscan.io/tx/0xcdd67926b3f023ebe382028cbeb8cb4551eccb60bf1e9e90ef7694b2d6367469) | `resume`: the suspension was the guardian's, so only the guardian (holding the resume right) could lift it |
| 24 | agent | [`0x321e6f08…`](https://sepolia.etherscan.io/tx/0x321e6f080740849f53f0cad4b95f5fc8cda522a3dac968597c485a875b0bb03f) | `borrow(1)`: executed |

## Phase 5: tender loop (transactions 25–30, blocks 11995026–11995040)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 25 | deployer | [`0xe40c02d0…`](https://sepolia.etherscan.io/tx/0xe40c02d03f467322db4c08ad06ed1ab816107a1ee0d2794ca359d5eb414ab374) | task #20 minted on the live `TaskToken` with the adapter as acceptance authority (reward 0.001 ETH, two completions, 7-day judgment window) |
| 26 | deployer | [`0x2bea4508…`](https://sepolia.etherscan.io/tx/0x2bea4508ea1cf2ad793e73b1ad473e25a5aa01f9ad93b2a53fbd50ee2f47e727) | task #20 funded with 0.002 ETH |
| 27 | agent | [`0x194aa99e…`](https://sepolia.etherscan.io/tx/0x194aa99ecb1b2320344291e61d221c9d946182dbf3073b199e662f11a1549fde) | submission 1 (`result-worker.json`) |
| 28 | guardian | [`0x72d68668…`](https://sepolia.etherscan.io/tx/0x72d68668ab52fc720733077e81914d9aea55b5b78571d140d4b409ed24318b7c) | submission 2 (`result-unbound.json`) by the account that holds no binding |
| 29 | deployer | [`0xad240865…`](https://sepolia.etherscan.io/tx/0xad240865eb8bec6922d4b5c72df52f9825074080485ddd8dc810a5cac472988c) | `judge(20, 1)`: `Judged(verdict = Satisfied, bindingIds = [bindingWorkerSelf], reasons = [None])`; the kernel's `acceptFulfillment` paid 0.001 ETH to the agent |
| 30 | deployer | [`0x58396ae0…`](https://sepolia.etherscan.io/tx/0x58396ae0498fbb5e5fbe969431a0743f1c315ff36d500b3fcb51179b8ccdd7d4) | `judge(20, 2)`: `Judged(verdict = NotSatisfied, bindingIds = [0], reasons = [NoBinding])`; the kernel recorded the rejection |

## Phase 6: lifecycle (transactions 31–35, blocks 11995045–11995051)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 31 | deployer | [`0xaa1f1ad6…`](https://sepolia.etherscan.io/tx/0xaa1f1ad66e2eea657547b3fcb985183de5dba54360798a0765dfe511ba132daa) | the principal suspends its own binding with bits 16 (`RESTRICT_FULL_STOP`) and the `responseRef` of `principal-full-stop.response.json` |
| 32 | agent | [`0x87986467…`](https://sepolia.etherscan.io/tx/0x879864671271bf61fdbe7132187469dd3c0eb3868dd4bb87bd42eda52e847b50) | `repay(1)`: refused, `BindingNotSatisfied(NotSatisfied, [Suspended])`; full stop closes de-risking too |
| 33 | deployer | [`0x27bb1bcc…`](https://sepolia.etherscan.io/tx/0x27bb1bcc28465bc2f6203e6ada0c7c825580892a407f2f368c937eaaf9344205) | `resume` (the principal lifts its own suspension) |
| 34 | deployer | [`0xb032f58d…`](https://sepolia.etherscan.io/tx/0xb032f58dc9e54d07f0bfca22c615eea7c7915134041b127bd6e8b1cbe191f64e) | `terminate(bindingSwarmCharter)` |
| 35 | deployer | [`0x15b2262a…`](https://sepolia.etherscan.io/tx/0x15b2262a501db59f54c57560d88e04822a439a8fa12a47f901654fff27c8ec09) | `deprecateVersion(Swarm Shared Funds, 1)` |

## State after the run

Read from Sepolia at block 11995077 with `eth_call`:

- `bindingOf(bindingPersonalAssistant)`: `Active`, `restrictions` 0, `responseRef` 0, `suspendedBy` 0, `stateChangedAt` 1792982280 (transaction 33).
- `bindingOf(bindingSwarmCharter)`: `Terminated`, `stateChangedAt` 1792982280 (transaction 34).
- `bindingOf(bindingSwarmMemberA)`: `Active` with `parentBindingId` = the charter; the record itself is untouched by the parent's termination.
- `checkBinding(bindingSwarmMemberA, {specRegistry, Swarm Shared Funds})`: `NotSatisfied`, `ParentNotSatisfied`, response set 0 (the chain is terminated, so no path stays open).
- `checkBinding(bindingWorkerSelf, {specRegistry, Personal Assistant Safety, interveners: [(deployer, RIGHT_SUSPEND)]})`: `Satisfied`.
- `checkBinding(bindingPersonalAssistant, {specRegistry, Personal Assistant Safety})`: `Satisfied`.
- `versionOf(Swarm Shared Funds, 1).deprecated` = true; `versionOf(Personal Assistant Safety, 1).deprecated` = false; `latestVersion(Swarm Shared Funds)` = 1.
- `ASFGuardedAccount.status()`: `Satisfied`, reasons `[None]`, response sets `[0]`.
- `supportsInterface(0x1ff33bef)` on the binding registry and `supportsInterface(0x9bddde77)` on the specification registry: true.
- `TaskToken.nextId` = 21; task #20 completed with submission 1 accepted and submission 2 rejected.

Balances after the run: deployer 0.02221 ETH, agent 0.01233 ETH (0.012 funded, less gas, plus the 0.001 ETH reward), guardian 0.00593 ETH.

## Reproducing the checks

```
forge build
# runtime code on chain versus the local build (addresses in deployments/sepolia.json):
cast code 0xc3e1A1Cb021Ab96EBBeD3279018840016114A5c4 --rpc-url $SEPOLIA_RPC_URL
# the state reads above, for example:
cast call 0xc3e1A1Cb021Ab96EBBeD3279018840016114A5c4 "bindingOf(bytes32)" 0x4a22a8a6c480537cd2bcc1f4cc475b47e54e0f3bc875374671d2b2a2f8989c6a --rpc-url $SEPOLIA_RPC_URL
cast call 0xc3e1A1Cb021Ab96EBBeD3279018840016114A5c4 \
  "checkBinding(bytes32,(address,bytes32,uint32[],address,bytes32,bytes32,uint16,(address,uint8)[]))" \
  0x9415d132202a591234e7e67596649dec866841a948c66ab1685f54e05405b4ed \
  "(0x1939665F5905d0d9135Da4f27e36f1B8c84E014b,0xb4ca2e72024eb3b38c408f5ad314728b91391b431977988520f860d45263e07a,[],0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000,0,[])" \
  --rpc-url $SEPOLIA_RPC_URL
```

The hashes pinned on chain are the content hashes of the files under `deployments/sepolia/examples/`; `node tools/validate.js` recomputes them and `deployments/sepolia/examples/manifest.json` lists them next to the identifiers.

The deployer keeps publishing control of the two specifications and the adopter role of the principal's and organizer's bindings; the keys are session-generated and hold no other value.
