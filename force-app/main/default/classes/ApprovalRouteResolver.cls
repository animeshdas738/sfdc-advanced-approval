public with sharing class ApprovalRouteResolver {

    /**
     * Resolves the set of approver User IDs for a specific stage number.
     * Rules sharing the same Rule_Order__c value belong to the same stage
     * and are treated as parallel approvers within that stage.
     */
    public static List<Id> resolveApproverIds(Approval_Request__c requestRecord, Integer stage) {
        if (requestRecord == null) return new List<Id>();

        List<Approval_Rule__c> rules = [
            SELECT Id, Approver_Type__c, Approver_Value__c
            FROM   Approval_Rule__c
            WHERE  Process__c    = :requestRecord.Process__c
            AND    Rule_Order__c = :stage
        ];

        Set<Id> approverIds = new Set<Id>();
        for (Approval_Rule__c rule : rules) {
            if (rule.Approver_Type__c == 'User') {
                approverIds.add((Id) rule.Approver_Value__c);
            } else if (rule.Approver_Type__c == 'Role') {
                approverIds.addAll(getUserIdsByRole(rule.Approver_Value__c));
            } else if (rule.Approver_Type__c == 'Public Group') {
                approverIds.addAll(getUserIdsByGroup(rule.Approver_Value__c));
            }
        }
        return new List<Id>(approverIds);
    }

    /** Returns the lowest Rule_Order__c value (the first stage) for a process. */
    public static Integer getFirstStage(Id processId) {
        AggregateResult[] results = [
            SELECT MIN(Rule_Order__c) minStage
            FROM   Approval_Rule__c
            WHERE  Process__c = :processId
        ];
        if (results.isEmpty() || results[0].get('minStage') == null) return 1;
        return ((Decimal) results[0].get('minStage')).intValue();
    }

    /**
     * Returns the next stage number after currentStage, or null if no further
     * stages exist (i.e. the current stage is the final one).
     */
    public static Integer getNextStage(Id processId, Integer currentStage) {
        List<Approval_Rule__c> next = [
            SELECT Rule_Order__c
            FROM   Approval_Rule__c
            WHERE  Process__c    = :processId
            AND    Rule_Order__c > :currentStage
            ORDER BY Rule_Order__c ASC
            LIMIT 1
        ];
        if (next.isEmpty()) return null;
        return next[0].Rule_Order__c.intValue();
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static List<Id> getUserIdsByRole(String roleDeveloperName) {
        List<Id> ids = new List<Id>();
        for (User u : [
            SELECT Id FROM User
            WHERE  UserRole.DeveloperName = :roleDeveloperName
            AND    IsActive = true
        ]) ids.add(u.Id);
        return ids;
    }

    private static List<Id> getUserIdsByGroup(String groupName) {
        List<Id> ids = new List<Id>();
        for (CollaborationGroupMember m : [
            SELECT MemberId FROM CollaborationGroupMember
            WHERE  CollaborationGroup.Name = :groupName
        ]) ids.add(m.MemberId);
        return ids;
    }
}
