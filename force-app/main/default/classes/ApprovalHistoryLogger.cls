public with sharing class ApprovalHistoryLogger {
    public static void logAction(Id approvalRequestId, String action, String previousState, String newState, String comments) {
        try {
            Approval_History__c history = new Approval_History__c();
            history.Approval_Request__c = approvalRequestId;
            history.Action__c = action;
            history.Actor__c = UserInfo.getUserId();
            history.Previous_State__c = previousState;
            history.New_State__c = newState;
            history.Comments__c = comments;
            history.Activity_Date__c = System.now();
            insert history;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to log approval history: ' + ex.getMessage());
        }
    }

    public static void logTaskDecision(Id taskId, String decision, String comments) {
        try {
            Approval_Task__c task = [SELECT Id, Approval_Request__c FROM Approval_Task__c WHERE Id = :taskId LIMIT 1];
            logAction(task.Approval_Request__c, 'Task Decision', 'Open', decision, 'Task ' + taskId + ' decided as: ' + decision + '. Comments: ' + comments);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to log task decision: ' + ex.getMessage());
        }
    }

    public static void logRequestStatusChange(Id approvalRequestId, String previousStatus, String newStatus) {
        try {
            logAction(approvalRequestId, 'Status Change', previousStatus, newStatus, 'Approval request status changed from ' + previousStatus + ' to ' + newStatus);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to log status change: ' + ex.getMessage());
        }
    }
}
