public with sharing class ApprovalTaskService {

    /**
     * Entry point called on initial submission.
     * Resolves the first (lowest Rule_Order__c) stage and creates tasks for it.
     */
    @AuraEnabled
    public static void createInitialTasks(Approval_Request__c requestRecord) {
        if (requestRecord == null) return;
        Integer firstStage = ApprovalRouteResolver.getFirstStage(requestRecord.Process__c);
        createTasksForStage(requestRecord, firstStage);
    }

    /**
     * Creates Approval_Task__c records for all approvers in a given stage,
     * then stamps Current_Stage__c on the request and logs the event.
     * Called on initial submission (stage 1) and by the evaluator on stage advance.
     */
    public static void createTasksForStage(Approval_Request__c requestRecord, Integer stage) {
        List<Id> approverIds = ApprovalRouteResolver.resolveApproverIds(requestRecord, stage);

        List<Approval_Task__c> tasks = new List<Approval_Task__c>();
        for (Id approverId : approverIds) {
            tasks.add(new Approval_Task__c(
                Approval_Request__c = requestRecord.Id,
                Assignee__c         = approverId,
                Task_Status__c      = 'Open',
                Stage_Number__c     = stage
            ));
        }
        if (!tasks.isEmpty()) insert tasks;

        // Stamp the active stage so the evaluator always knows where we are
        requestRecord.Current_Stage__c = String.valueOf(stage);
        update requestRecord;

        ApprovalHistoryLogger.logAction(
            requestRecord.Id,
            'Stage ' + stage + ' Initiated',
            requestRecord.Status__c,
            requestRecord.Status__c,
            'Stage ' + stage + ' started — ' + tasks.size() + ' approver task(s) created.'
        );
    }

    @AuraEnabled
    public static void approveTask(Id taskId, String comments) {
        Approval_Task__c task = [
            SELECT Id, Approval_Request__c, Task_Status__c
            FROM   Approval_Task__c WHERE Id = :taskId LIMIT 1
        ];
        task.Task_Status__c   = 'Approved';
        task.Decision__c      = 'Approved';
        task.Decision_Date__c = System.now();
        task.Comments__c      = comments;
        update task;

        ApprovalHistoryLogger.logTaskDecision(taskId, 'Approved', comments);
        ApprovalDecisionEvaluator.evaluateTaskOutcome(task.Approval_Request__c);
    }

    @AuraEnabled
    public static void rejectTask(Id taskId, String comments) {
        Approval_Task__c task = [
            SELECT Id, Approval_Request__c, Task_Status__c
            FROM   Approval_Task__c WHERE Id = :taskId LIMIT 1
        ];
        task.Task_Status__c   = 'Rejected';
        task.Decision__c      = 'Rejected';
        task.Decision_Date__c = System.now();
        task.Comments__c      = comments;
        update task;

        ApprovalHistoryLogger.logTaskDecision(taskId, 'Rejected', comments);
        ApprovalDecisionEvaluator.evaluateTaskOutcome(task.Approval_Request__c);
    }
}
