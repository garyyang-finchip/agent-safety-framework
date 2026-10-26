# Test record

`forge test`: 84 tests, 0 failures (solc 0.8.30, optimizer 200 runs, via IR; the suite also passes with `via_ir = false`). The binding registry's check runs in the externally linked library `ASFEvaluation`, so the suite exercises the registry through the library exactly as it is deployed. 58 of them are negative conformance scenarios, numbered N01–N58 in the test names (N49–N56 were added in revision 3 for the findings of the first public review: response sets over derivation chains, required interveners, and the rule that an intervener's suspension is not the adopter's to lift; N57–N58 in revision 4 for the closed resume right, after the second review). Tool tests (`npm run test:tools`): 4 tests. Example pipeline (`npm run check`): 16 example documents validated against 5 schemas, manifest re-checked, vectors regenerated (interface ids, identifiers, keys, canonicalization, specification id, binding id, requirement id, response requirement bits, example hashes).

## Group 1 — Safety Specification registry (`test/ASFSpecificationRegistry.t.sol`)

- `test_N01_zero_content_hash_reverts`
- `test_N02_same_salt_twice_reverts`
- `test_N03_publishVersion_by_non_publisher_reverts`
- `test_N04_setLocator_unknown_version_reverts`
- `test_N05_deprecate_by_non_publisher_reverts_and_deprecation_is_informative`
- `test_N06_frozen_specification_rejects_every_write`
- `test_N07_unknown_specification_reverts_on_reads`
- `test_locator_changes_hash_does_not`
- `test_publisher_transfer`
- `test_registration_is_attributable_and_deterministic`
- `test_supports_interface`
- `test_versions_are_immutable_and_sequential`

## Group 2 — Safety Binding creation and lifecycle (`test/ASFBindingLifecycle.t.sol`)

