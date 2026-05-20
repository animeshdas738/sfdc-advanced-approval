public with sharing class SubmitForApprovalAction {
    @InvocableMethod(label='Submit for Approval' description='Submit a record for the advanced approval process')
    public static List<ApprovalResult> submitForApproval(List<ApprovalRequest> requests) {
        List<ApprovalResult> results = new List<ApprovalResult>();

        for (ApprovalRequest req : requests) {
            ApprovalResult result = new ApprovalResult();
            try {
                Approval_Request__c approvalReq = new Approval_Request__c();
                approvalReq.Target_Record_Id__c = req.targetRecordId;
                approvalReq.Process__c = req.processId;
                approvalReq.Requested_By__c = UserInfo.getUserId();
                approvalReq.Requested_Date__c = System.now();
                approvalReq.Status__c = 'Pending';
                approvalReq.Parallel_Mode__c = req.parallelMode != null ? req.parallelMode : 'All';
                insert approvalReq;

                ApprovalTaskService.createInitialTasks(approvalReq);

                result.isSuccess = true;
                result.approvalRequestId = approvalReq.Id;
                result.message = 'Approval request submitted successfully.';

                // Log to approval history
                logApprovalHistory(approvalReq.Id, 'Submitted', 'Pending', 'Pending', 'Approval request submitted.');
            } catch (Exception ex) {
                result.isSuccess = false;
                result.message = 'Error: ' + ex.getMessage();
            }
            results.add(result);
        }

        return results;
    }

    public class ApprovalRequest {
        @InvocableVariable(required=true label='Target Record ID')
        public String targetRecordId;

        @InvocableVariable(required=true label='Process ID')
        public String processId;

        @InvocableVariable(required=false label='Parallel Mode' description='All, Any, or Majority')
        public String parallelMode;
    }

    public class ApprovalResult {
        @InvocableVariable(label='Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Approval Request ID')
        public String approvalRequestId;

        @InvocableVariable(label='Message')
        public String message;
    }

    private static void logApprovalHistory(Id approvalRequestId, String action, String previousState, String newState, String comments) {
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
            System.debug('Failed to log approval history: ' + ex.getMessage());
        }
    }
}
