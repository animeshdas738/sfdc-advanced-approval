/**
 * SetupOpportunityApproval.apex
 * ─────────────────────────────────────────────────────────────────────────────
 * Anonymous Apex: seeds the Approval_Process__c, Approval_Criteria__c, and
 * Approval_Rule__c records needed by the generic OpportunityApproval trigger.
 *
 * HOW TO RUN:
 *   sf apex run --file scripts/apex/SetupOpportunityApproval.apex --target-org <alias>
 *
 * CRITERIA CONFIGURED:
 *   Group 1 (AND):  Amount > 1000
 *                   StageName Changed To "Qualification"
 *   → The trigger fires only when BOTH conditions are true simultaneously.
 *
 * APPROVER:
 *   Rule 1 — Role-based. Change 'Manager' to your org's Role DeveloperName.
 *   Add more Approval_Rule__c records for multi-stage / parallel approvals.
 *
 * IDEMPOTENT: safe to re-run; deletes and recreates criteria and rules each time.
 * ─────────────────────────────────────────────────────────────────────────────
 */

// ── Step 1: Upsert the Approval Process ──────────────────────────────────────
Approval_Process__c oppProcess;
List<Approval_Process__c> existing = [
    SELECT Id, Name
    FROM   Approval_Process__c
    WHERE  Target_Object__c = 'Opportunity'
    AND    Active__c = true
    LIMIT  1
];

if (!existing.isEmpty()) {
    oppProcess = existing[0];
    System.debug('Reusing Approval Process: ' + oppProcess.Id + ' – ' + oppProcess.Name);
} else {
    oppProcess = new Approval_Process__c(
        Name              = 'Opportunity Qualification Approval',
        Target_Object__c  = 'Opportunity',
        Active__c         = true,
        Trigger_Events__c = 'Update',
        Description__c    = 'Approval required when Opportunity Amount > 1000 moves to Qualification.',
        Escalation_Rule__c = 'Escalate after 3 days with no decision'
    );
    insert oppProcess;
    System.debug('Created Approval Process: ' + oppProcess.Id);
}

// ── Step 2: Recreate Approval Criteria ───────────────────────────────────────
// Delete existing criteria for this process (idempotent reset)
delete [SELECT Id FROM Approval_Criteria__c WHERE Process__c = :oppProcess.Id];

List<Approval_Criteria__c> criteria = new List<Approval_Criteria__c>{

    // Criterion 1 — Amount must be greater than 1000
    new Approval_Criteria__c(
        Process__c       = oppProcess.Id,
        Field_API_Name__c = 'Amount',
        Operator__c      = 'Greater Than',
        Value__c         = '1000',
        Field_Type__c    = 'Number',
        Logic_Group__c   = 1,
        Sort_Order__c    = 1
    ),

    // Criterion 2 — Stage must have just changed TO Qualification
    new Approval_Criteria__c(
        Process__c        = oppProcess.Id,
        Field_API_Name__c = 'StageName',
        Operator__c       = 'Changed To',
        Value__c          = 'Qualification',
        Field_Type__c     = 'Text',
        Logic_Group__c    = 1,
        Sort_Order__c     = 2
    )

    // Example: add a second group (OR condition) — uncomment to use
    // new Approval_Criteria__c(
    //     Process__c        = oppProcess.Id,
    //     Field_API_Name__c = 'Amount',
    //     Operator__c       = 'Greater Than',
    //     Value__c          = '50000',
    //     Field_Type__c     = 'Number',
    //     Logic_Group__c    = 2,   // ← different group = OR with Group 1
    //     Sort_Order__c     = 1
    // )
};
insert criteria;
System.debug('Inserted ' + criteria.size() + ' Approval Criteria.');

// ── Step 3: Recreate Approval Rules (approver routing) ───────────────────────
delete [SELECT Id FROM Approval_Rule__c WHERE Process__c = :oppProcess.Id];

List<Approval_Rule__c> rules = new List<Approval_Rule__c>{

    // Rule 1 — Manager review (change 'Manager' to your Role DeveloperName)
    new Approval_Rule__c(
        Name               = 'Opp Qualification – Manager Review',
        Process__c         = oppProcess.Id,
        Approver_Type__c   = 'Role',
        Approver_Value__c  = 'Manager',     // ← replace with actual Role DeveloperName
        Approval_Mode__c   = 'All must approve',
        Parallelity__c     = 'Sequential',
        Rule_Order__c      = 1,
        Days_to_Decision__c = 3
    )

    // Uncomment for a second approver stage
    // new Approval_Rule__c(
    //     Name               = 'Opp Qualification – VP Sign-off',
    //     Process__c         = oppProcess.Id,
    //     Approver_Type__c   = 'Role',
    //     Approver_Value__c  = 'VP_Sales',
    //     Approval_Mode__c   = 'All',
    //     Parallelity__c     = 'Sequential',
    //     Rule_Order__c      = 2,
    //     Days_to_Decision__c = 2
    // )
};
insert rules;
System.debug('Inserted ' + rules.size() + ' Approval Rule(s).');

// ── Summary ───────────────────────────────────────────────────────────────────
System.debug('');
System.debug('=== Setup Complete ===');
System.debug('Approval_Process__c Id : ' + oppProcess.Id);
System.debug('Criteria count         : ' + criteria.size());
System.debug('Rules count            : ' + rules.size());
System.debug('');
System.debug('The generic OpportunityApproval trigger will now evaluate these');
System.debug('criteria automatically on every Opportunity after insert/update.');
