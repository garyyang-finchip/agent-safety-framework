# Agent Safety Framework — design memo (v0.2)

This memo records the analysis behind the ERC text, the design decisions of the reference implementation, the relation to neighbouring proposals, and the open points. The ERC text (`ERCS/erc-asf.md`) is normative; this memo explains it.

## 1. Where the framework comes from

The proposal grew out of a classification exercise: what do people mean by "security" when they discuss AI agents, on-chain theft, assistants that hold their users' accounts, and the behaviour of agents themselves. Two classifications were produced independently and then merged.

The first classification follows the chain of a delegated action and asks where a relation that should hold breaks: substrate (do the mechanisms run as specified), identity (is the actor who it claims to be, for whom), authority (does it stay within what was granted, also after composition and re-delegation), information flow (are inputs handled according to their trust level, and is disclosure within permission), decision (right goal, right action, no deception or evasion of oversight), accountability (can effects be attributed, interrupted and remedied, and are the interveners themselves bounded) and the collective (do constraints still hold once many subjects interact). These seven links are non-overlapping and give every incident a primary class.

The second classification asks what is protected and which relation must not be broken, and arrives at eight domains that are allowed to overlap: identity, authorization and control; information, privacy and input trust; technical execution, environment and supply chain; behaviour and goal alignment; assets, transactions and economics; collaboration, groups and systems; persons, society and public interest; governance, accountability and remedy. It adds six sources of risk (external attack, operator misuse, capability failure, goal and norm deviation, interaction and dependency failure, governance failure or abuse) and tags for lifecycle stage, impact scope and reversibility.

The merge keeps the seven links as the analytical primary axis, the protected domains as the second axis (the five domains that appear in the specification document: assets and economics, information and privacy, control and rules, credit and eligibility, third parties and the public), the six sources as the third axis, and the eight domains as the practical grouping of profiles. Nothing on chain depends on the families being disjoint, so the two views coexist: one for analysis, one for organizing vocabularies.

Three cross-cutting judgments shaped the kernel:

- Intent is not provable for a stochastic system. The framework never certifies alignment. It records commitments and evidence about behaviour and leaves the question of "good or bad" where it can be acted upon: bounded authority, attributable identity and credit, records and interventions, and collective checks.
- A security document is not a control. The framework therefore records where an arrangement is enforced, and lets requirements demand enforcement at a chosen independence from the subject.
- The on-chain layer is the one place where order can be enforced rather than advised: a cap, a second factor, an escrow delay, a pause with a defined restriction can be invariants in accounts and contracts, where in other environments they remain best practice.

## 2. Why the adoption relation is the object

An overlap review of agent-related proposals found the mechanisms well covered: wallet permission requests and smart-contract delegations; regulated agent mandates with caps, expiry and freeze; action-bound confidential policy verdicts with an execution guard and a policy-domain registry; attestation-gated actions; sandboxed agent wallets; identity, reputation and validation registries for agents; collective decision registries; task tenders with escrow and judgment windows; skill packages committed by hash; swarm charters; economic unit registries; resource discovery registries; protocol control disclosure. None of these records the relation between them: in this scope, which participants accepted which arrangement, in which version, enforced where, and whether the acceptance is in force now.

Making that relation a registry object is a smaller addition than any new control and the one that lets the existing controls be composed and relied upon by third parties. Three alternatives were rejected: a registry of safety documents alone (it records opinions, not acceptance), a policy registry (several exist, and a registry that evaluated policies would acquire a privileged position), and one more allow/deny interface (the registry-level check is deliberately limited to facts about the relation).

## 3. The kernel

Two objects, one check, one composition rule.

**Safety Specification.** A versioned, content-addressed document. The members were chosen so that a reader can answer, without reading anything else: what is protected, where the specification applies, which constraints hold under which profile and over what (action, state, trajectory, group, relation), who may adopt and enforce and on what external authority, what evidence is expected and what it binds, through which channels at which locations with which coverage and known bypasses the constraints are enforced, what happens on unknown, denied and dependency failure, which remedies are pre-accepted, and which profiles a consumer must understand. Versions are immutable; deprecation is a signal. The registry keeps the hash, the locator, the publication time, the deprecation flag and the required profiles.

**Safety Binding.** The adoption relation. Three rules make the registry trustworthy in the only sense a registry can be: the adopter is the sending account; the adopter is part of every identifier and every index key; the entitlement to adopt is verified by consumers against their own permission source, not by the registry. The record pins a specification version by content hash, names the subject and scope by opaque keys, carries the parameters hash, an authority reference, the enforcement bit set, a validity window, optional interveners with explicit rights, and an optional parent.

