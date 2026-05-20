public with sharing class ApprovalDecisionEvaluator {
    public static void evaluateTaskOutcome(Id approvalRequestId) {
        Approval_Request__c approvalRequest = [
            SELECT Id, Status__c, Parallel_Mode__c, Outcome__c,
                (SELECT Id, Task_Status__c, Decision__c FROM Approval_Tasks__r)
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];

        if (approvalRequest == null) {
            return;
        }

        Boolean allApproved = true;
        Boolean anyRejected = false;
        Integer approvedCount = 0;
        Integer totalCount = approvalRequest.Approval_Tasks__r.size();

        for (Approval_Task__c task : approvalRequest.Approval_Tasks__r) {
            if (task.Task_Status__c == 'Rejected') {
                anyRejected = true;
            }
            if (task.Task_Status__c == 'Approved') {
                approvedCount += 1;
            }
            if (task.Task_Status__c != 'Approved') {
                allApproved = false;
            }
        }

        String finalOutcome;
        if (anyRejected) {
            finalOutcome = 'Rejected';
        } else if (approvalRequest.Parallel_Mode__c == 'Any' && approvedCount > 0) {
            finalOutcome = 'Approved';
        } else if (approvalRequest.Parallel_Mode__c == 'Majority' && approvedCount * 2 >= totalCount) {
            finalOutcome = 'Approved';
        } else if (allApproved && totalCount > 0) {
            finalOutcome = 'Approved';
        }

        if (finalOutcome != null) {
            approvalRequest.Status__c = finalOutcome == 'Approved' ? 'Approved' : 'Rejected';
            approvalRequest.Outcome__c = finalOutcome;
            update approvalRequest;
        }
    }
}
