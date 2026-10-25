# Test record

`forge test`: 73 tests, 0 failures (solc 0.8.30, optimizer 200 runs, no via-IR). 47 of them are negative conformance scenarios, numbered N01–N47 in the test names. Tool tests (`npm run test:tools`): 4 tests. Example pipeline (`npm run check`): 14 documents validated against 4 schemas, manifest re-checked, vectors regenerated.

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
- `test_N14_suspend_requires_a_named_restriction`
- `test_N15_strangers_cannot_transition`
- `test_N16_intervener_rights_are_exactly_the_granted_ones`
- `test_N17_invalid_transitions_revert`
- `test_N18_unknown_binding_reverts`
- `test_N19_parent_must_be_active`
- `test_N20_parent_must_pin_the_same_specification_version`
- `test_N21_child_window_cannot_exceed_the_parent`
- `test_N22_depth_is_bounded`
- `test_adopter_is_msg_sender_and_record_is_complete`
- `test_backdated_validFrom_is_recorded_but_adoption_starts_at_creation`
- `test_derived_binding_pins_the_same_version_and_inherits_depth`
- `test_index_pagination`
- `test_params_locator_update_keeps_hash`
- `test_state_machine_happy_path_with_events`
- `test_supports_interface`

## Group 3 — registry-level check, combinators, Unknown (`test/ASFCheck.t.sol`)

- `test_N23_no_binding_supplied_or_unknown_id`
- `test_N24_state_reasons_and_restriction_surface`
- `test_N25_time_window_is_half_open`
- `test_N26_clause_mismatches_in_evaluation_order`
- `test_N27_a_new_specification_version_never_upgrades_a_binding`
- `test_N28_ancestor_failure_propagates_to_derived_bindings`
- `test_N29_unknown_when_the_specification_registry_is_unavailable`
- `test_N30_requirement_validation`
- `test_N31_combinators`
- `test_N32_unknown_counts_toward_neither_side_in_KOf`
- `test_satisfied_clause_reports_no_reason`
- `test_subject_and_scope_keys_match_the_reference_derivation`

## Group 4 — closed loop on the wallet path (ASFGuardedAccount) (`test/ASFGuardedAccount.t.sol`)

- `test_N33_suspension_blocks_new_exposure_and_derisk_only_keeps_unwinding_open`
- `test_N34_full_stop_blocks_even_derisking`
- `test_N35_resume_reopens_and_terminate_closes_for_good`
- `test_N36_expiry_closes_the_path_without_any_transaction`
- `test_N37_a_third_partys_binding_does_not_satisfy_the_principals_requirement`
- `test_N38_weaker_enforcement_declaration_is_refused`
- `test_N39_only_the_operator_executes_and_only_the_owner_configures`
- `test_N40_malformed_requirement_cannot_be_deployed`
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
- `test_fulfiller_with_binding_is_accepted_and_paid_through_the_real_kernel`
- `test_requirement_for_a_fulfiller_fills_adopter_and_subject`
- `test_the_first_satisfying_binding_is_selected_among_several`
- `test_two_workers_are_judged_independently`

## Group 6 — ethers <-> solc vector cross-checks (`test/ASFVectors.t.sol`)

- `test_canonicalization_vector`
- `test_identifier_hashes`
- `test_interface_ids_match_the_vectors`
- `test_keys_match_the_on_chain_derivation`
- `test_requirement_id_matches_the_registry`
- `test_spec_and_binding_ids_follow_the_abi_encoding`

## Anvil rehearsal of the evidence script

`script/SepoliaEvidence.s.sol` was run end to end on a local Anvil chain with three keys: deployCore (12 transactions), publishAndAdopt (7), guardLoop (6), tenderLoop (6), lifecycle (5) — 36 transactions. Observed: borrow ok, suspend `DeriskOnly`, borrow refused (probe event with revert data), repay ok, resume, borrow ok; tender accepted and the bound worker paid 0.001 ETH through the real `acceptFulfillment`, the unbound submission rejected; `FullStop` refused repay; charter terminated and the derived member binding reported `ParentNotSatisfied` while its own record stayed `Active`; swarm specification v1 deprecated with the binding unaffected.
