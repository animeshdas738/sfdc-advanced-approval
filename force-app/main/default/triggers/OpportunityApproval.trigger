trigger OpportunityApproval on Opportunity (after insert, after update) {
    ApprovalProcessEvaluator.evaluate(Trigger.new, Trigger.oldMap, 'Opportunity');
}
