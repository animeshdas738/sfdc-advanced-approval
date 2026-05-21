public with sharing class ApprovalDecisionEvaluator {

    /**
     * Evaluates the outcome of the CURRENT stage after each task decision.
     *
     * Stage progression:
     *   • Any task Rejected  → entire request is immediately Rejected (all stages)
     *   • Current stage threshold met (per Parallel_Mode__c) AND a next stage exists
     *                         → advance: create tasks for next stage
     *   • Current stage threshold met AND no further stages exist
     *                         → request fully Approved
     *   • Threshold not yet met → no-op (wait for remaining approvers)
     *
     * Stage identification: Rule_Order__c on Approval_Rule__c defines stage numbers.
     * Tasks are stamped with Stage_Number__c at creation time.
     */
    public static void evaluateTaskOutcome(Id approvalRequestId) {
        Approval_Request__c req = [
            SELECT Id, Status__c, Parallel_Mode__c, Outcome__c, Current_Stage__c, Process__c,
                   (SELECT Id, Task_Status__c, Stage_Number__c FROM Approval_Tasks__r)
            FROM   Approval_Request__c
            WHERE  Id = :approvalRequestId
            LIMIT 1
        ];
        if (req == null) return;

        // Determine the active stage number
        Integer currentStage = String.isNotBlank(req.Current_Stage__c)
            ? Integer.valueOf(req.Current_Stage__c)
            : ApprovalRouteResolver.getFirstStage(req.Process__c);

        // Isolate tasks that belong to the current stage
        List<Approval_Task__c> stageTasks = new List<Approval_Task__c>();
        for (Approval_Task__c t : req.Approval_Tasks__r) {
            Integer taskStage = t.Stage_Number__c != null
                ? t.Stage_Number__c.intValue()
                : currentStage;
            if (taskStage == currentStage) stageTasks.add(t);
        }

        Boolean anyRejected  = false;
        Integer approvedCount = 0;
        Boolean allResolved   = true;
        Integer totalCount    = stageTasks.size();

        for (Approval_Task__c t : stageTasks) {
            if (t.Task_Status__c == 'Rejected') anyRejected   = true;
            if (t.Task_Status__c == 'Approved') approvedCount++;
            if (t.Task_Status__c == 'Open')     allResolved   = false;
        }

        // ── Rejection: immediately fail the whole request ─────────────────────
        if (anyRejected) {
            req.Status__c  = 'Rejected';
            req.Outcome__c = 'Rejected';
            update req;
            ApprovalHistoryLogger.logRequestStatusChange(approvalRequestId, 'Pending', 'Rejected');
            return;
        }

        // ── Check if the current stage's approval threshold is met ────────────
        Boolean stageApproved = false;
        if      (req.Parallel_Mode__c == 'Any'     && approvedCount > 0)              stageApproved = true;
        else if (req.Parallel_Mode__c == 'Majority' && approvedCount * 2 >= totalCount) stageApproved = true;
        else if (allResolved && totalCount > 0)                                          stageApproved = true; // 'All' default

        if (!stageApproved) return; // Stage still in progress — wait

        // ── Stage approved: advance or finalise ───────────────────────────────
        Integer nextStage = ApprovalRouteResolver.getNextStage(req.Process__c, currentStage);

        if (nextStage != null) {
            // More stages remain — advance
            ApprovalHistoryLogger.logAction(
                approvalRequestId,
                'Stage ' + currentStage + ' Approved',
                'Pending', 'Pending',
                'Stage ' + currentStage + ' approved. Advancing to Stage ' + nextStage + '.'
            );
            ApprovalTaskService.createTasksForStage(req, nextStage);
        } else {
            // Final stage approved — close the request
            req.Status__c  = 'Approved';
            req.Outcome__c = 'Approved';
            update req;
            ApprovalHistoryLogger.logRequestStatusChange(approvalRequestId, 'Pending', 'Approved');
        }
    }
}
