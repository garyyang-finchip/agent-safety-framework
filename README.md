# ERC-8468: Agent Safety Framework (ASF)

Reference repository of **ERC-8468, Agent Safety Framework (ASF)** (Draft): a registry model through which the safety arrangements that govern autonomous systems (agents, swarms, economic units, any referenceable system) become protocol objects with a source, a version, a scope, an attributable adoption relation and a lifecycle.

Status: Draft. ERC-8468 was assigned on 2026-10-27 in [ethereum/ERCs#2113](https://github.com/ethereum/ERCs/pull/2113) (filed on 2026-10-25 under the placeholder number 9999); discussion thread: [ERC-8468: Agent Safety Framework (ASF)](https://ethereum-magicians.org/t/erc-8468-agent-safety-framework-asf/30073) on Ethereum Magicians. This repository holds revision 7 of the draft (v0.8.2). Reference implementation, schemas, vectors, worked examples and two closed-loop consumers are complete and tested; the evidence run was executed on Sepolia twice, with the revision-5 contracts (36 transactions) and with the revision-7 contracts (43 transactions, including the standing-stop loop), all transactions successful and all contracts verified (see below).

## What it is

The framework standardizes two objects and one check, and consumes everything else from the standards that already provide it.

1. **Safety Specification.** A reusable, versioned, content-addressed document: which protected interests a set of requirements serves (`assets-economic`, `information-privacy`, `control-rules`, `credit-eligibility`, `human-public`, each with the roles whose interest is protected: principal, operator, counterparty, bystander, public), which constraints apply and under which profile, which uses are permitted and prohibited, who may adopt and enforce, which evidence is expected, through which channels and at which **enforcement locations** (`self`, `account`, `runtime`, `custodian`, `contract`, `collective`) the constraints are enforced, how unknown conditions and failures are handled, and which remedies are pre-accepted (reversibility, intervention window, service continuity, incident reporting). Versions are immutable; publishing version 2 changes nothing for adopters of version 1.
2. **Safety Binding.** The attributable, on-chain statement that an adopter (always `msg.sender`) adopts one pinned specification version for one subject within one scope, under a named external authority basis, with declared enforcement locations, a validity window, named **interveners** with explicit rights, and a lifecycle `Active -> Suspended -> Active | Terminated`. A suspension records who made it; a suspension recorded by an intervener can be lifted only by an intervener holding the resume right, never by the adopter (the adopter can always terminate, and a terminated record keeps showing the stop it carried). An intervener's suspension is also a **standing stop** against the adopter for the subject and the specification, and the stop is the intervener's: it outlives the termination of the binding it was recorded through, widens by union when the intervener suspends another binding of the adopter, is lifted only by that intervener or by the one lifter it named (by no right of the adopter, and not by the resume holders of a binding), and no binding of that adopter for that subject and specification satisfies a clause that names the intervener while it stands. A suspension carries a combinable set of **response requirements** (`RESTRICT_NO_NEW_RISK` 1, `RESTRICT_SHRINK` 2, `RESTRICT_ESSENTIAL_ONLY` 4, `RESTRICT_DERISK_ONLY` 8, `RESTRICT_FULL_STOP` 16; full stop dominates) and the hash of a structured **intervention response** document that states who started the response, what it covers, what it prohibits, allows and keeps running, how in-flight actions are handled and who may end it. Bindings can be **derived** from a parent binding and never widen it. A binding identifier is never recreated.
3. **The check.** `check(requirement, bindingIds)` evaluates a requirement set (clauses combined by all-of / any-of / k-of) against candidate bindings at the current block time and returns `Satisfied`, `NotSatisfied` or `Unknown` with a reason and the response set in force per clause. A clause can also require **interveners** with given rights, so that a resource insists that someone other than the subject can stop it; a clause that names interveners also closes the resume right to the accounts it names, since the adopter chooses the interveners and could otherwise lift any stop through an account of its own. Pure registry logic (existence, state, validity, pin, adopter, subject, scope, enforcement, required interveners, standing stops by the accounts the clause names, ancestors); no policy is evaluated, and `Unknown` never counts as satisfied. The response set in force is the union over the binding and its suspended ancestors (empty when the chain is terminated or expired), so a parent's de-risk-only response reaches derived bindings intact and a full stop anywhere in the chain is visible below it. The verdicts and reasons are the registry's own; the native results of permission, policy and validation mechanisms that consumers read alongside them are preserved, not normalized.

The registry never decides whether the adopter was entitled to adopt (consumers verify that against the permission source named by `authorityRef`), whether an action is permitted (policy and permission mechanisms do), or whether the arrangement is actually enforced (the declared locations are attributable commitments; evidence and the mechanisms carry the verification). Incident reports, claims and labels have no effect of their own; only the rules of the consumer that reads them give them one.

Two consumers close the loop at an execution boundary: `ASFGuardedAccount` (an operator may act only while the principal's binding is satisfied; de-risking calls stay open while the response set in force, of the presented binding or of its suspended ancestors, includes `RESTRICT_DERISK_ONLY` and not `RESTRICT_FULL_STOP`; there is no path that skips the check) and `ASFTaskTenderAdapter` (an acceptance authority for token-bound task tenders that admits only fulfillers holding the required bindings, with the task publisher as a required intervener, and leaves the tender's own clock in force on `Unknown`; tested against the real TASK-KERNEL v3.0 `TaskToken`).

## Analysis basis

The design memo (`docs/design-memo.md`) maps the problem space on three axes used as a multi-label index, never as an exclusive classification: seven **links** of an agent system (substrate, identity, authority, information flow, decision, accountability, collective), five **protected domains** (the `protects.domain` values above) and six **sources** of failure. Eight requirement families group the profiles. The memo also carries the object-and-authority attribution table (which object settles which question, and under whose authority), a walkthrough of fourteen scenarios against the registry behaviour and the test suite, and the overlap and adaptation review against the neighbouring proposals.

## Repository

```
ERCS/erc-asf.md                      ERC text (source; the filing package names it erc-8468.md)
assets/erc-asf/
  contracts/                         ASFSpecificationRegistry, ASFBindingRegistry, ASFTypes, ASFErrors,
                                     interfaces/ (incl. the vendored ITaskTenderKernel subset),
                                     libraries/ (ASFKeys, ASFRequirementLib; ASFEvaluation and ASFLifecycle: the
                                     registry's check and its writes as externally linked libraries),
                                     examples/ASFGuardedAccount, adapters/ASFTaskTenderAdapter
  schemas/                           JSON Schemas (safety specification, safety binding, requirement set,
                                     intervention response, profile descriptor, common)
  vectors/                           interface ids, identifiers, keys, canonicalization, spec id, binding id,
                                     requirement id, response requirement bits, example hashes
  examples/                          2 specifications, 4 bindings (one derived), 2 requirement sets,
                                     2 intervention responses, 6 profile descriptors, manifest.json
test/                                Foundry suite (93 tests, 67 of them negative conformance scenarios)
                                     incl. ethers <-> solc vector cross-checks and the vendored TaskToken fixture
tools/                               build-examples.js, vectors.js, validate.js, lint-erc.js, lib/canonical.js,
                                     test/ (node --test)
script/SepoliaEvidence.s.sol         evidence run (deploy, publish, adopt, guard loop, tender loop, stop loop, lifecycle)
scripts/make-filing-package.py       builds ercs-pr-package/ for the ethereum/ERCs pull request
deployments/                         Sepolia records of the two runs: addresses and identifiers, the transactions,
                                     the relinked examples (sepolia*, revision 5; sepolia-rev7*, revision 7)
docs/                                design memo, Magicians post and revision notes, test record, Sepolia runbook
                                     and the two evidence records
```

## Build and test

```
npm install
forge build
forge test
npm run check          # rebuild examples, regenerate vectors, validate schemas, run the tool tests
npm run lint:erc       # eipw lint of the ERC text (spelling findings are listed, not gating)
python3 scripts/make-filing-package.py                 # --number and --discussions-to override the defaults (8468, the thread URL)
```

`forge` needs solc 0.8.30 (downloaded automatically) and the vendored `lib/forge-std` (1.9.7). The project compiles via IR (`via_ir = true` in `foundry.toml`; the suite also passes without it): the binding registry delegates its check to the externally linked library `ASFEvaluation` and its writes (`adopt`, `suspend`, `resume`, `terminate`, `liftStop`, `setStopLifter`) to `ASFLifecycle`, which keeps the registry's deployed code within the per-transaction gas cap of networks that price code deposit heavily (see `docs/sepolia-evidence.md`); the interface, the identifiers and the behaviour are unchanged by the split.

## Identifiers

| Item | Value |
|---|---|
| `IASFSpecificationRegistry` interface id | `0x9bddde77` |
| `IASFBindingRegistry` interface id | `0xcff7f826` |
| Content hash | `keccak256(UTF-8(JCS(document)))` (RFC 8785) |
| `subjectKey` | `keccak256(UTF-8(reference))`, account reference `eip155:<chainId>:<lowercase address>` |
| `scopeKey` | `keccak256(UTF-8(JCS(scope object)))` |
| `specId` | `keccak256(abi.encode(chainId, specRegistry, publisher, salt))` |
| `bindingId` | `keccak256(abi.encode(chainId, bindingRegistry, adopter, subjectKey, scopeKey, specRegistry, specId, version, salt))` |
| `requirementId` | `keccak256(abi.encode(RequirementSet))`; a clause carries `(address,uint8)[]` required interveners |
| `responseRef` | content hash of the intervention response document |

## Relation to other proposals

The framework is designed to sit on top of existing and emerging agent standards without normative dependencies: identity and reputation registries, wallet permissions and delegations, action-bound policy verdicts, agent mandates, collective decision mechanisms, task tenders and skill packages, swarm charters, economic units and resource discovery are referenced by bindings and requirement sets as the subjects, scopes, authority bases and enforcement mechanisms of an adoption, never re-defined, and their own results are read as they are. The ERC text requires only ERC-165.

## Sepolia

The evidence run (`script/SepoliaEvidence.s.sol`) has been executed on Sepolia twice, both times against the live TASK-KERNEL v3.0 `TaskToken`. The record of each run is in `deployments/` and `docs/`; the procedure in `docs/sepolia-runbook.md`.

The second run, on 2026-10-27 (blocks 12003345 to 12003478), deployed the revision-7 contracts (interface identifier `0xcff7f826`): it deployed both registries with their two linked libraries, published the two example specifications, created the example bindings (including the derived member binding), exercised the guarded-account loop (execute, the guardian suspends with its de-risk-only response and the registry records the guardian's standing stop, the de-risk call passes, new exposure reverts, the guardian's resume lifts its stop), the tender loop against the live `TaskToken` (the bound worker accepted and paid, the unbound submitter rejected), the standing-stop loop of Section 8.5 (the task publisher stops the worker's binding; the worker terminates it and adopts a fresh one, submits and is rejected with `StoppedByIntervener`; the publisher lifts its stop through `liftStop`; the worker submits again and is accepted and paid) and the lifecycle phase (the principal's full-stop response refuses even repayment, charter termination, the derived binding reporting `ParentNotSatisfied`, deprecation). 43 transactions, all successful; `docs/sepolia-evidence-rev7.md`, `deployments/sepolia-rev7.json`, `deployments/sepolia-rev7.transactions.json`.

| Contract (revision 7) | Sepolia address |
|---|---|
| `ASFSpecificationRegistry` | `0x9110b622a17F83065f1e9773D961EB10672932e5` |
| `ASFBindingRegistry` | `0x136E2a88e1B518342CD997423BDa69Dd2c68e919` |
| `ASFEvaluation` (library linked by the binding registry) | `0x9b12f62D69EAfc9a240b9AB889cC1647Bf9C56db` |
| `ASFLifecycle` (library linked by the binding registry) | `0x6a6F645eC9F161735Cc22D441aFD1f513f3b143b` |
| `ASFGuardedAccount` | `0xc88A3FdbC5a4934D335b24416cC9fbF4046e88b0` |
| `OperatorProbe` | `0xA5cA2A45E0160c6fCAf00Fa846E9cD4C6241a18c` |
| `LendingDesk` | `0x655B256CC0f942fff44b977A50B00bE7391C7341` |
| `ASFTaskTenderAdapter` | `0x015393ECe2E3072055A3Fbe8Fc7f2979B7C7F3Ed` |
| `TaskToken` (live TASK-KERNEL v3.0, consumed) | `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` |

All eight deployed contracts are verified on Sourcify (runtime and creation match; solc 0.8.30, optimizer 200 runs, via IR). Specification identifiers: Personal Assistant Safety v1 `0x5ed86852…0e2a`, Swarm Shared Funds v1 `0x57dadd22…6888` (full values in `deployments/sepolia-rev7.json`).

The first run, on 2026-10-26 (blocks 11994931 to 11995051), deployed the revision-5 contracts (interface identifier `0x1ff33bef`, one linked library) and exercised the same phases without the stop loop: 36 transactions, all successful, seven contracts verified on Sourcify; `docs/sepolia-evidence.md`, `deployments/sepolia.json`, `deployments/sepolia.transactions.json`. Those contracts stay deployed as they were.

| Contract (revision 5) | Sepolia address |
|---|---|
| `ASFSpecificationRegistry` | `0x1939665F5905d0d9135Da4f27e36f1B8c84E014b` |
| `ASFBindingRegistry` | `0xc3e1A1Cb021Ab96EBBeD3279018840016114A5c4` |
| `ASFEvaluation` (library linked by the binding registry) | `0x663B84f1BfcE37bE4a78358b0301B5d5E5079269` |
| `ASFGuardedAccount` | `0x40AaD5106A7a13B15892E53099f6bD06bCF80aD3` |
| `OperatorProbe` | `0xD68B1bB09399Ca6acc802Bf2E2A4346ec810da77` |
| `LendingDesk` | `0x78A466eb7A5FB8E101b02bf3EAee9E6f9C701d9E` |
| `ASFTaskTenderAdapter` | `0x51772fabFB757Fb5A4186c0435Ec4fa76D75CE4e` |

## License

CC0-1.0 (see `LICENSE.md`).
