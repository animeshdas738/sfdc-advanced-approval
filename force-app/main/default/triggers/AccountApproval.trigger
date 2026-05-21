trigger AccountApproval on Account (after insert, after update) {
    ApprovalProcessEvaluator.evaluate(Trigger.new, Trigger.oldMap, 'Account');
}
