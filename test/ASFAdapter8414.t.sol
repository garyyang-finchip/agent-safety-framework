// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ASFBase} from "./ASFBase.t.sol";
import {ASFTypes as T} from "asf/ASFTypes.sol";
import {ASFErrors} from "asf/ASFErrors.sol";
import {ASFKeys} from "asf/libraries/ASFKeys.sol";
import {ASFTaskTenderAdapter} from "asf/adapters/ASFTaskTenderAdapter.sol";
import {ITaskTenderKernel} from "asf/interfaces/ITaskTenderKernel.sol";
import {TaskToken} from "./fixtures/task-token/TaskToken.sol";
import {ITaskTender} from "./fixtures/task-token/interfaces/ITaskTender.sol";
import {ToggleSpecRegistry} from "./mocks/ToggleSpecRegistry.sol";

/// Test group 5 — closed loop on the task path, against the real TASK-KERNEL v3.0 TaskToken (vendored
/// fixture): a tender whose acceptance authority admits only fulfillers holding the required binding.
contract ASFAdapter8414Test is ASFBase {
    TaskToken task;
    ASFTaskTenderAdapter adapter;

    address owner = address(0xA11CE);
    address taskPublisher = address(0xB0B);
    address funder = address(0xF00D);
    address worker = address(0xCAFE);
    address worker2 = address(0xCAFE2);

    bytes32 TD = sha256("TASK.md v1");
    bytes32 TH = sha256("taskroot v1");
    bytes32 RES = sha256("deliverable");

    event FulfillmentAccepted(uint256 indexed tokenId, uint256 indexed submissionId, address indexed fulfiller, uint256 reward);
    event FulfillmentRejected(uint256 indexed tokenId, uint256 indexed submissionId);

    function setUp() public override {
        super.setUp();
        task = new TaskToken("Task Token", "TASK");
        // the tender requires: a self-adopted binding of spec v1, enforced at least at the account level
        T.Clause memory c = clause();
        c.versions = new uint32[](1);
        c.versions[0] = 1;
        c.enforcement = T.ENFORCED_ACCOUNT;
        adapter = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        vm.deal(funder, 100 ether);
    }

    function terms(uint64 judgmentWindow) internal pure returns (ITaskTender.TenderTerms memory) {
        return ITaskTender.TenderTerms(address(0), 1 ether, 2, 0, 0, 0, 0, judgmentWindow);
    }

    function mintWithAdapter(uint64 judgmentWindow) internal returns (uint256 id) {
        id = task.mintTask(owner, taskPublisher, address(adapter), TD, TH, "ipfs://task-v1", terms(judgmentWindow));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
    }

    function submit(address who, uint256 id) internal returns (uint256 sid) {
        vm.prank(who);
        sid = task.submitFulfillment(id, RES, "ipfs://result");
    }

    /// The worker adopts the specification for itself (adopter == subject == worker).
    function selfAdopt(address who, bytes32 salt, uint16 enforcement) internal returns (bytes32 id) {
        T.BindingInput memory i = input(salt);
        i.subjectKey = ASFKeys.accountSubjectKey(who);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = enforcement;
        id = adoptAs(who, i);
    }

    function test_fulfiller_with_binding_is_accepted_and_paid_through_the_real_kernel() public {
        bytes32 b = selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (T.Verdict pre, bytes32[] memory ids,) = adapter.evaluate(worker);
        assertVerdict(pre, T.Verdict.Satisfied);
        assertEq(ids[0], b);
        uint256 before = worker.balance;
        vm.expectEmit(true, true, true, true, address(task));
        emit FulfillmentAccepted(id, sid, worker, 1 ether);
        vm.prank(rando);
        T.Verdict v = adapter.judge(id, sid);
        assertVerdict(v, T.Verdict.Satisfied);
        assertEq(worker.balance, before + 1 ether);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Accepted));
    }

    function test_N41_fulfiller_without_binding_is_rejected_and_the_reservation_released() public {
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        assertEq(task.pendingOf(id), 1);
        vm.expectEmit(true, true, false, true, address(task));
        emit FulfillmentRejected(id, sid);
        T.Verdict v = adapter.judge(id, sid);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        assertEq(task.pendingOf(id), 0);
    }

    function test_N42_a_binding_adopted_by_someone_else_for_the_worker_does_not_count() public {
        // the task publisher "adopts" the spec for the worker: an attributable statement by the publisher,
        // not the worker's own commitment, so the tender's self-adoption clause is not met
        T.BindingInput memory i = input(keccak256("x"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.enforcement = T.ENFORCED_ACCOUNT;
        adoptAs(taskPublisher, i);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (T.Verdict v,,) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_N43_binding_suspended_between_submission_and_judgment_leads_to_rejection() public {
        bytes32 b = selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        vm.prank(worker);
        reg.suspend(b, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("self-reported incident"));
        (T.Verdict v, bytes32[] memory ids, T.Reason[] memory reasons) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(ids[0], b, "the explaining candidate is reported");
        assertReason(reasons[0], T.Reason.Suspended);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_N44_self_declared_enforcement_is_not_enough_for_this_tender() public {
        selfAdopt(worker, keccak256("w"), T.ENFORCED_SELF);
        uint256 id = mintWithAdapter(7 days);
        uint256 sid = submit(worker, id);
        (, , T.Reason[] memory reasons) = adapter.evaluate(worker);
        assertReason(reasons[0], T.Reason.EnforcementMismatch);
        adapter.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    function test_the_first_satisfying_binding_is_selected_among_several() public {
        selfAdopt(worker, keccak256("weak"), T.ENFORCED_SELF);
        bytes32 strong = selfAdopt(worker, keccak256("strong"), T.ENFORCED_ACCOUNT | T.ENFORCED_CONTRACT);
        (T.Verdict v, bytes32[] memory ids,) = adapter.evaluate(worker);
        assertVerdict(v, T.Verdict.Satisfied);
        assertEq(ids[0], strong);
    }

    function test_N45_unknown_verdict_does_nothing_and_the_task_clock_governs() public {
        // a tender whose requirement points at a specification registry that later becomes unavailable
        bytes32 tSpec = keccak256("toggle spec");
        ToggleSpecRegistry toggle = new ToggleSpecRegistry(tSpec, HASH1);
        T.Clause memory c = clause();
        c.specRegistry = address(toggle);
        c.specId = tSpec;
        ASFTaskTenderAdapter a2 = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        T.BindingInput memory i = input(keccak256("t"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.specRegistry = address(toggle);
        i.specId = tSpec;
        adoptAs(worker, i);

        uint256 id = task.mintTask(owner, taskPublisher, address(a2), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        uint256 submittedAt = vm.getBlockTimestamp();

        toggle.setBroken(true);
        vm.expectRevert("ASFTender: verdict unknown; the task clock governs");
        a2.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Pending));
        // the kernel's own default is untouched by the unknown verdict
        vm.expectRevert("TaskToken: window open");
        task.claimUnjudged(id, sid);
        vm.warp(submittedAt + 7 days + 1);
        uint256 before = worker.balance;
        task.claimUnjudged(id, sid);
        assertEq(worker.balance, before + 1 ether, "silence pays the fulfiller, on the kernel's clock");
    }

    function test_N46_adapter_requires_the_authority_and_a_pending_judged_submission() public {
        uint256 id = task.mintTask(owner, taskPublisher, rando, TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        vm.expectRevert("ASFTender: not the acceptance authority");
        adapter.judge(id, sid);

        uint256 id2 = mintWithAdapter(7 days);
        uint256 sid2 = submit(worker, id2);
        adapter.judge(id2, sid2); // rejected (no binding)
        vm.expectRevert("ASFTender: not pending");
        adapter.judge(id2, sid2);
    }

    function test_N47_template_may_not_pre_bind_adopter_or_subject() public {
        T.Clause memory c = clauseFor(worker, bytes32(0), bytes32(0), 1);
        vm.expectRevert("ASFTender: template binds adopter or subject");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        c = clauseFor(address(0), subjectAgent, bytes32(0), 1);
        vm.expectRevert("ASFTender: template binds adopter or subject");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        vm.expectRevert("ASFTender: zero address");
        new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(0)), one(clause()));
    }

    function test_requirement_for_a_fulfiller_fills_adopter_and_subject() public view {
        T.RequirementSet memory r = adapter.requirementFor(worker);
        assertEq(r.clauses[0].adopter, worker);
        assertEq(r.clauses[0].subjectKey, ASFKeys.accountSubjectKey(worker));
        assertEq(adapter.template().clauses[0].adopter, address(0));
        assertTrue(adapter.supportsInterface(0x01ffc9a7));
    }

    function test_two_workers_are_judged_independently() public {
        selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = mintWithAdapter(7 days);
        uint256 s1 = submit(worker, id);
        uint256 s2 = submit(worker2, id);
        adapter.judge(id, s1);
        adapter.judge(id, s2);
        assertEq(uint8(task.submissionOf(id, s1).status), uint8(ITaskTender.SubmissionStatus.Accepted));
        assertEq(uint8(task.submissionOf(id, s2).status), uint8(ITaskTender.SubmissionStatus.Rejected));
    }

    // ------------------------------------------------------------- who can stop a fulfiller

    /// A tender whose clause requires the task publisher as an intervener with the suspend right.
    function adapterRequiringPublisher() internal returns (ASFTaskTenderAdapter a) {
        T.Clause memory c = clause();
        c.versions = new uint32[](1);
        c.versions[0] = 1;
        c.enforcement = T.ENFORCED_ACCOUNT;
        c.interveners = new T.Intervener[](1);
        c.interveners[0] = T.Intervener({account: taskPublisher, rights: T.RIGHT_SUSPEND});
        a = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
    }

    function selfAdoptWithIntervener(address who, bytes32 salt, address intervener, uint8 rights) internal returns (bytes32 id) {
        T.BindingInput memory i = input(salt);
        i.subjectKey = ASFKeys.accountSubjectKey(who);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = T.ENFORCED_ACCOUNT;
        i.interveners = new T.Intervener[](1);
        i.interveners[0] = T.Intervener({account: intervener, rights: rights});
        id = adoptAs(who, i);
    }

    function test_N55_a_fulfiller_whose_binding_does_not_name_the_required_intervener_is_rejected() public {
        ASFTaskTenderAdapter a = adapterRequiringPublisher();
        // a self-adopted binding under the fulfiller's sole control does not meet the tender's requirement
        selfAdopt(worker, keccak256("w"), T.ENFORCED_ACCOUNT);
        uint256 id = task.mintTask(owner, taskPublisher, address(a), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 s1 = submit(worker, id);
        (T.Verdict v,, T.Reason[] memory reasons) = a.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.IntervenerMismatch);
        a.judge(id, s1);
        assertEq(uint8(task.submissionOf(id, s1).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        // a binding that names the publisher with the suspend right is admitted
        bytes32 b = selfAdoptWithIntervener(worker2, keccak256("w2"), taskPublisher, T.RIGHT_SUSPEND);
        uint256 s2 = submit(worker2, id);
        (T.Verdict v2, bytes32[] memory ids,) = a.evaluate(worker2);
        assertVerdict(v2, T.Verdict.Satisfied);
        assertEq(ids[0], b);
        a.judge(id, s2);
        assertEq(uint8(task.submissionOf(id, s2).status), uint8(ITaskTender.SubmissionStatus.Accepted));
    }

    function test_N56_the_publishers_suspension_is_not_the_fulfillers_to_lift_before_judgment() public {
        ASFTaskTenderAdapter a = adapterRequiringPublisher();
        bytes32 b = selfAdoptWithIntervener(worker, keccak256("w"), taskPublisher, T.RIGHT_SUSPEND);
        uint256 id = task.mintTask(owner, taskPublisher, address(a), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        // the publisher suspends the fulfiller's binding after a report; the fulfiller cannot resume it
        vm.prank(taskPublisher);
        reg.suspend(b, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report"));
        vm.prank(worker);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(b, bytes32(0));
        (T.Verdict v,, T.Reason[] memory reasons) = a.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertReason(reasons[0], T.Reason.Suspended);
        a.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        // terminating the suspended record and adopting afresh does not escape the stop: the publisher's
        // suspension stands against the fulfiller for the subject and the specification (Section 8.5), and the
        // terminated record keeps showing who stopped it
        vm.prank(worker);
        reg.terminate(b, bytes32(0));
        assertEq(uint8(reg.bindingOf(b).state), uint8(T.BindingState.Terminated));
        assertEq(reg.bindingOf(b).suspendedBy, taskPublisher);
        bytes32 fresh = selfAdoptWithIntervener(worker, keccak256("w-fresh"), taskPublisher, T.RIGHT_SUSPEND);
        (T.Verdict v2, bytes32[] memory ids, T.Reason[] memory reasons2) = a.evaluate(worker);
        assertVerdict(v2, T.Verdict.NotSatisfied);
        assertEq(ids[0], fresh);
        assertReason(reasons2[0], T.Reason.StoppedByIntervener);
        T.Stop memory stop = reg.stopOf(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher);
        assertEq(stop.bindingId, b);
        assertEq(stop.restrictions, T.RESTRICT_FULL_STOP);
        // the stop is the publisher's: the fulfiller cannot lift it, the suspend-only publisher can, without
        // holding any resume right on a binding
        vm.prank(worker);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, bytes32(0));
        vm.prank(taskPublisher);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, keccak256("cleared"));
        (T.Verdict v3, bytes32[] memory ids3,) = a.evaluate(worker);
        assertVerdict(v3, T.Verdict.Satisfied);
        assertEq(ids3[0], fresh);
    }

    function adapterRequiringPublisherWith(uint8 rights) internal returns (ASFTaskTenderAdapter a) {
        T.Clause memory c = clause();
        c.versions = new uint32[](1);
        c.versions[0] = 1;
        c.enforcement = T.ENFORCED_ACCOUNT;
        c.interveners = new T.Intervener[](1);
        c.interveners[0] = T.Intervener({account: taskPublisher, rights: rights});
        a = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
    }

    function test_N61_a_sibling_binding_does_not_escape_the_publishers_stop() public {
        ASFTaskTenderAdapter a = adapterRequiringPublisher();
        // the fulfiller holds two bindings for the same subject and specification, both naming the publisher
        // with the suspend right exactly as the clause asks
        bytes32 b1 = selfAdoptWithIntervener(worker, keccak256("w-1"), taskPublisher, T.RIGHT_SUSPEND);
        bytes32 b2 = selfAdoptWithIntervener(worker, keccak256("w-2"), taskPublisher, T.RIGHT_SUSPEND);
        uint256 id = task.mintTask(owner, taskPublisher, address(a), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        (T.Verdict v0, bytes32[] memory ids0,) = a.evaluate(worker);
        assertVerdict(v0, T.Verdict.Satisfied);
        assertEq(ids0[0], b1);
        // the publisher suspends the first; the second is Active and untouched, and is still refused
        vm.prank(taskPublisher);
        reg.suspend(b1, T.RESTRICT_FULL_STOP, keccak256("resp"), keccak256("report"));
        assertEq(uint8(reg.bindingOf(b2).state), uint8(T.BindingState.Active));
        (T.Verdict v, bytes32[] memory ids, T.Reason[] memory reasons) = a.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(ids[0], b1);
        assertReason(reasons[0], T.Reason.Suspended);
        (T.Verdict vb2, T.Reason rb2, uint8 setb2) = reg.checkBinding(b2, a.requirementFor(worker).clauses[0]);
        assertVerdict(vb2, T.Verdict.NotSatisfied);
        assertReason(rb2, T.Reason.StoppedByIntervener);
        assertEq(setb2, T.RESTRICT_FULL_STOP);
        // judgment by anyone, including the fulfiller, rejects
        vm.prank(worker);
        a.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        // a third binding adopted after the stop is refused as well
        selfAdoptWithIntervener(worker, keccak256("w-3"), taskPublisher, T.RIGHT_SUSPEND);
        (T.Verdict v3,,) = a.evaluate(worker);
        assertVerdict(v3, T.Verdict.NotSatisfied);
    }

    function test_N62_the_publishers_stop_follows_the_fulfiller_until_the_publisher_lifts_it() public {
        // the tender names the publisher with the suspend and the resume right, so that the stop it records can
        // also be lifted by it
        ASFTaskTenderAdapter a = adapterRequiringPublisherWith(T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        bytes32 b = selfAdoptWithIntervener(worker, keccak256("w"), taskPublisher, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        uint256 id = task.mintTask(owner, taskPublisher, address(a), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        vm.prank(taskPublisher);
        reg.suspend(b, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY, keccak256("resp"), keccak256("report"));
        // the fulfiller terminates the suspended record and adopts afresh, then calls judge itself: rejected
        vm.prank(worker);
        reg.terminate(b, keccak256("replaced"));
        bytes32 fresh = selfAdoptWithIntervener(worker, keccak256("w-fresh"), taskPublisher, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        (T.Verdict v, bytes32[] memory ids, T.Reason[] memory reasons) = a.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(ids[0], fresh);
        assertReason(reasons[0], T.Reason.StoppedByIntervener);
        (, , uint8 set) = reg.checkBinding(fresh, a.requirementFor(worker).clauses[0]);
        assertEq(set, T.RESTRICT_NO_NEW_RISK | T.RESTRICT_DERISK_ONLY);
        // the terminated record is terminal for everyone, and the stop is not the fulfiller's to lift
        vm.prank(taskPublisher);
        vm.expectRevert(ASFErrors.InvalidState.selector);
        reg.resume(b, bytes32(0));
        vm.prank(worker);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, bytes32(0));
        // the publisher lifts it; the record stays Terminated and the fresh binding is admitted
        vm.prank(taskPublisher);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, keccak256("report dismissed"));
        assertEq(uint8(reg.bindingOf(b).state), uint8(T.BindingState.Terminated));
        assertEq(reg.stopOf(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher).bindingId, bytes32(0));
        (T.Verdict v2, bytes32[] memory ids2,) = a.evaluate(worker);
        assertVerdict(v2, T.Verdict.Satisfied);
        assertEq(ids2[0], fresh);
        a.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Accepted));
        // and the publisher can stop the fresh binding as well; the stop then points at it, and the publisher's
        // own resumption of the fresh binding lifts the stop with it
        vm.prank(taskPublisher);
        reg.suspend(fresh, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report, again"));
        assertEq(reg.stopOf(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher).bindingId, fresh);
        vm.prank(taskPublisher);
        reg.resume(fresh, keccak256("report dismissed, again"));
        assertEq(reg.stopOf(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher).bindingId, bytes32(0));
        (T.Verdict v4,,) = a.evaluate(worker);
        assertVerdict(v4, T.Verdict.Satisfied);
    }

    function test_N67_the_executor_of_one_tender_cannot_free_a_fulfiller_for_a_tender_that_never_named_it() public {
        // tender A names the publisher (suspend) and an executor (resume); tender B names only the publisher
        // (suspend and resume). The fulfiller holds one binding shaped for each.
        address executor = address(0xE8EC);
        T.Clause memory ca = clause();
        ca.versions = new uint32[](1);
        ca.versions[0] = 1;
        ca.enforcement = T.ENFORCED_ACCOUNT;
        ca.interveners = new T.Intervener[](2);
        ca.interveners[0] = T.Intervener({account: taskPublisher, rights: T.RIGHT_SUSPEND});
        ca.interveners[1] = T.Intervener({account: executor, rights: T.RIGHT_RESUME});
        ASFTaskTenderAdapter tenderA = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(ca));
        ASFTaskTenderAdapter tenderB = adapterRequiringPublisherWith(T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        T.BindingInput memory i = input(keccak256("w-a"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = T.ENFORCED_ACCOUNT;
        i.interveners = ca.interveners;
        bytes32 ba = adoptAs(worker, i);
        bytes32 bb = selfAdoptWithIntervener(worker, keccak256("w-b"), taskPublisher, T.RIGHT_SUSPEND | T.RIGHT_RESUME);
        uint256 idA = task.mintTask(owner, taskPublisher, address(tenderA), TD, TH, "ipfs://task-a", terms(7 days));
        uint256 idB = task.mintTask(owner, taskPublisher, address(tenderB), TD, TH, "ipfs://task-b", terms(7 days));
        vm.startPrank(funder);
        task.fundTask{value: 2 ether}(idA, 2 ether);
        task.fundTask{value: 2 ether}(idB, 2 ether);
        vm.stopPrank();
        uint256 sa = submit(worker, idA);
        uint256 sb = submit(worker, idB);
        {
            (T.Verdict va, bytes32[] memory idsa,) = tenderA.evaluate(worker);
            (T.Verdict vb, bytes32[] memory idsb,) = tenderB.evaluate(worker);
            assertVerdict(va, T.Verdict.Satisfied);
            assertEq(idsa[0], ba);
            assertVerdict(vb, T.Verdict.Satisfied);
            assertEq(idsb[0], bb);
        }
        // the publisher stops the fulfiller through the binding of tender A; the executor of tender A resumes
        // that record. Tender B never named the executor: the publisher's stop still stands for it (and for A)
        vm.prank(taskPublisher);
        reg.suspend(ba, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report"));
        vm.prank(executor);
        reg.resume(ba, keccak256("decision"));
        assertEq(uint8(reg.bindingOf(ba).state), uint8(T.BindingState.Active));
        {
            (T.Verdict vb,,) = tenderB.evaluate(worker);
            assertVerdict(vb, T.Verdict.NotSatisfied);
            (T.Verdict vbb, T.Reason rbb, uint8 setbb) = reg.checkBinding(bb, tenderB.requirementFor(worker).clauses[0]);
            assertVerdict(vbb, T.Verdict.NotSatisfied);
            assertReason(rbb, T.Reason.StoppedByIntervener);
            assertEq(setbb, T.RESTRICT_FULL_STOP);
            (T.Verdict va, bytes32[] memory idsa, T.Reason[] memory ra) = tenderA.evaluate(worker);
            assertVerdict(va, T.Verdict.NotSatisfied);
            assertEq(idsa[0], ba);
            assertReason(ra[0], T.Reason.StoppedByIntervener);
        }
        vm.prank(worker);
        tenderB.judge(idB, sb);
        assertEq(uint8(task.submissionOf(idB, sb).status), uint8(ITaskTender.SubmissionStatus.Rejected));
        // the executor cannot lift the publisher's stop; the publisher can, and tender A then accepts
        vm.prank(executor);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, bytes32(0));
        vm.prank(taskPublisher);
        reg.liftStop(worker, ASFKeys.accountSubjectKey(worker), address(specs), specId, taskPublisher, keccak256("report dismissed"));
        tenderA.judge(idA, sa);
        assertEq(uint8(task.submissionOf(idA, sa).status), uint8(ITaskTender.SubmissionStatus.Accepted));
        // had the publisher named the executor as its lifter, the executor's resumption would have lifted the
        // stop for both tenders at once
        vm.prank(taskPublisher);
        reg.setStopLifter(executor);
        vm.prank(taskPublisher);
        reg.suspend(ba, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report"));
        {
            (T.Verdict vb,,) = tenderB.evaluate(worker);
            assertVerdict(vb, T.Verdict.NotSatisfied);
        }
        vm.prank(executor);
        reg.resume(ba, keccak256("decision"));
        {
            (T.Verdict vb,,) = tenderB.evaluate(worker);
            assertVerdict(vb, T.Verdict.Satisfied);
        }
    }

    function test_N58_a_fulfiller_cannot_keep_a_resume_key_of_its_own_beside_the_required_intervener() public {
        ASFTaskTenderAdapter a = adapterRequiringPublisher();
        // the fulfiller names the publisher with the suspend right, as required, and adds an address it controls
        // with the resume right: with it the publisher's suspension would be lifted in the next block
        address puppetKey = address(0xD011);
        T.BindingInput memory i = input(keccak256("w"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = T.ENFORCED_ACCOUNT;
        i.interveners = new T.Intervener[](2);
        i.interveners[0] = T.Intervener({account: taskPublisher, rights: T.RIGHT_SUSPEND});
        i.interveners[1] = T.Intervener({account: puppetKey, rights: T.RIGHT_RESUME});
        bytes32 b = adoptAs(worker, i);
        uint256 id = task.mintTask(owner, taskPublisher, address(a), TD, TH, "ipfs://task-v1", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = submit(worker, id);
        // the binding is refused before any suspension happens: an unnamed holder of the resume right
        (T.Verdict v, bytes32[] memory ids, T.Reason[] memory reasons) = a.evaluate(worker);
        assertVerdict(v, T.Verdict.NotSatisfied);
        assertEq(ids[0], b);
        assertReason(reasons[0], T.Reason.IntervenerMismatch);
        a.judge(id, sid);
        assertEq(uint8(task.submissionOf(id, sid).status), uint8(ITaskTender.SubmissionStatus.Rejected));

        // the escalation shape the tender can choose: name the publisher (suspend) and an executor (resume); the
        // fulfiller's binding then grants exactly those, the publisher's stop is lifted by the executor and nobody else
        address executor = address(0xE8EC);
        T.Clause memory c = clause();
        c.versions = new uint32[](1);
        c.versions[0] = 1;
        c.enforcement = T.ENFORCED_ACCOUNT;
        c.interveners = new T.Intervener[](2);
        c.interveners[0] = T.Intervener({account: taskPublisher, rights: T.RIGHT_SUSPEND});
        c.interveners[1] = T.Intervener({account: executor, rights: T.RIGHT_RESUME});
        ASFTaskTenderAdapter esc = new ASFTaskTenderAdapter(reg, ITaskTenderKernel(address(task)), one(c));
        i = input(keccak256("w2"));
        i.subjectKey = ASFKeys.accountSubjectKey(worker2);
        i.scopeKey = ASFKeys.refScopeKey("task-tenders");
        i.enforcement = T.ENFORCED_ACCOUNT;
        i.interveners = new T.Intervener[](2);
        i.interveners[0] = T.Intervener({account: taskPublisher, rights: T.RIGHT_SUSPEND});
        i.interveners[1] = T.Intervener({account: executor, rights: T.RIGHT_RESUME});
        bytes32 b2 = adoptAs(worker2, i);
        uint256 id2 = task.mintTask(owner, taskPublisher, address(esc), TD, TH, "ipfs://task-v2", terms(7 days));
        vm.prank(funder);
        task.fundTask{value: 2 ether}(id2, 2 ether);
        uint256 sid2 = submit(worker2, id2);
        vm.prank(taskPublisher);
        reg.suspend(b2, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report"));
        vm.prank(worker2);
        vm.expectRevert(ASFErrors.NotAuthorized.selector);
        reg.resume(b2, bytes32(0));
        (T.Verdict v2,,) = esc.evaluate(worker2);
        assertVerdict(v2, T.Verdict.NotSatisfied);
        // the executor reopens the record, but the stop is the publisher's: the publisher names the executor as
        // its lifter, and the executor's resumption then lifts the stop as well
        vm.prank(executor);
        reg.resume(b2, keccak256("report dismissed"));
        (T.Verdict v3,, T.Reason[] memory r3) = esc.evaluate(worker2);
        assertVerdict(v3, T.Verdict.NotSatisfied);
        assertReason(r3[0], T.Reason.StoppedByIntervener);
        vm.prank(taskPublisher);
        reg.setStopLifter(executor);
        vm.prank(taskPublisher);
        reg.suspend(b2, T.RESTRICT_FULL_STOP, bytes32(0), keccak256("report"));
        vm.prank(executor);
        reg.resume(b2, keccak256("report dismissed"));
        (T.Verdict v4,,) = esc.evaluate(worker2);
        assertVerdict(v4, T.Verdict.Satisfied);
        esc.judge(id2, sid2);
        assertEq(uint8(task.submissionOf(id2, sid2).status), uint8(ITaskTender.SubmissionStatus.Accepted));
    }
}
