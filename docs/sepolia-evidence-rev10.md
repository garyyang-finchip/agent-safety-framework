# Sepolia evidence run, revision 10

This record is of revision 10 of the reference implementation (`IASFBindingRegistry` `0xcff7f826`; the registry's evaluation and lifecycle in two externally linked libraries). It is the third run of `script/SepoliaEvidence.s.sol` on Sepolia. The first, with the revision-5 contracts, is recorded in `docs/sepolia-evidence.md`; the second, with the revision-7 contracts, in `docs/sepolia-evidence-rev7.md`. Both stay as they were. The three runs share the three accounts and the live `TaskToken`; nothing else.

The run was executed on 2026-11-15 between blocks 12140959 (14:57:00 UTC) and 12140990 (15:03:12 UTC): 58 transactions across the seven transaction phases of the runbook (deploy, publish and adopt, guard loop, tender loop, stop loop, lifecycle, and the set loop that revision 8 added), all with status 1, 92,884,224 gas in total, 0.00464 ETH in fees at a priority fee of 0.05 gwei over a base fee of 15 to 18 wei (0.00396 ETH paid by the deployer, 0.00057 by the agent, 0.00012 by the guardian). The machine-readable record with every transaction hash, block, gas and effective price is `deployments/sepolia-rev10.transactions.json`; the addresses and identifiers written by the phases are `deployments/sepolia-rev10.json`; the relinked documents whose hashes went on chain are under `deployments/sepolia-rev10/examples/`.

The same three session-generated keys took part as in the earlier runs: the deployer `0xf12AFe29c9Ec5f66f669D7E388E0baE7Dc2f3eCe` (publisher of both specifications, principal of the guarded account, swarm organizer, task publisher), the agent `0x08FcB3bd9c4F171b1cba69Be2CA9e79e80f9eA6e` (operator of the guarded account through the probe, swarm member A, worker) and the guardian `0xc3e6965d427Abc91c1E33c78a986df2dBaDC660E` (suspend and resume rights on the principal's binding and a required intervener of the guarded account's clause; the unbound submitter in the tender loop). No funding transfers were needed.

## Contracts

| Contract | Address | Deployment | Gas used |
|---|---|---|---|
| `ASFEvaluation` (external library) | `0x7Dad89304047AC97814405921d140616f1708032` | [`0x923a29af…`](https://sepolia.etherscan.io/tx/0x923a29afacbedae79fea1b688fd8ffe033e90fa0e19a75295e4d7526228ded46) through the deterministic CREATE2 factory `0x4e59b44847b379578588920ca78fbf26c0b4956c` | 6,414,013 |
| `ASFLifecycle` (external library) | `0x00706AD939f32e8e40833658485b410Def0662Eb` | [`0x27a40ff5…`](https://sepolia.etherscan.io/tx/0x27a40ff5b505d89411e1161a39e4014b161702487cea50ac3180aa2104e24e18) through the same factory | 9,434,570 |
| `ASFSpecificationRegistry` | `0x9cC8A10207F6B3E54241657cD040580939dDef5A` | [`0x4f1ce95d…`](https://sepolia.etherscan.io/tx/0x4f1ce95d073473779a58d2ae99a7f5ffa4eef1f6ed7b2f975a9a32ef84f62c80) | 5,248,776 |
| `ASFBindingRegistry` | `0x17D5A20094d5C97C53d921b101Fe8A9eE7c031D7` | [`0xccf61279…`](https://sepolia.etherscan.io/tx/0xccf61279b8a4d3c80e6b13e7afd7a0109da32917357148cdbe25c3b42f56d4be) | 12,018,026 |
| `LendingDesk` (target) | `0xe8E77A1dD2b39B3f2C63e8f1528287d05758E9B2` | [`0x73807cae…`](https://sepolia.etherscan.io/tx/0x73807caec2d4802ce72f011afe9951b674e0cfab934580ac1ad7913eb0480ebe) | 1,010,339 |
| `ASFGuardedAccount` | `0xb2E426d9b2A6f9A884ff9303288949267D76863D` | [`0x72ba44b1…`](https://sepolia.etherscan.io/tx/0x72ba44b137b03e865a46f1e3e294fcfd874207724e28b3abc4d53e75c95f6afe) | 12,049,503 |
| `OperatorProbe` | `0xf4217a47323b5212172F308A4Be1B862b702bBd7` | [`0xb6274c38…`](https://sepolia.etherscan.io/tx/0xb6274c386876afa1aab7e03f7babe2acb27ac2fb5007242f99a04f5efa09c5de) | 1,824,426 |
| `ASFTaskTenderAdapter` | `0x2b7662128D9bc8Bd59E4a1206C19EE71be9A8cFf` | [`0x319ab982…`](https://sepolia.etherscan.io/tx/0x319ab982379b5495dc257f653203e0e0fb64224f3d8ee848448af9168295e315) | 11,066,793 |
| `TaskToken` (live TASK-KERNEL v3.0, not ours) | `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` | — | — |

The registry's runtime code is 7,637 bytes (`ASFLifecycle` 5,963, `ASFEvaluation` 4,010); its deployment used 12,018,026 gas, 72% of the per-transaction cap of 16,777,216.

All eight contracts are verified on Sourcify (API v2, 2026-11-15 15:00 UTC) with a runtime and a creation match: solc 0.8.30+commit.73712a01, optimizer 200 runs, via IR, EVM version cancun, metadata without a bytecode hash, `ASFEvaluation` and `ASFLifecycle` linked at their addresses for the registry. The sources submitted were the files of this repository at the paths of the standard JSON input, fetched from the `main` branch and checked against the local hashes before submission. Lookup: `https://sourcify.dev/server/v2/contract/11155111/<address>`.

Specification identifiers: Personal Assistant Safety v1 `0xc2675934f7593f209b8963d08bcabc03726258dd086c0306a9eed0ab88d43bf6`, Swarm Shared Funds v1 `0xc923ee99b7d95d6af3cff3222c121d24e3452e23cd8e49a1f809c235df3414d9`. Binding identifiers: principal's binding for the agent `0x2308770d4b9d0e74bc9aad981510eb17021519510e3a248bcdb98b93895274db`, swarm charter `0x82369816cb8c1be57bce25438f1011f1007bf256fecc619ae9b80074d7fa8b40`, derived member binding `0xd17494485bf3a6e4416a92e4acb31a96191b408c93a1bafa65baa49bba378bbd`, worker's own binding `0xe990ce659d23c6327fe7f34bc9ef0b9554f700a02f842ab27233c6a3b406f333`, the worker's fresh binding `0x757a71b0b1f627fec0a912580478344d04e9fdeb80efe38b54d1713726e6febe`, the principal's sibling binding `0x12d45b618f00c924fcb6d8275f9f66c9759b1927707d5f6336893e652e7e346b` and fresh binding `0x1ce334a59bb3e562271751a47b28fcddaccaad4b08d59532698c9a73b0a4f714`. Tender: task #52 on the live `TaskToken`.

## How the run was executed

As in the earlier runs (see `docs/sepolia-evidence.md` for the gas schedule and the per-transaction cap of Sepolia's Glamsterdam upgrade), the transactions were produced by `forge script` against a local Anvil mirror of the Sepolia state: chain id 11155111 and the three accounts with their live balances and nonces (deployer 52, agent 22, guardian 6). At the live `TaskToken` address the mirror carried the runtime code of the vendored TASK-KERNEL v3.0 source in `test/fixtures/task-token/` (the source the live token was built from, compiled here with this repository's settings, so the bytecode differs from the live token's) together with the live values of the four non-zero storage slots of the live token: its name, its symbol, its next token id (52) and its reentrancy flag. The earlier runs copied the live token's bytecode instead.

The 58 transactions were signed with the three keys at the mirror's nonces, with a 0.05 gwei priority fee and gas limits of twelve times the mirror's gas plus 300,000, capped at 16,777,216 (Sepolia used 5.1 times the mirror's gas in total; the largest deployment, the guarded account, used 12,049,503). They were relayed to Sepolia as raw transactions through a public RPC endpoint in 25 batches, one per run of consecutive transactions from the same sender, each batch confirmed before the next was sent, so that every step whose effect depends on the order of two senders landed in a later block than the step before it. The three nonces, the token's next id and the absence of code at the two library addresses were checked against Sepolia before the first batch. No transaction failed and no nonce was skipped; the relay took 6 minutes 38 seconds.

Every application log of the 58 Sepolia receipts equals the corresponding log of the mirror, the `TaskToken`'s included (compared as SHA-256 digests of address, topics and data, transaction by transaction). Sepolia's receipts carry four logs the mirror's do not: the EIP-7708 transfer logs (emitted from the system address `0xffff…fffe`) for the three ETH movements of the tender, 0.002 ETH from the deployer into the kernel's escrow in transaction 25 (two logs), and 0.001 ETH from the escrow to the agent in transactions 28 and 37. Anvil does not emit them.

## Phase 1: deploy (transactions 0–10, block 12140959)

Both libraries, both registries, the lending-desk target, the guarded account, its operator probe, the three configuration calls and the tender adapter, all in one block. The guarded account's requirement is the deployer's adoption of Personal Assistant Safety v1 for the agent, account-enforced, naming the guardian as a required intervener holding the suspend and resume rights (the earlier runs named no intervener), so that the account relies on the guardian's standing stops as well as on the record it is presented.

| # | Sender | Transaction | Effect |
|---|---|---|---|
| 0 | deployer | [`0x923a29af…`](https://sepolia.etherscan.io/tx/0x923a29afacbedae79fea1b688fd8ffe033e90fa0e19a75295e4d7526228ded46) | ASFEvaluation library deployed through the deterministic CREATE2 factory (0x4e59b44847b379578588920ca78fbf26c0b4956c); the receipt carries no contract address, the library lives at 0x7Dad89304047AC97814405921d140616f1708032 |
| 1 | deployer | [`0x27a40ff5…`](https://sepolia.etherscan.io/tx/0x27a40ff5b505d89411e1161a39e4014b161702487cea50ac3180aa2104e24e18) | ASFLifecycle library (revision 10) deployed through the deterministic CREATE2 factory (0x4e59b44847b379578588920ca78fbf26c0b4956c); the receipt carries no contract address, the library lives at 0x00706AD939f32e8e40833658485b410Def0662Eb |
| 2 | deployer | [`0x4f1ce95d…`](https://sepolia.etherscan.io/tx/0x4f1ce95d073473779a58d2ae99a7f5ffa4eef1f6ed7b2f975a9a32ef84f62c80) | ASFSpecificationRegistry deployed |
| 3 | deployer | [`0xccf61279…`](https://sepolia.etherscan.io/tx/0xccf61279b8a4d3c80e6b13e7afd7a0109da32917357148cdbe25c3b42f56d4be) | ASFBindingRegistry deployed, linked to ASFEvaluation and ASFLifecycle |
| 4 | deployer | [`0x73807cae…`](https://sepolia.etherscan.io/tx/0x73807caec2d4802ce72f011afe9951b674e0cfab934580ac1ad7913eb0480ebe) | LendingDesk (the target of the guarded account) deployed |
| 5 | deployer | [`0x72ba44b1…`](https://sepolia.etherscan.io/tx/0x72ba44b137b03e865a46f1e3e294fcfd874207724e28b3abc4d53e75c95f6afe) | ASFGuardedAccount deployed (owner: deployer; requirement: the deployer's adoption of Personal Assistant Safety v1 for the agent, account-enforced, naming the guardian as a required intervener holding the suspend and resume rights) |
| 6 | deployer | [`0xb6274c38…`](https://sepolia.etherscan.io/tx/0xb6274c386876afa1aab7e03f7babe2acb27ac2fb5007242f99a04f5efa09c5de) | OperatorProbe deployed (operator: agent; records every attempt with the revert data) |
| 7 | deployer | [`0xc2bf2e79…`](https://sepolia.etherscan.io/tx/0xc2bf2e79420e7edb2f7a094049d32c9cfae4e6f6cebedb4da1133f7c68d14fcd) | ASFGuardedAccount.setOperator(probe) |
| 8 | deployer | [`0x0fef0020…`](https://sepolia.etherscan.io/tx/0x0fef0020107db05609a2c98567408adfce35ed293c2a7f75e3e1a339400db643) | ASFGuardedAccount.setDeriskAllowed(desk, repay, true) |
| 9 | deployer | [`0x051c02ba…`](https://sepolia.etherscan.io/tx/0x051c02ba561e320cf675ddb6310eb739ec4d0e93ab11b44bd76ccc53eb5da9b8) | ASFGuardedAccount.setDeriskAllowed(desk, cancelOrder, true) |
| 10 | deployer | [`0x319ab982…`](https://sepolia.etherscan.io/tx/0x319ab982379b5495dc257f653203e0e0fb64224f3d8ee848448af9168295e315) | ASFTaskTenderAdapter deployed, bound to the live TaskToken; template: the fulfiller's own adoption of Personal Assistant Safety v1 with the deployer as intervener holding the suspend and resume rights |

## Phase 2: relink

The example documents under `deployments/sepolia-rev10/examples/` were relinked with the chain id, the registries and the three accounts (`tools/build-examples.js --dir deployments/sepolia-rev10/examples --chain-id 11155111`), validated against the schemas, and their hashes written to `manifest.json`; the tender documents of `script/tender/` were copied next to them. The specification, binding and result locators on chain point at the `main` branch under `deployments/sepolia-rev10/examples/`; the files there are the exact bytes whose hashes went on chain. The response documents used below: `guardian-derisk-only.response.json` (bits 9, `responseRef` `0x3c0458de0083bd43294d2e85cfdec074b4a969adbbf5af1867077ebb43123b8a`), `guardian-full-stop-widening.response.json` (bits 25, `responseRef` `0xbc1c89f5b1da8802aec221f9af0c9e09919a78ce45a74211dfb91f0f42dd5708`, naming the first in `supersedes`) and `principal-full-stop.response.json` (bits 16, `responseRef` `0x23ab504b25177f9ffd9c8e5c9824f0fc74994f4d1c74c4109754d5f5abf7049a`).

## Phase 3: publish and adopt (transactions 11–17, blocks 12140959 and 12140967)

| # | Sender | Transaction | Effect |
|---|---|---|---|
| 11 | deployer | [`0x2765dc49…`](https://sepolia.etherscan.io/tx/0x2765dc49f1c52283ff01545da7fed90b2fdd52064be29a58a8cd7334b50f1307) | registerSpecification: Personal Assistant Safety v1 (specIdPersonalAssistant) |
| 12 | deployer | [`0x08eadbcd…`](https://sepolia.etherscan.io/tx/0x08eadbcd11693349814ab4b42995c864d8319210f9e1b44fcfbb97a27d401611) | registerSpecification: Swarm Shared Funds v1 (specIdSwarmSharedFunds) |
| 13 | deployer | [`0x0c77cbfe…`](https://sepolia.etherscan.io/tx/0x0c77cbfe03a4bfdd1ba3e9fc6065e044c9500a2c40c3d7a3839da71c7bcc9459) | adopt: the principal's binding for the agent on the guarded account, guardian with suspend and resume rights (bindingPersonalAssistant) |
| 14 | deployer | [`0x8d3810ab…`](https://sepolia.etherscan.io/tx/0x8d3810ab851af099194fd2c6631df1eaaea1511f9d93bc1d02cc150a1d9c96d7) | ASFGuardedAccount.presentBindings([bindingPersonalAssistant]) |
| 15 | deployer | [`0x4842f8ee…`](https://sepolia.etherscan.io/tx/0x4842f8ee6b77a516c1c4f7b46a9330e403ed23dd15794448b299390e75470ba8) | adopt: the organizer's binding for the swarm, collective enforcement (bindingSwarmCharter) |
| 16 | agent | [`0x6ca00e43…`](https://sepolia.etherscan.io/tx/0x6ca00e43bdb8ef7371452d2f5d4b866e6e977c641da898f25490b7a823bda655) | adopt: member A's binding derived from the charter (bindingSwarmMemberA) |
| 17 | agent | [`0x6184a016…`](https://sepolia.etherscan.io/tx/0x6184a01688e25d4b8e735f54d57e72f860772300cba4b62e61e6e1919902ed02) | adopt: the worker's own binding naming the deployer (task publisher) with the suspend and resume rights (bindingWorkerSelf) |

## Phase 4: guard loop (transactions 18–23, blocks 12140967–12140971)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 18 | agent | [`0x1d500d86…`](https://sepolia.etherscan.io/tx/0x1d500d86a10d0a3ac9b5370fe6bb061203ac66ae3d9a64fc12f2cf8246b9e637) | borrow(100) through probe and account: executed |
| 19 | guardian | [`0x70661954…`](https://sepolia.etherscan.io/tx/0x70661954ac2ef6863fae39e3fdc7b07639597163ed8d07ee437f747453d81d21) | guardian suspends bindingPersonalAssistant with RESTRICT_NO_NEW_RISK \| RESTRICT_DERISK_ONLY (bits 9) and the responseRef of guardian-derisk-only.response.json: StopRecorded (adopter deployer, subject agent, intervener guardian, restrictions 9) then BindingStateChanged(Active -> Suspended) |
| 20 | agent | [`0x073d1501…`](https://sepolia.etherscan.io/tx/0x073d150101af37d9b05a56435c8c596c49bd5ee73736a0259e937fc14b63061e) | borrow(1): refused, Attempt records BindingNotSatisfied(NotSatisfied, [Suspended]) |
| 21 | agent | [`0x07caa6de…`](https://sepolia.etherscan.io/tx/0x07caa6de3634c62989d4b333f6f8b3a66a9f85f7877b47bba23d6461c5d99ebf) | repay(40): executed under de-risk only |
| 22 | guardian | [`0x5cc69e13…`](https://sepolia.etherscan.io/tx/0x5cc69e135bf7f24031d8f79814d132cc421bc8581a6d4504a53760085e65ecb9) | guardian resumes; the record carries the guardian's own suspension, so its resume lifts its stop: StopLifted then BindingStateChanged(Suspended -> Active) |
| 23 | agent | [`0x92c4373e…`](https://sepolia.etherscan.io/tx/0x92c4373e7b42ba3ae42723a07fb99d549260e009201dfb1ef254b7058a693351) | borrow(1): executed |

## Phase 5: tender loop (transactions 24–29, blocks 12140972–12140975)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 24 | deployer | [`0x925bb9a8…`](https://sepolia.etherscan.io/tx/0x925bb9a8b9309c063153a299b87b7c5f951ea81cff4f4ba2edcfcb361c7d1cd0) | mintTask on the live TaskToken (task #52, adapter as acceptance authority, reward 0.001 ETH, two completions, 7-day judgment window; digest and locator of tender/task.json) |
| 25 | deployer | [`0xce406159…`](https://sepolia.etherscan.io/tx/0xce40615955bd9b884865c3dde7439f45e0449207709f4f741293e9a950837148) | fundTask(#52, 0.002 ETH); the kernel escrows the value (TenderFunded, plus the two EIP-7708 transfer logs Sepolia emits for the ETH movement) |
| 26 | agent | [`0xdb2589ea…`](https://sepolia.etherscan.io/tx/0xdb2589ea65bdae11c1d7889798c6fd4a5fdc4f51043ec7d7206ed4edd90d261f) | agent submits tender/result-worker.json (submission 1) |
| 27 | guardian | [`0x729ccf94…`](https://sepolia.etherscan.io/tx/0x729ccf94e232adccd2c87a665d04c3bc63dd31b41f242481765e4f3159e1dec0) | guardian (no binding) submits tender/result-unbound.json (submission 2) |
| 28 | deployer | [`0x7ce85eea…`](https://sepolia.etherscan.io/tx/0x7ce85eeaf9299c665a750ad8717d0475bda62d24ee332077218e8b6c18fb2b76) | judge(#52, 1): Judged(Satisfied, [bindingWorkerSelf], [None]); the kernel pays 0.001 ETH to the agent (FulfillmentAccepted, plus the EIP-7708 transfer log) |
| 29 | deployer | [`0x9beb5786…`](https://sepolia.etherscan.io/tx/0x9beb5786186988da6aacad2da60ae2d7426a2b9db422060a52b582934626b866) | judge(#52, 2): Judged(NotSatisfied, [0], [NoBinding]); the kernel records the rejection (FulfillmentRejected) |

## Phase 6: stop loop (transactions 30–37, blocks 12140975–12140978)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 30 | deployer | [`0xd08c0fc3…`](https://sepolia.etherscan.io/tx/0xd08c0fc36bd531cef78821647e47715e5494bb67dbcb6734dfa531f9d36a0d6b) | the publisher suspends bindingWorkerSelf with RESTRICT_FULL_STOP (bits 16, zero responseRef, reasonRef keccak256("report: deliverable misrepresented")): StopRecorded (adopter agent, subject agent, intervener deployer, restrictions 16) then BindingStateChanged(Active -> Suspended) |
| 31 | agent | [`0x69b4556b…`](https://sepolia.etherscan.io/tx/0x69b4556b42ad57dcda72779564e5eb2f515aa9e9b094ce26fbb5d7227d15161b) | the worker terminates bindingWorkerSelf (reasonRef keccak256("replaced")): BindingStateChanged(Suspended -> Terminated); the record keeps suspendedBy, the stop stays |
| 32 | agent | [`0xb20c51de…`](https://sepolia.etherscan.io/tx/0xb20c51de6548fb6823b6e6dd9ad21add1515c31edb4ab55d796bd1643ab43b96) | the worker adopts a fresh binding under the next salt, same document and interveners (bindingWorkerSelfFresh) |
| 33 | agent | [`0x2f1a98e5…`](https://sepolia.etherscan.io/tx/0x2f1a98e59165a8d020aee78a02c0e65ea3e8705cea609e2d51b9e3bf10bd920b) | the worker submits tender/result-worker-after-stop.json (submission 3) |
| 34 | agent | [`0xdfd44272…`](https://sepolia.etherscan.io/tx/0xdfd44272b6cab21b0d5f64b3b2f6fc1aa894a79b323706f1885e25c7d270103a) | the worker calls judge(#52, 3) itself: Judged(NotSatisfied, [bindingWorkerSelfFresh], [StoppedByIntervener]); the kernel records the rejection |
| 35 | deployer | [`0x7b4702da…`](https://sepolia.etherscan.io/tx/0x7b4702da18160782a98bc4f113ff48b7011ba3871f245c5c30dd4b7928700deb) | the publisher lifts its stop with liftStop(agent, subjectKey(agent), specRegistry, specIdPersonalAssistant, deployer, keccak256("report withdrawn")): StopLifted; the terminated record is untouched |
| 36 | agent | [`0xaa5a8ae4…`](https://sepolia.etherscan.io/tx/0xaa5a8ae407aa6e64e0971ea78244ff62e1f41aed14605823cb6a281bd4b5f050) | the worker submits tender/result-worker-after-lift.json (submission 4) |
| 37 | agent | [`0xc7c2b47b…`](https://sepolia.etherscan.io/tx/0xc7c2b47b42a38e8cdeb87dc525c103682a1259195d5d372335f6342fa947de37) | the worker calls judge(#52, 4): Judged(Satisfied, [bindingWorkerSelfFresh], [None]); the kernel pays 0.001 ETH to the agent (second completion, plus the EIP-7708 transfer log) |

## Phase 7: lifecycle (transactions 38–42, blocks 12140979–12140981)

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 38 | deployer | [`0x4cb1a4e6…`](https://sepolia.etherscan.io/tx/0x4cb1a4e60f6e16c876cec16a610c9b4118daa589c93dfe83c01169e08219f128) | the principal suspends its own binding with RESTRICT_FULL_STOP (bits 16) and the responseRef of principal-full-stop.response.json; the adopter's own suspension records no stop |
| 39 | agent | [`0xa37b0ca2…`](https://sepolia.etherscan.io/tx/0xa37b0ca277e1f4003a746a66e29f3d53b6d7aefb6c24cad3bee6ddf2cc8a4070) | repay(1): refused, Attempt records BindingNotSatisfied(NotSatisfied, [Suspended]); full stop closes de-risking too |
| 40 | deployer | [`0xddecb024…`](https://sepolia.etherscan.io/tx/0xddecb0246e56e913d216e81303b6cca41451a562566f6aae6a6e234f6395bba0) | the principal resumes its own binding |
| 41 | deployer | [`0x9264cb74…`](https://sepolia.etherscan.io/tx/0x9264cb744803f09004744a7a000b9f512a0fe99c78b20c97b1226924b2549e26) | terminate(bindingSwarmCharter) |
| 42 | deployer | [`0x887933df…`](https://sepolia.etherscan.io/tx/0x887933dfa775bd765bc52a26955d2605d35a24b2e8b90690be3d99ef473e4a57) | deprecateVersion(Swarm Shared Funds, 1) |

## Phase 8: set loop (transactions 43–57, blocks 12140981–12140990)

The set loop exercises the response set in force of Section 10.1 (revision 8) on a live network: the set a consumer must apply is the record's own set together with the standing stops of the accounts its clause names, whatever reason the check reports first. Refusals below are recorded by the probe's `Attempt` event with the account's revert data, `BindingNotSatisfied(NotSatisfied, [Suspended])`.

| # | Sender | Transaction | Observed |
|---|---|---|---|
| 43 | deployer | [`0x7b43b55b…`](https://sepolia.etherscan.io/tx/0x7b43b55b117a44498954dffdd44b865612ec4bf0db05fc2b8f72d2e3d3edbcc6) | the principal adopts a sibling binding for the agent, same document and interveners, next salt (bindingPersonalAssistantSibling) |
| 44 | guardian | [`0xb0d79248…`](https://sepolia.etherscan.io/tx/0xb0d792486091dd71e50c190577a80feb98eb51d5fbd7a12405d47ae603829fd3) | guardian suspends the presented bindingPersonalAssistant with bits 9 and the responseRef of guardian-derisk-only.response.json: StopRecorded (restrictions 9) then BindingStateChanged(Active -> Suspended) |
| 45 | guardian | [`0x5d93880d…`](https://sepolia.etherscan.io/tx/0x5d93880d3f3f1286646546a11574889a2ecf18c49765b61e010465125f80642f) | guardian suspends the sibling with RESTRICT_NO_NEW_RISK \| RESTRICT_DERISK_ONLY \| RESTRICT_FULL_STOP (bits 25) and the responseRef of guardian-full-stop-widening.response.json (a document naming the one it supersedes): StopRecorded with the widened set 25, then BindingStateChanged(Active -> Suspended); the presented record still carries 9 |
| 46 | agent | [`0xfbd76977…`](https://sepolia.etherscan.io/tx/0xfbd7697778658294b7bde843aadde561302966d3d89e319021eafeb98efe48fa) | repay(1): refused, Attempt records BindingNotSatisfied(NotSatisfied, [Suspended]); the response set in force is the record's 9 together with the guardian's standing stop 25, so the full stop applies although the presented record shows de-risk only |
| 47 | deployer | [`0x49dcc1fd…`](https://sepolia.etherscan.io/tx/0x49dcc1fd3a80debfcb1703b8a57a803028ebc51bdf56df876bc1001b616d2f2f) | the principal terminates the sibling (reasonRef keccak256("replaced")): BindingStateChanged(Suspended -> Terminated); the guardian's stop stays |
| 48 | deployer | [`0xf206b6fd…`](https://sepolia.etherscan.io/tx/0xf206b6fd1249b52c4dea3e88521c7d93fb04e75e1b74dfef79035ee5a63deb2b) | the principal adopts a fresh binding for the agent, same document and interveners, next salt (bindingPersonalAssistantFresh) |
| 49 | deployer | [`0x59c2e565…`](https://sepolia.etherscan.io/tx/0x59c2e56512ebde89b3054798ee9d623b41c135888428e47b2c03ee5e8e9fd2dd) | the principal suspends the fresh binding itself with RESTRICT_DERISK_ONLY (bits 8, reasonRef keccak256("maintenance: unwinding")); the adopter's own suspension records no stop |
| 50 | deployer | [`0x2861ea39…`](https://sepolia.etherscan.io/tx/0x2861ea39098115b27d88cd1bce05f8440216eceb7d600579af753f31d02724e2) | ASFGuardedAccount.presentBindings([bindingPersonalAssistantFresh]) |
| 51 | agent | [`0x23dc8f0a…`](https://sepolia.etherscan.io/tx/0x23dc8f0a831f234813a9a90551b61c5b3ea698733c5e2f630e43bbb20eba9798) | repay(1): refused, Attempt records BindingNotSatisfied(NotSatisfied, [Suspended]); the guardian's full stop is in the set in force although the presented record shows the principal's de-risk only |
| 52 | guardian | [`0x0018dea0…`](https://sepolia.etherscan.io/tx/0x0018dea0ef91c39eca30c156410efb759ab22415d674892040ab97fe1fd48ae1) | the guardian lifts its stop with liftStop(deployer, subjectKey(agent), specRegistry, specIdPersonalAssistant, guardian, keccak256("incident closed")): StopLifted |
| 53 | agent | [`0x8aa40717…`](https://sepolia.etherscan.io/tx/0x8aa4071785f4775362a059a0ee0327811e26b13ceaef2103f879859d164c1a35) | repay(1): executed under the principal's own de-risk-only suspension |
| 54 | agent | [`0xbf9a2fa2…`](https://sepolia.etherscan.io/tx/0xbf9a2fa2f0324e3dc0ad7b2eced0207c0b3fafcfa360afe742cfce6bb9c90458) | borrow(1): refused, Attempt records BindingNotSatisfied(NotSatisfied, [Suspended]) |
| 55 | deployer | [`0x2e20a969…`](https://sepolia.etherscan.io/tx/0x2e20a9692f8bfa9c526f0243c28cd63a6d7d6bec982fd201d4c790b1c372c284) | the principal resumes the fresh binding (reasonRef keccak256("maintenance over")) |
| 56 | agent | [`0xed9949b2…`](https://sepolia.etherscan.io/tx/0xed9949b2cb85eaf7cdab1e71af5e4c8dc2565252a96fa9d5e6735262f68dc676) | borrow(1): executed |
| 57 | guardian | [`0xefa06f41…`](https://sepolia.etherscan.io/tx/0xefa06f413af79556dca8f3ca48fa55258288fbac6c7eabfe1e8a7bdb4b4332bf) | the guardian reopens bindingPersonalAssistant, which carries its suspension from step 2 (reasonRef keccak256("reviewed")): BindingStateChanged(Suspended -> Active); its stop was already lifted |

## State after the run

Read from Sepolia at block 12141005 with `eth_call` (39 reads); every value equals the mirror's except the timestamp words of the binding records, the specification versions and the submissions, which are Sepolia's block times.

- `bindingOf(bindingPersonalAssistant)`: `Active`, `restrictions` 0 (suspended by the guardian in transaction 44 and reopened by it in transaction 57).
- `bindingOf(bindingPersonalAssistantSibling)`: `Terminated`; the guardian's stop recorded through it was lifted in transaction 52.
- `bindingOf(bindingPersonalAssistantFresh)`: `Active`, the binding the account is presented (`presentedBindings()` = `[bindingPersonalAssistantFresh]`).
- `bindingOf(bindingSwarmCharter)`: `Terminated`; `bindingOf(bindingSwarmMemberA)`: `Active` with the charter as parent; `checkBinding(bindingSwarmMemberA, {specRegistry, Swarm Shared Funds})`: `NotSatisfied`, `ParentNotSatisfied`, response set 0.
- `bindingOf(bindingWorkerSelf)`: `Terminated`; `checkBinding(bindingWorkerSelf, {specRegistry, Personal Assistant Safety, interveners: [(deployer, suspend | resume)]})`: `NotSatisfied`, `Terminated`; the same clause on `bindingWorkerSelfFresh`: `Satisfied`.
- `stopOf` for the deployer's stop against the agent and for the guardian's stop against the deployer, both for the agent and Personal Assistant Safety: empty (lifted in transactions 35 and 52). `stopLifterOf(deployer)` and `stopLifterOf(guardian)`: zero.
- `ASFGuardedAccount.status()`: `Satisfied`, reasons `[None]`, response sets `[0]`.
- `ASFTaskTenderAdapter.evaluate(agent)`: `Satisfied` through `bindingWorkerSelfFresh`; `evaluate(guardian)`: `NotSatisfied`, `NoBinding`.
- `versionOf(Swarm Shared Funds, 1).deprecated` = true; `versionOf(Personal Assistant Safety, 1).deprecated` = false.
- `supportsInterface(0xcff7f826)` on the binding registry: true (`0x2db6eb8a` and `0x1ff33bef`, the revision-6 and revision-5 identifiers: false); `supportsInterface(0x9bddde77)` on the specification registry: true.
- `countBySubject(subjectKey(agent), agent)` = 3: the member binding, the terminated worker binding and the fresh one.
- `TaskToken.nextId` = 53; task #52 has four submissions, two completions (1 and 4 accepted, 2 and 3 rejected) and an escrow balance of 0 after both rewards.

Balances after the run: deployer 0.00697 ETH, agent 0.01469 ETH (two rewards of 0.001 ETH less gas), guardian 0.00569 ETH.

## Reproducing the checks

```
forge build
# runtime code on chain versus the local build (addresses in deployments/sepolia-rev10.json):
cast code 0x17D5A20094d5C97C53d921b101Fe8A9eE7c031D7 --rpc-url $SEPOLIA_RPC_URL
# the guardian's stop recorded in transactions 44 and 45 and lifted in transaction 52 (all zero now):
cast call 0x17D5A20094d5C97C53d921b101Fe8A9eE7c031D7 "stopOf(address,bytes32,address,bytes32,address)" \
  0xf12AFe29c9Ec5f66f669D7E388E0baE7Dc2f3eCe 0x10c46d6e66c66fda3fdb02443d1dfbc8f8fb8750e105fc89704db2fab36706da \
  0x9cC8A10207F6B3E54241657cD040580939dDef5A 0xc2675934f7593f209b8963d08bcabc03726258dd086c0306a9eed0ab88d43bf6 \
  0xc3e6965d427Abc91c1E33c78a986df2dBaDC660E --rpc-url $SEPOLIA_RPC_URL
# the binding the guarded account is presented and its current check:
cast call 0xb2E426d9b2A6f9A884ff9303288949267D76863D "status()" --rpc-url $SEPOLIA_RPC_URL
```

The hashes pinned on chain are the content hashes of the files under `deployments/sepolia-rev10/examples/`: Keccak-256 over the JCS-canonical form of each document (`tools/lib/canonical.js`), as `deployments/sepolia-rev10/examples/manifest.json` lists them next to the identifiers; the task and result documents under `tender/` are hashed with SHA-256 over the file bytes, as the kernel expects.

The deployer keeps publishing control of the two specifications and the adopter role of the principal's and organizer's bindings; the keys are session-generated and hold no other value.
