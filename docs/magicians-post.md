# Draft ERC: Agent Safety and Security Framework (ASF) — a registry of versioned safety specifications and of the scoped, attributable adoption relations that bind agents to them

Pull request: https://github.com/ethereum/ERCs/pull/2113 (placeholder number 9999 until an editor assigns one)
Repository: https://github.com/garyyang-finchip/agent-safety-framework (reference implementation, schemas, vectors, worked examples, two closed-loop consumers, design memo)

Current text: revision 2 (see the revision note below and the reply that introduces it).

## The gap

Agents now hold credentials, operate accounts and move funds for people and organizations, and the mechanisms that bound them are maturing in several places at once: permission grants and delegations in accounts, regulated mandates, action-bound policy verdicts, identity and reputation registries, decision mechanisms, task escrows. What none of them records is the relation between them: in this task, on these resources, in this execution environment, which participants have accepted which safety requirements, in which version, relying on which evidence, enforced by which mechanism, and whether that acceptance can still be relied upon now.

Without that relation a counterparty either trusts a label or asks for nothing; a requirement written into a document cannot be told apart from one enforced at an execution boundary; an accepted requirement is silently reinterpreted when its publisher releases a new version; and when an arrangement is paused or breached there is no shared way to say what stops, what continues, and who was entitled to intervene.

## What the draft standardizes

Two objects, one check, one composition rule. Everything else is consumed from the standards that already provide it; the text requires only ERC-165.

**Safety Specification.** A versioned, content-addressed document: protected interests (five domains — assets and economic position, information and privacy, control and rules, credit and eligibility, human and public interests — each naming whose interest is protected: principal, operator, counterparty, bystander, public), applicability with permitted and prohibited uses, constraints under named profiles (evaluated over an action, a state, a trajectory, a group or a relation between trajectories), who may adopt and enforce and on what external authority, expected evidence and what it binds, enforcement channels with their **location** (self, account, runtime, custodian, contract, collective), coverage and known bypasses, failure handling for unknown / denied / dependency failure, pre-accepted remedies (reversibility, intervention window, service continuity, incident reporting), and the profiles a consumer must understand. Versions are immutable; publishing v2 changes nothing for adopters of v1; deprecation is a signal.

**Safety Binding.** The on-chain statement that an adopter (always `msg.sender`) adopts one pinned specification version for one subject within one scope, under a named external authority basis, with declared enforcement locations, a validity window, named interveners with explicit rights (suspend / resume / terminate) and a lifecycle: Active, Suspended, Terminated. A suspension carries a **combinable set of response requirements** (no new risk, shrink, essential only, de-risk only, full stop; full stop dominates) and the hash of a structured **intervention response** document that states who started the response and under which right, what it covers, what it prohibits, allows and keeps running, how in-flight actions are handled, how long it lasts and who may end it. The adopter is part of every identifier and index key, so the registry can never attribute an arrangement to an account that did not accept it; whether the adopter was *entitled* to adopt for the subject is verified by consumers against the permission source the binding references, never by the registry. Bindings can be **derived** from a parent (same pinned version, validity inside the parent's, ancestors must hold, parameters never wider under the profile's declared order).

**The check.** `check(requirement, bindingIds)` evaluates a requirement set (clauses with explicit version lists, adopter, subject, scope and required enforcement locations, combined by all-of / any-of / k-of) and returns `Satisfied`, `NotSatisfied` or `Unknown` with a reason per clause. Pure registry logic — existence, state, validity, pin, adopter, subject, scope, enforcement, ancestors — no policy is evaluated, `Unknown` never counts as satisfied, and clause verdicts are never combined into a score. The verdicts and reasons are the registry's own; when a consumer also reads a permission, policy or validation mechanism, that mechanism's native result is kept as it is, never normalized into the registry's vocabulary. Which bindings a resource requires is decided by the resource's own authority rules; a subject cannot substitute a looser one.

## Closing the loop

Two reference consumers show that the relation bites at an execution boundary. `ASFGuardedAccount`: the operator may act only while the principal's binding is satisfied; a guardian's suspension with "no new risk" and "de-risk only" set blocks new exposure while repayment and cancellation still go through; once "full stop" is in the set, everything stops; there is no path that skips the check. `ASFTaskTenderAdapter`: an acceptance authority for token-bound task tenders that admits only fulfillers holding their own binding, rejects an unbound fulfiller and releases the reservation, and on `Unknown` neither accepts nor rejects — the kernel's own judgment clock stays in force. Both are tested against negative scenarios (74 tests, 48 negative), and the evidence script has been rehearsed end to end on Anvil; the Sepolia run follows.

## What it deliberately does not do

It does not decide whether an action is permitted, does not evaluate policies, does not certify that an agent is aligned, and does not prove that an arrangement is enforced: declared locations are attributable commitments, evidence and the mechanisms carry the verification. Incident reports, claims and labels have no effect of their own in the framework; only the rules of the consumer that reads them give them one, and the text fixes the consumer rules that keep such records from being used as weapons. It records who accepted what, where, in which version, enforced where, and whether that is in force now — and makes that answer available in one call at the moment of effect.

## Analysis basis

The design memo in the repository maps the problem space on three axes used as a multi-label index rather than as an exclusive classification: the seven links of an agent system (substrate, identity, authority, information flow, decision, accountability, collective), the five protected domains above, and six sources of failure. Eight requirement families group the profiles. The memo carries the object-and-authority attribution table, a scenario walkthrough against the test suite, and the overlap and adaptation review against the neighbouring proposals (permissions and delegations, policy verdicts, mandates, identity and reputation, validation, swarm charters, task tenders).

## Questions for the thread

1. Derived bindings: is the split between the on-chain structural rule and the off-chain profile-order rule acceptable, or should profiles with a declared order be checkable on chain?
2. Response requirements: are the five combinable bits plus the structured response document the right shape, or should the response document's `inFlight` rule (what happens to actions already authorized or sent) also be reflected on chain?
3. Protected domains: the fifth domain, human and public interests with the roles principal / operator / counterparty / bystander / public, replaced a narrower "third parties and the public" domain. Does anyone see an interest that falls outside the five?
4. Incident reports and claims stay outside the kernel and have effect only through consumer rules (and, if wanted, an optional profile). Is that the right boundary for a first version?

Feedback on the overlap review with the mandate, verdict, delegation and identity proposals is especially welcome.

## Revision note

- Revision 1 (initial filing): two objects, one check, five exclusive suspension restrictions, four protected domains plus "third parties and the public".
- Revision 2: suspension restrictions became a combinable bit set with a structured intervention response document (`responseRef`); the fifth protected domain became human and public interests with protected roles; specifications gained permitted and prohibited uses and the remedies reversibility, intervention window, service continuity and incident reporting; the text now states that native results of external mechanisms are preserved rather than normalized, that identity, representation and legitimate use are established separately, and the consumer rules for incident reports, claims and labels; the `IASFBindingRegistry` interface identifier changed accordingly (`0xb99bdc2a`); the design memo with the three-axis map, the attribution table, the scenario walkthrough and the overlap review was added to the repository.
