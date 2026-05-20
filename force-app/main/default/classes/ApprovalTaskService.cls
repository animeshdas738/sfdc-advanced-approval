public with sharing class ApprovalTaskService {
    @AuraEnabled
    public static void createInitialTasks(Approval_Request__c requestRecord) {
        if (requestRecord == null) {
            return;
        }

        List<Approval_Task__c> tasks = new List<Approval_Task__c>();

        List<Id> approverIds = ApprovalRouteResolver.resolveApproverIds(requestRecord);
        for (Id approverId : approverIds) {
            Approval_Task__c task = new Approval_Task__c();
            task.Approval_Request__c = requestRecord.Id;
            task.Assignee__c = approverId;
            task.Task_Status__c = 'Open';
            tasks.add(task);
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    @AuraEnabled
    public static void approveTask(Id taskId, String comments) {
        Approval_Task__c task = [SELECT Id, Approval_Request__c, Task_Status__c FROM Approval_Task__c WHERE Id = :taskId LIMIT 1];
        String previousStatus = task.Task_Status__c;
        task.Task_Status__c = 'Approved';
        task.Decision__c = 'Approved';
        task.Decision_Date__c = System.now();
        task.Comments__c = comments;
        update task;

        ApprovalHistoryLogger.logTaskDecision(taskId, 'Approved', comments);
        ApprovalDecisionEvaluator.evaluateTaskOutcome(task.Approval_Request__c);
    }

    @AuraEnabled
    public static void rejectTask(Id taskId, String comments) {
        Approval_Task__c task = [SELECT Id, Approval_Request__c, Task_Status__c FROM Approval_Task__c WHERE Id = :taskId LIMIT 1];
        String previousStatus = task.Task_Status__c;
        task.Task_Status__c = 'Rejected';
        task.Decision__c = 'Rejected';
        task.Decision_Date__c = System.now();
        task.Comments__c = comments;
        update task;

        ApprovalHistoryLogger.logTaskDecision(taskId, 'Rejected', comments);
        ApprovalDecisionEvaluator.evaluateTaskOutcome(task.Approval_Request__c);
    }
}
