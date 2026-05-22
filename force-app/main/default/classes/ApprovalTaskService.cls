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

    /**
     * Returns context for the current user's approval task on the given record.
     * Two-step lookup: request by Target_Record_Id__c (Text) first, then task by
     * the request's Id (a proper relationship field). Avoids cross-object Text
     * field filtering which is unreliable with Id bind variables in SOQL.
     */
    @AuraEnabled(cacheable=true)
    public static TaskContext getMyTaskContext(Id recordId) {
        TaskContext ctx = new TaskContext();
        if (recordId == null) return ctx;

        // Step 1 — find the pending request; explicit String cast matches the Text field
        String recIdStr = String.valueOf(recordId);
        List<Approval_Request__c> reqs = [
            SELECT Id, Status__c, Current_Stage__c
            FROM   Approval_Request__c
            WHERE  Target_Record_Id__c = :recIdStr
            AND    Status__c = 'Pending'
            LIMIT 1
        ];
        if (reqs.isEmpty()) return ctx;
        ctx.requestExists = true;

        // Step 2 — find the current user's open task via the proper Id relationship
        Id reqId = reqs[0].Id;
        List<Approval_Task__c> tasks = [
            SELECT Id, Task_Status__c, Stage_Number__c
            FROM   Approval_Task__c
            WHERE  Approval_Request__c = :reqId
            AND    Assignee__c = :UserInfo.getUserId()
            AND    Task_Status__c = 'Open'
            LIMIT 1
        ];
        if (!tasks.isEmpty()) {
            ctx.task = tasks[0];
            ctx.isAssignee = true;
        }
        return ctx;
    }

    public class TaskContext {
        @AuraEnabled public Boolean requestExists = false;
        @AuraEnabled public Boolean isAssignee   = false;
        @AuraEnabled public Approval_Task__c task;
    }

    @AuraEnabled
    public static void approveTask(Id taskId, String comments) {
        List<Approval_Task__c> tasks = [
            SELECT Id, Approval_Request__c, Task_Status__c
            FROM   Approval_Task__c WHERE Id = :taskId LIMIT 1
        ];
        if (tasks.isEmpty()) throw new AuraHandledException('Approval task not found: ' + taskId);
        Approval_Task__c task = tasks[0];
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
        List<Approval_Task__c> tasks = [
            SELECT Id, Approval_Request__c, Task_Status__c
            FROM   Approval_Task__c WHERE Id = :taskId LIMIT 1
        ];
        if (tasks.isEmpty()) throw new AuraHandledException('Approval task not found: ' + taskId);
        Approval_Task__c task = tasks[0];
        task.Task_Status__c   = 'Rejected';
        task.Decision__c      = 'Rejected';
        task.Decision_Date__c = System.now();
        task.Comments__c      = comments;
        update task;

        ApprovalHistoryLogger.logTaskDecision(taskId, 'Rejected', comments);
        ApprovalDecisionEvaluator.evaluateTaskOutcome(task.Approval_Request__c);
    }
}
