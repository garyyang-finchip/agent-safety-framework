# Draft ERC: Agent Safety Framework (ASF) — a registry of versioned safety specifications and of the scoped, attributable adoption relations that bind agents to them

Repository: https://github.com/garyyang-finchip/agent-safety-framework (reference implementation, schemas, vectors, worked examples, two closed-loop consumers; PR to be added after filing)

## The gap

Agents now hold credentials, operate accounts and move funds for people and organizations, and the mechanisms that bound them are maturing in several places at once: permission grants and delegations in accounts, regulated mandates, action-bound policy verdicts, identity and reputation registries, decision mechanisms, task escrows. What none of them records is the relation between them: in this task, on these resources, in this execution environment, which participants have accepted which safety requirements, in which version, relying on which evidence, enforced by which mechanism, and whether that acceptance can still be relied upon now.

Without that relation a counterparty either trusts a label or asks for nothing; a requirement written into a document cannot be told apart from one enforced at an execution boundary; an accepted requirement is silently reinterpreted when its publisher releases a new version; and when an arrangement is paused or breached there is no shared way to say what stops, what continues, and who was entitled to intervene.

## What the draft standardizes

Two objects, one check, one composition rule. Everything else is consumed from the standards that already provide it; the text requires only ERC-165.

**Safety Specification.** A versioned, content-addressed document: protected interests, applicability, constraints under named profiles (evaluated over an action, a state, a trajectory, a group or a relation between trajectories), who may adopt and enforce and on what external authority, expected evidence and what it binds, enforcement channels with their **location** (self, account, runtime, custodian, contract, collective), coverage and known bypasses, failure handling for unknown / denied / dependency failure, pre-accepted remedies, and the profiles a consumer must understand. Versions are immutable; publishing v2 changes nothing for adopters of v1; deprecation is a signal.

**Safety Binding.** The on-chain statement that an adopter (always `msg.sender`) adopts one pinned specification version for one subject within one scope, under a named external authority basis, with declared enforcement locations, a validity window, named interveners with explicit rights (suspend / resume / terminate) and a lifecycle: Active, Suspended under one of five restrictions (no new risk, shrink, essential only, de-risk only, full stop), Terminated. The adopter is part of every identifier and index key, so the registry can never attribute an arrangement to an account that did not accept it; whether the adopter was *entitled* to adopt for the subject is verified by consumers against the permission source the binding references, never by the registry. Bindings can be **derived** from a parent (same pinned version, validity inside the parent's, ancestors must hold, parameters never wider under the profile's declared order) — the attenuated re-delegation that surveys of agent-mandate proposals and of workload-identity standards both flag as missing.

**The check.** `check(requirement, bindingIds)` evaluates a requirement set (clauses with explicit version lists, adopter, subject, scope and required enforcement locations, combined by all-of / any-of / k-of) and returns `Satisfied`, `NotSatisfied` or `Unknown` with a reason per clause. Pure registry logic — existence, state, validity, pin, adopter, subject, scope, enforcement, ancestors — no policy is evaluated, `Unknown` never counts as satisfied, and clause verdicts are never combined into a score. Which bindings a resource requires is decided by the resource's own authority rules; a subject cannot substitute a looser one.

## Closing the loop

Two reference consumers show that the relation bites at an execution boundary. `ASFGuardedAccount`: the operator may act only while the principal's binding is satisfied; a guardian's suspension under `DeriskOnly` blocks new exposure while repayment and cancellation still go through; `FullStop` blocks everything; there is no path that skips the check. `ASFTaskTenderAdapter`: an acceptance authority for token-bound task tenders that admits only fulfillers holding their own binding, rejects an unbound fulfiller and releases the reservation, and on `Unknown` neither accepts nor rejects — the kernel's own judgment clock stays in force. Both are tested against negative scenarios (73 tests, 47 negative), and the evidence script has been rehearsed end to end on Anvil; the Sepolia run follows.

## What it deliberately does not do

It does not decide whether an action is permitted, does not evaluate policies, does not certify that an agent is aligned, and does not prove that an arrangement is enforced: declared locations are attributable commitments, evidence and the mechanisms carry the verification. It records who accepted what, where, in which version, enforced where, and whether that is in force now — and makes that answer available in one call at the moment of effect.

## Questions for the thread

1. Is the registry-level check the right boundary, or should the kernel also normalize denial reasons of external policy mechanisms?
2. Derived bindings: is the split between the on-chain structural rule and the off-chain profile-order rule acceptable, or should profiles with a declared order be checkable on chain?
3. Is a five-value restriction vocabulary the right granularity for suspensions?
4. Should incident and claim records enter the kernel in a later revision, or stay with identity facets and decision records, linked by binding identifier?

Feedback on the overlap review with the mandate, verdict and delegation proposals is especially welcome.
