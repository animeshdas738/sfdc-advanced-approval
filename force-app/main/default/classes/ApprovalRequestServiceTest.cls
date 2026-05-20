@isTest
public class ApprovalRequestServiceTest {
    @TestSetup
    static void setup() {
        // Create approval process
        Approval_Process__c process = new Approval_Process__c();
        process.Name = 'Test Approval Process';
        process.Target_Object__c = 'Account';
        process.Active__c = true;
        insert process;

        // Create approval rule
        Approval_Rule__c rule = new Approval_Rule__c();
        rule.Process__c = process.Id;
        rule.Rule_Order__c = 1;
        rule.Approver_Type__c = 'User';
        rule.Approver_Value__c = UserInfo.getUserId();
        rule.Parallelity__c = 'Parallel';
        rule.Approval_Mode__c = 'All must approve';
        insert rule;
    }

    @isTest
    static void testCreateApprovalRequest() {
        Approval_Process__c process = [SELECT Id FROM Approval_Process__c LIMIT 1];
        Account account = new Account();
        account.Name = 'Test Account';
        insert account;

        Test.startTest();
        ApprovalRequestService.ApprovalRequestResult result = ApprovalRequestService.createApprovalRequest(
            account.Id,
            process.Id,
            UserInfo.getUserId()
        );
        Test.stopTest();

        Assert.isTrue(result.success, 'Approval request creation should succeed');
        Assert.isNotNull(result.approvalRequestId, 'Approval request ID should be populated');

        Approval_Request__c createdRequest = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :result.approvalRequestId];
        Assert.areEqual('Pending', createdRequest.Status__c, 'Status should be Pending');
    }

    @isTest
    static void testGetPendingRequests() {
        Approval_Process__c process = [SELECT Id FROM Approval_Process__c LIMIT 1];
        Account account = new Account();
        account.Name = 'Test Account';
        insert account;

        ApprovalRequestService.createApprovalRequest(account.Id, process.Id, UserInfo.getUserId());

        Test.startTest();
        List<Approval_Request__c> requests = ApprovalRequestService.getPendingRequests(new List<Id>{ account.Id });
        Test.stopTest();

        Assert.areEqual(1, requests.size(), 'Should return one pending request');
        Assert.areEqual(account.Id, requests[0].Target_Record_Id__c, 'Request target should match account ID');
    }
}
