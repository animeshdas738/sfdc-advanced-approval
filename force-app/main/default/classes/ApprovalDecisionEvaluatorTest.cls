@isTest
public class ApprovalDecisionEvaluatorTest {
    @TestSetup
    static void setup() {
        Approval_Process__c process = new Approval_Process__c();
        process.Name = 'Test Process';
        process.Target_Object__c = 'Account';
        process.Active__c = true;
        insert process;
    }

    @isTest
    static void testAllApproversApprove() {
        Approval_Process__c process = [SELECT Id FROM Approval_Process__c LIMIT 1];
        
        Approval_Request__c request = new Approval_Request__c();
        request.Process__c = process.Id;
        request.Target_Record_Id__c = null;
        request.Status__c = 'Pending';
        request.Parallel_Mode__c = 'All';
        insert request;

        User user1 = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Approval_Task__c task1 = new Approval_Task__c();
        task1.Approval_Request__c = request.Id;
        task1.Assignee__c = user1.Id;
        task1.Task_Status__c = 'Open';
        insert task1;

        Approval_Task__c task2 = new Approval_Task__c();
        task2.Approval_Request__c = request.Id;
        task2.Assignee__c = user1.Id;
        task2.Task_Status__c = 'Open';
        insert task2;

        Test.startTest();
        task1.Task_Status__c = 'Approved';
        update task1;

        task2.Task_Status__c = 'Approved';
        update task2;

        ApprovalDecisionEvaluator.evaluateTaskOutcome(request.Id);
        Test.stopTest();

        Approval_Request__c evaluatedRequest = [SELECT Status__c, Outcome__c FROM Approval_Request__c WHERE Id = :request.Id];
        Assert.areEqual('Approved', evaluatedRequest.Status__c, 'Request should be approved when all tasks approved');
    }

    @isTest
    static void testAnyApprover() {
        Approval_Process__c process = [SELECT Id FROM Approval_Process__c LIMIT 1];
        
        Approval_Request__c request = new Approval_Request__c();
        request.Process__c = process.Id;
        request.Target_Record_Id__c = null;
        request.Status__c = 'Pending';
        request.Parallel_Mode__c = 'Any';
        insert request;

        User user1 = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Approval_Task__c task1 = new Approval_Task__c();
        task1.Approval_Request__c = request.Id;
        task1.Assignee__c = user1.Id;
        task1.Task_Status__c = 'Open';
        insert task1;

        Approval_Task__c task2 = new Approval_Task__c();
        task2.Approval_Request__c = request.Id;
        task2.Assignee__c = user1.Id;
        task2.Task_Status__c = 'Open';
        insert task2;

        Test.startTest();
        task1.Task_Status__c = 'Approved';
        update task1;

        ApprovalDecisionEvaluator.evaluateTaskOutcome(request.Id);
        Test.stopTest();

        Approval_Request__c evaluatedRequest = [SELECT Status__c, Outcome__c FROM Approval_Request__c WHERE Id = :request.Id];
        Assert.areEqual('Approved', evaluatedRequest.Status__c, 'Request should be approved when any task approved');
    }

    @isTest
    static void testRejectDecision() {
        Approval_Process__c process = [SELECT Id FROM Approval_Process__c LIMIT 1];
        
        Approval_Request__c request = new Approval_Request__c();
        request.Process__c = process.Id;
        request.Target_Record_Id__c = null;
        request.Status__c = 'Pending';
        request.Parallel_Mode__c = 'All';
        insert request;

        User user1 = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Approval_Task__c task1 = new Approval_Task__c();
        task1.Approval_Request__c = request.Id;
        task1.Assignee__c = user1.Id;
        task1.Task_Status__c = 'Open';
        insert task1;

        Test.startTest();
        task1.Task_Status__c = 'Rejected';
        update task1;

        ApprovalDecisionEvaluator.evaluateTaskOutcome(request.Id);
        Test.stopTest();

        Approval_Request__c evaluatedRequest = [SELECT Status__c, Outcome__c FROM Approval_Request__c WHERE Id = :request.Id];
        Assert.areEqual('Rejected', evaluatedRequest.Status__c, 'Request should be rejected if any task is rejected');
    }
}