- `test_N08_spec_registry_without_interface_reverts`
- `test_N09_unknown_version_reverts`
- `test_N10_content_hash_mismatch_reverts`
- `test_N11_no_re_creation_even_after_termination`
- `test_N12_malformed_validity_reverts`
- `test_N13_intervener_rules`
- `test_N14_suspend_requires_a_non_empty_in_range_response_set`
- `test_N15_strangers_cannot_transition`
- `test_N16_intervener_rights_are_exactly_the_granted_ones` (a suspend-only guardian can neither resume nor terminate; the adopter cannot lift the guardian's suspension and can only terminate; `suspendedBy` recorded and cleared)
- `test_N17_invalid_transitions_revert`
- `test_N18_unknown_binding_reverts`
- `test_N19_parent_must_be_active`
- `test_N20_parent_must_pin_the_same_specification_version`
- `test_N21_child_window_cannot_exceed_the_parent`
- `test_N22_depth_is_bounded`
- `test_N49_an_interveners_suspension_is_lifted_only_by_an_intervener_holding_the_right` (guardian suspends: adopter cannot resume, executor with the right can; the adopter's own suspension is lifted by the adopter or by an intervener with the right; the executor's suspension cannot be lifted by the adopter or a suspend-only guardian)
- `test_adopter_is_msg_sender_and_record_is_complete`
- `test_backdated_validFrom_is_recorded_but_adoption_starts_at_creation`
- `test_derived_binding_pins_the_same_version_and_inherits_depth`
- `test_index_pagination`
- `test_params_locator_update_keeps_hash`
- `test_state_machine_happy_path_with_events` (suspension with a response set and a response reference, both cleared on resume; the record survives termination)
- `test_supports_interface`

## Group 3 — registry-level check, combinators, Unknown (`test/ASFCheck.t.sol`)

- `test_N23_no_binding_supplied_or_unknown_id`
- `test_N24_state_reasons_and_restriction_surface` (the response set is returned with `Suspended`)
- `test_N25_time_window_is_half_open`
- `test_N26_clause_mismatches_in_evaluation_order` (`IntervenerMismatch` is evaluated after `EnforcementMismatch` and before the ancestor walk)
- `test_N27_a_new_specification_version_never_upgrades_a_binding`
- `test_N28_ancestor_failure_propagates_to_derived_bindings` (the ancestor's response set is reported with `ParentNotSatisfied`)
- `test_N29_unknown_when_the_specification_registry_is_unavailable`
- `test_N30_requirement_validation`
- `test_N31_combinators`
- `test_N32_unknown_counts_toward_neither_side_in_KOf`
- `test_N50_response_sets_in_force_are_the_union_of_the_chain_and_empty_when_the_chain_is_broken` (root set reaches a grandchild; child and root sets unite; a full stop anywhere is in the union; a terminated or expired record empties it)
- `test_N51_required_interveners_must_be_named_with_at_least_the_required_rights` (named account, rights subset, the adopter never counts, a zero account is a malformed requirement, several required interveners, malformed rights revert)
- `test_N57_a_clause_that_names_interveners_closes_the_resume_right` (an unnamed holder of the resume right fails the clause; unnamed suspend-only or terminate-only interveners are allowed; a named account may hold more; the escalation shape with a named suspender and a named executor; no constraint without required interveners)
- `test_satisfied_clause_reports_no_reason`
- `test_subject_and_scope_keys_match_the_reference_derivation`

## Group 4 — closed loop on the wallet path (ASFGuardedAccount) (`test/ASFGuardedAccount.t.sol`)

- `test_N33_suspension_blocks_new_exposure_and_derisk_only_keeps_unwinding_open`
- `test_N34_full_stop_blocks_even_derisking`
- `test_N35_resume_reopens_and_terminate_closes_for_good` (the principal cannot lift the guardian's suspension; the guardian, holding the resume right, does)
- `test_N36_expiry_closes_the_path_without_any_transaction`
- `test_N37_a_third_partys_binding_does_not_satisfy_the_principals_requirement`
- `test_N38_weaker_enforcement_declaration_is_refused`
- `test_N39_only_the_operator_executes_and_only_the_owner_configures`
- `test_N40_malformed_requirement_cannot_be_deployed`
- `test_N48_combined_response_requirements_keep_derisking_open_unless_full_stop_is_set` (`RESTRICT_NO_NEW_RISK | RESTRICT_DERISK_ONLY`: borrow refused, repay passes; `RESTRICT_DERISK_ONLY | RESTRICT_FULL_STOP`: repay refused as well)
- `test_N52_a_parents_derisk_only_suspension_keeps_the_derived_bindings_unwinding_open` (the account requires the agent's binding derived from the principal's root; a de-risk-only suspension of the root blocks borrow and keeps repay and cancel open although the derived record carries no set; the guardian's resume reopens)
- `test_N53_a_parents_full_stop_or_termination_closes_the_derived_bindings_derisking_path` (full stop on the root closes repay; termination reports `ParentNotSatisfied` with an empty set and closes everything)
- `test_N54_sets_of_the_child_and_of_the_parent_combine_and_full_stop_dominates`
- `test_operator_acts_while_the_binding_is_satisfied`
- `test_requirement_is_fixed_at_deployment`

## Group 5 — closed loop on the task path (ASFTaskTenderAdapter, vendored TASK-KERNEL v3.0) (`test/ASFAdapter8414.t.sol`)

- `test_N41_fulfiller_without_binding_is_rejected_and_the_reservation_released`
- `test_N42_a_binding_adopted_by_someone_else_for_the_worker_does_not_count`
- `test_N43_binding_suspended_between_submission_and_judgment_leads_to_rejection`
- `test_N44_self_declared_enforcement_is_not_enough_for_this_tender`
- `test_N45_unknown_verdict_does_nothing_and_the_task_clock_governs`
- `test_N46_adapter_requires_the_authority_and_a_pending_judged_submission`
- `test_N47_template_may_not_pre_bind_adopter_or_subject`
- `test_N55_a_fulfiller_whose_binding_does_not_name_the_required_intervener_is_rejected` (clause requires the task publisher with the suspend right: a binding under the fulfiller's sole control is rejected with `IntervenerMismatch`, one naming the publisher is accepted)
- `test_N56_the_publishers_suspension_is_not_the_fulfillers_to_lift_before_judgment` (the fulfiller's resume reverts; judgment rejects; a fresh binding naming the publisher is admitted and can be suspended again)
- `test_N58_a_fulfiller_cannot_keep_a_resume_key_of_its_own_beside_the_required_intervener` (the puppet-key binding is rejected with `IntervenerMismatch` before any suspension; with a clause naming publisher and executor, the executor lifts the publisher's stop, the fulfiller cannot, and the fulfiller is then accepted)
- `test_fulfiller_with_binding_is_accepted_and_paid_through_the_real_kernel`
- `test_requirement_for_a_fulfiller_fills_adopter_and_subject`
- `test_the_first_satisfying_binding_is_selected_among_several`
- `test_two_workers_are_judged_independently`

## Group 6 — ethers <-> solc vector cross-checks (`test/ASFVectors.t.sol`)

- `test_canonicalization_vector`
- `test_identifier_hashes`
- `test_interface_ids_match_the_vectors` (`IASFSpecificationRegistry` `0x9bddde77`, `IASFBindingRegistry` `0x1ff33bef`)
- `test_keys_match_the_on_chain_derivation`
- `test_requirement_id_matches_the_registry` (three clauses, the third with two required interveners: a suspender and a resume holder)
- `test_spec_and_binding_ids_follow_the_abi_encoding`

## Anvil rehearsal of the evidence script

`script/SepoliaEvidence.s.sol` was run end to end on a local Anvil chain with three keys: deployCore (12 transactions, the first of them the `ASFEvaluation` library through the CREATE2 factory), publishAndAdopt (7), guardLoop (6), tenderLoop (6), lifecycle (5) — 36 transactions, with the response sets, response references and interveners read from the relinked `manifest.json`. Observed: borrow ok; the guardian suspends with `RESTRICT_NO_NEW_RISK | RESTRICT_DERISK_ONLY` (bits 9) and the `responseRef` of `guardian-derisk-only.response.json`; borrow refused (probe event with revert data); repay ok; the guardian resumes; borrow ok; the tender's template requires the deployer as an intervener with the suspend right and the worker's binding names it; tender accepted and the bound worker paid 0.001 ETH through the real `acceptFulfillment`, the unbound submission rejected; the principal's `RESTRICT_FULL_STOP` suspension (bits 16, `principal-full-stop.response.json`) refused repay; charter terminated and the derived member binding reported `ParentNotSatisfied` while its own record stayed `Active`; swarm specification v1 deprecated with the binding unaffected.

## Sepolia run

The same 36 transactions were executed on Sepolia on 2026-10-26 (blocks 11994931 to 11995051), all with status 1, against the live TASK-KERNEL v3.0 `TaskToken` at `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` (task #20). Every observation of the rehearsal was reproduced on chain and read back after the run: the guard loop's refusals carry `BindingNotSatisfied(NotSatisfied, [Suspended])` in the probe's `Attempt` events, the adapter's `Judged` events show `Satisfied` with the worker's binding for submission 1 and `NotSatisfied` / `NoBinding` for submission 2, the derived member binding checks `ParentNotSatisfied` with an empty response set after the charter's termination while its record stays `Active`, and version 1 of the swarm specification is deprecated. The seven contracts are verified on Sourcify from the standard JSON input. Record: `docs/sepolia-evidence.md`, `deployments/sepolia.json`, `deployments/sepolia.transactions.json`.
