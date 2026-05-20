public with sharing class ApprovalRouteResolver {
    public static List<Id> resolveApproverIds(Approval_Request__c requestRecord) {
        if (requestRecord == null) {
            return new List<Id>();
        }

        List<Approval_Rule__c> rules = [
            SELECT Id, Approver_Type__c, Approver_Value__c
            FROM Approval_Rule__c
            WHERE Process__c = :requestRecord.Process__c
            ORDER BY Rule_Order__c
        ];

        Set<Id> approverIds = new Set<Id>();
        for (Approval_Rule__c rule : rules) {
            if (rule.Approver_Type__c == 'User') {
                approverIds.add((Id)rule.Approver_Value__c);
            } else if (rule.Approver_Type__c == 'Role') {
                approverIds.addAll(getUserIdsByRole(rule.Approver_Value__c));
            } else if (rule.Approver_Type__c == 'Public Group') {
                approverIds.addAll(getUserIdsByGroup(rule.Approver_Value__c));
            }
        }

        return new List<Id>(approverIds);
    }

    private static List<Id> getUserIdsByRole(String roleDeveloperName) {
        List<User> users = [
            SELECT Id FROM User
            WHERE UserRole.DeveloperName = :roleDeveloperName
                AND IsActive = TRUE
        ];
        List<Id> userIds = new List<Id>();
        for (User u : users) {
            userIds.add(u.Id);
        }
        return userIds;
    }

    private static List<Id> getUserIdsByGroup(String groupName) {
        List<CollaborationGroupMember> members = [
            SELECT MemberId FROM CollaborationGroupMember
            WHERE CollaborationGroup.Name = :groupName
        ];
        List<Id> memberIds = new List<Id>();
        for (CollaborationGroupMember m : members) {
            memberIds.add(m.MemberId);
        }
        return memberIds;
    }
}