**Lifecycle.** Active, Suspended under one of five restrictions (no new risk, shrink, essential only, de-risk only, full stop), Terminated. The restrictions exist so that a suspension can say what continues; the reference guarded account shows the pattern by keeping listed de-risking calls open under de-risk only and nothing under full stop. Transitions record the actor and a reason reference; a binding identifier is never recreated; termination keeps the record.

**Derived bindings.** The decidable part of attenuation is enforced on chain: same pinned version, validity inside the parent's, bounded depth, and ancestors must hold at evaluation. The profile-dependent part is stated as a rule (not wider under the profile's declared partial order, equal where none is declared, never satisfied by default) and verified by consumers from the two parameters documents. The undecidable part is declared undecidable.

**The check.** Pure registry logic with a defined evaluation order and a reason per clause; a verdict of Unknown where the registry itself cannot decide (the pinned specification registry no longer answers); combinators all-of, any-of and k-of that never count Unknown as satisfied and never produce a score.

## 4. The five additions of this revision

Relative to the first draft of the adoption-relation design, this revision adds the pieces that make the framework effective rather than complete:

1. A registry-level `check` and two reference consumers that close the loop at an execution boundary, with negative tests: a guarded account whose operator is stopped by a suspension, and a task-tender acceptance authority that rejects an unbound fulfiller and leaves the kernel's own clock in force on Unknown.
2. Derived bindings with an on-chain structural rule and an off-chain parameter rule.
3. A five-value restriction vocabulary for suspensions, interveners with explicit rights fixed at creation, and a reason reference on every transition.
4. A deliberate placement of incident and claim records outside the kernel in this version: they belong to behaviour facets of agent identities and to collective decision records, linked by binding identifier through the reason references. The kernel reserves the hook, not the object.
5. A requirement grammar (clauses with explicit version lists, adopter, subject, scope and enforcement, combined by all-of, any-of, k-of), its identifier, and a document form with role-relative values that consumers resolve.

## 5. Relation to the agent standards family and to neighbouring proposals

The framework consumes and never re-defines:

| Provides | Role in a binding or requirement |
|---|---|
| agent identity and reputation registries (on-chain agent identities; address-anchored identities with behaviour facets) | subject references; evidence; the natural home of incident records |
| know-your-agent assertion registries | evidence that a requirement can ask for; never a source of authority |
| wallet permissions, delegations, regulated mandates, policy verdicts with execution guards | enforcement mechanisms at the account and contract locations; authority bases |
| collective decision registries | the collective enforcement location; interveners' decisions; dispute resolution named in remedies |
| task tenders and skill packages | scopes and subjects; the tender adapter is one consumer |
| swarm charters | authority bases of organizer bindings; parents of member bindings |
| economic unit registries | subjects and scopes; a future valuation profile may price posture |
| resource discovery registries | discovery of specification registries and services, without upgrading discoverability into assurance |
| protocol control disclosure | enforcement channel references for protocol-level controls |

The ERC text names only merged proposals and describes the rest by concept, so that it depends normatively on nothing but interface detection.

## 6. Conventions

Content hashes are Keccak-256 over JCS-canonical UTF-8, the convention of the economic unit and resource discovery work of the same family, so that one tool chain serves all three. Subject references for accounts follow the CAIP-10 account form in lowercase; scope objects are canonicalized with JCS; the one-member `{"ref": ...}` form is derivable on chain. Identifiers bind chain and registry. Profile identifiers follow `asf:profile:<family-short-name>/<name>@<version>`.

## 7. Verification

The Foundry suite has 73 tests, 47 of them negative conformance scenarios (N01–N47) covering specification identity and immutability, binding creation rules, the state machine, intervener rights, derived bindings, clause semantics and evaluation order, combinators, Unknown propagation, the guarded-account loop and the tender loop against the vendored TASK-KERNEL v3.0 `TaskToken`. Vectors are generated with ethers and re-checked in Solidity (interface identifiers, keys, canonicalization, specification and binding identifiers, requirement identifier). The evidence script was rehearsed end to end on Anvil (36 transactions across five phases).

## 8. Open points for the next round

- Shared-budget coordinator: the reserve-commit-release companion that makes the `economic/shared-budget` profile enforceable at the contract location is specified but not yet implemented; it is the next closed loop.
- Composition of requirement sets: v1 combines clauses, not sets; a nested grammar (all-of over k-of) is a candidate once a consumer needs it.
- Off-chain signed adoption (typed-data signatures relayed by a third party) is excluded from v1 to keep the dependency set at interface detection only; a profile can add it.
- Cross-chain specification registries: v1 pins same-chain registries; a cross-chain pin needs a stated consistency model.
- Incident and claim records: kept outside the kernel in v1; the reason references on transitions are the hook.
