/**
 * ApprovalProcessEvaluator
 * ──────────────────────────────────────────────────────────────────────────────
 * Generic trigger handler called by every object's thin trigger.
 * For each active Approval_Process__c configured for the object:
 *   1. Checks Trigger_Events__c (Create / Update / Create and Update)
 *   2. Re-queries records if cross-object fields are needed by criteria
 *   3. Delegates evaluation to ApprovalCriteriaEvaluator
 *   4. Skips records that already have a Pending request for this process
 *   5. Submits qualifying records via SubmitForApprovalAction
 *
 * To add a new object to the approval system, create one thin trigger:
 *   trigger MyObjectApproval on MyObject__c (after insert, after update) {
 *       ApprovalProcessEvaluator.evaluate(Trigger.new, Trigger.oldMap, 'MyObject__c');
 *   }
 * Then configure Approval_Process__c + Approval_Criteria__c records — no code changes needed.
 */
public with sharing class ApprovalProcessEvaluator {

    public static void evaluate(
        List<SObject> newRecords,
        Map<Id, SObject> oldMap,
        String objectApiName
    ) {
        // Load all active processes + their criteria in one query
        List<Approval_Process__c> processes = [
            SELECT Id, Trigger_Events__c,
                (SELECT Id, Field_API_Name__c, Operator__c, Value__c,
                        Field_Type__c, Logic_Group__c, Sort_Order__c
                 FROM   Approval_Criteria__r
                 ORDER BY Logic_Group__c ASC NULLS LAST, Sort_Order__c ASC NULLS LAST)
            FROM Approval_Process__c
            WHERE Target_Object__c = :objectApiName
            AND   Active__c = true
        ];

        if (processes.isEmpty()) return;

        Boolean isInsert = (oldMap == null || oldMap.isEmpty());

        // Re-query records once to hydrate any cross-object fields required by criteria
        Map<Id, SObject> enriched = enrichRecords(newRecords, processes, objectApiName);

        for (Approval_Process__c process : processes) {

            // ── 1. Event gate ─────────────────────────────────────────────────
            String evt = process.Trigger_Events__c;
            if (evt == 'Create' && !isInsert) continue;
            if (evt == 'Update' &&  isInsert) continue;

            List<Approval_Criteria__c> criteria = process.Approval_Criteria__r;

            // ── 2. Evaluate each record against criteria ──────────────────────
            List<Id> qualifiedIds = new List<Id>();
            for (SObject newRec : newRecords) {
                Id recId     = (Id) newRec.get('Id');
                SObject rec  = enriched.containsKey(recId) ? enriched.get(recId) : newRec;
                SObject prev = (oldMap != null) ? oldMap.get(recId) : null;

                if (ApprovalCriteriaEvaluator.evaluate(rec, prev, criteria)) {
                    qualifiedIds.add(recId);
                }
            }

            if (qualifiedIds.isEmpty()) continue;

            // ── 3. Dedup — skip records with an active pending request ────────
            Set<Id> alreadyPending = new Set<Id>();
            for (Approval_Request__c ar : [
                SELECT Target_Record_Id__c
                FROM   Approval_Request__c
                WHERE  Process__c          = :process.Id
                AND    Target_Record_Id__c IN :qualifiedIds
                AND    Status__c           = 'Pending'
            ]) {
                alreadyPending.add(ar.Target_Record_Id__c);
            }

            // ── 4. Build and submit ───────────────────────────────────────────
            List<SubmitForApprovalAction.ApprovalRequest> requests =
                new List<SubmitForApprovalAction.ApprovalRequest>();

            for (Id recId : qualifiedIds) {
                if (alreadyPending.contains(recId)) continue;
                SubmitForApprovalAction.ApprovalRequest req =
                    new SubmitForApprovalAction.ApprovalRequest();
                req.targetRecordId = String.valueOf(recId);
                req.processId      = String.valueOf(process.Id);
                req.parallelMode   = 'All';
                requests.add(req);
            }

            if (!requests.isEmpty()) {
                SubmitForApprovalAction.submitForApproval(requests);
            }
        }
    }

    // ── Private: re-query to populate cross-object (dot-notation) fields ──────

    private static Map<Id, SObject> enrichRecords(
        List<SObject> records,
        List<Approval_Process__c> processes,
        String objectApiName
    ) {
        // Collect every cross-object field path used across all criteria
        Set<String> crossObjectPaths = new Set<String>();
        for (Approval_Process__c p : processes) {
            for (Approval_Criteria__c c : p.Approval_Criteria__r) {
                if (c.Field_API_Name__c != null && c.Field_API_Name__c.contains('.')) {
                    crossObjectPaths.add(c.Field_API_Name__c); // e.g. Account.Industry
                }
            }
        }

        if (crossObjectPaths.isEmpty()) return new Map<Id, SObject>();

        List<Id> recIds = new List<Id>();
        for (SObject r : records) recIds.add((Id) r.get('Id'));

        // Build SELECT with Id + all cross-object paths
        Set<String> selectFields = new Set<String>{ 'Id' };
        selectFields.addAll(crossObjectPaths);

        try {
            String soql = 'SELECT ' + String.join(new List<String>(selectFields), ', ')
                        + ' FROM ' + objectApiName
                        + ' WHERE Id IN :recIds';
            Map<Id, SObject> result = new Map<Id, SObject>();
            for (SObject r : Database.query(soql)) {
                result.put((Id) r.get('Id'), r);
            }
            return result;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'ApprovalProcessEvaluator.enrichRecords failed: ' + ex.getMessage());
            return new Map<Id, SObject>();
        }
    }
}
