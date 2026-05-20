public with sharing class ApprovalRequestService {
    public class ApprovalRequestResult {
        @AuraEnabled public Id approvalRequestId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static ApprovalRequestResult createApprovalRequest(Id targetRecordId, Id processId, Id requestedById) {
        ApprovalRequestResult result = new ApprovalRequestResult();

        try {
            Approval_Request__c approvalRequest = new Approval_Request__c();
            approvalRequest.Target_Record_Id__c = targetRecordId;
            approvalRequest.Process__c = processId;
            approvalRequest.Requested_By__c = requestedById;
            approvalRequest.Requested_Date__c = System.now();
            approvalRequest.Status__c = 'Pending';
            insert approvalRequest;

            ApprovalTaskService.createInitialTasks(approvalRequest);

            result.approvalRequestId = approvalRequest.Id;
            result.success = true;
            result.message = 'Approval request created successfully.';
        } catch (Exception ex) {
            result.success = false;
            result.message = 'Failed to create approval request: ' + ex.getMessage();
        }

        return result;
    }

    public static List<Approval_Request__c> getPendingRequests(List<Id> targetIds) {
        if (targetIds == null || targetIds.isEmpty()) {
            return new List<Approval_Request__c>();
        }

        return [
            SELECT Id, Target_Record_Id__c, Status__c, Current_Stage__c, Process__c, Outcome__c
            FROM Approval_Request__c
            WHERE Target_Record_Id__c IN :targetIds
                AND Status__c = 'Pending'
        ];
    }
}
