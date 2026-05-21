/**
 * SetupMultiStepApproval.apex
 * ─────────────────────────────────────────────────────────────────────────────
 * Sets up a 3-step Opportunity approval process using Public Groups.
 *
 *   Step 1  │ Rule_Order__c = 1 │ Public Group: Opp Approval - Sales Managers   │ All must approve
 *   Step 2a │ Rule_Order__c = 2 │ Public Group: Opp Approval - Finance Approvers│ Both groups must
 *   Step 2b │ Rule_Order__c = 2 │ Public Group: Opp Approval - Legal Approvers  │ approve (parallel)
 *   Step 3  │ Rule_Order__c = 3 │ Public Group: Opp Approval - VP Sales         │ Final sign-off
 *
 * Trigger criteria (AND):
 *   • Amount > 1000
 *   • StageName changed TO 'Qualification'
 *
 * HOW TO RUN:
 *   sf apex run --file scripts/apex/SetupMultiStepApproval.apex --target-org <alias>
 *
 * AFTER RUNNING:
 *   Add users to each Public Group in Salesforce Setup → Public Groups.
 *   The approval engine resolves the group members at runtime.
 *
 * IDEMPOTENT: safe to re-run; groups are reused if they already exist.
 * ─────────────────────────────────────────────────────────────────────────────
 */

// ── Group definitions ─────────────────────────────────────────────────────────
// Each entry: Label (Name), DeveloperName, purpose comment
List<Map<String, String>> groupDefs = new List<Map<String, String>>{
    new Map<String, String>{
        'name'      => 'Opp Approval - Sales Managers',
        'devName'   => 'Opp_Approval_Sales_Managers',
        'step'      => 'Step 1'
    },
    new Map<String, String>{
        'name'      => 'Opp Approval - Finance Approvers',
        'devName'   => 'Opp_Approval_Finance_Approvers',
        'step'      => 'Step 2a'
    },
    new Map<String, String>{
        'name'      => 'Opp Approval - Legal Approvers',
        'devName'   => 'Opp_Approval_Legal_Approvers',
        'step'      => 'Step 2b'
    },
    new Map<String, String>{
        'name'      => 'Opp Approval - VP Sales',
        'devName'   => 'Opp_Approval_VP_Sales',
        'step'      => 'Step 3'
    }
};

// ── Step 1: Upsert Public Groups ──────────────────────────────────────────────
// Query all existing groups by DeveloperName in one call
Set<String> devNames = new Set<String>();
for (Map<String, String> def : groupDefs) devNames.add(def.get('devName'));

Map<String, Id> groupIdByDevName = new Map<String, Id>();
for (Group g : [
    SELECT Id, DeveloperName
    FROM   Group
    WHERE  DeveloperName IN :devNames
    AND    Type = 'Regular'
]) {
    groupIdByDevName.put(g.DeveloperName, g.Id);
}

// Insert any groups that don't exist yet
List<Group> toInsert = new List<Group>();
for (Map<String, String> def : groupDefs) {
    if (!groupIdByDevName.containsKey(def.get('devName'))) {
        toInsert.add(new Group(
            Name          = def.get('name'),
            DeveloperName = def.get('devName'),
            Type          = 'Regular'
        ));
    }
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    for (Group g : toInsert) groupIdByDevName.put(g.DeveloperName, g.Id);
    System.debug('Created ' + toInsert.size() + ' new Public Group(s).');
} else {
    System.debug('All Public Groups already exist — reusing.');
}

// Named references for rule assignment
Id grpSalesManagers   = groupIdByDevName.get('Opp_Approval_Sales_Managers');
Id grpFinanceApprovers = groupIdByDevName.get('Opp_Approval_Finance_Approvers');
Id grpLegalApprovers  = groupIdByDevName.get('Opp_Approval_Legal_Approvers');
Id grpVPSales         = groupIdByDevName.get('Opp_Approval_VP_Sales');

System.debug('Groups resolved:');
for (Map<String, String> def : groupDefs) {
    System.debug('  ' + def.get('step') + ' → ' + def.get('name')
        + ' (' + groupIdByDevName.get(def.get('devName')) + ')');
}


// ── Step 2: Upsert Approval Process ──────────────────────────────────────────
Approval_Process__c process;
List<Approval_Process__c> existing = [
    SELECT Id, Name
    FROM   Approval_Process__c
    WHERE  Target_Object__c = 'Opportunity'
    AND    Name = 'Opportunity Multi-Step Approval'
    AND    Active__c = true
    LIMIT  1
];

if (!existing.isEmpty()) {
    process = existing[0];
    System.debug('Reusing Approval Process: ' + process.Id);
} else {
    process = new Approval_Process__c(
        Name               = 'Opportunity Multi-Step Approval',
        Target_Object__c   = 'Opportunity',
        Active__c          = true,
        Trigger_Events__c  = 'Update',
        Description__c     = '3-step approval via Public Groups: Sales Mgrs → Finance+Legal → VP.',
        Escalation_Rule__c = 'Escalate after 3 days with no decision'
    );
    insert process;
    System.debug('Created Approval Process: ' + process.Id);
}


// ── Step 3: Recreate Approval Criteria ───────────────────────────────────────
delete [SELECT Id FROM Approval_Criteria__c WHERE Process__c = :process.Id];

insert new List<Approval_Criteria__c>{
    new Approval_Criteria__c(
        Process__c        = process.Id,
        Field_API_Name__c = 'Amount',
        Operator__c       = 'Greater Than',
        Value__c          = '1000',
        Field_Type__c     = 'Number',
        Logic_Group__c    = 1,
        Sort_Order__c     = 1
    ),
    new Approval_Criteria__c(
        Process__c        = process.Id,
        Field_API_Name__c = 'StageName',
        Operator__c       = 'Changed To',
        Value__c          = 'Qualification',
        Field_Type__c     = 'Text',
        Logic_Group__c    = 1,
        Sort_Order__c     = 2
    )
};
System.debug('Approval Criteria created (2 rows, AND logic).');


// ── Step 4: Recreate Approval Rules ──────────────────────────────────────────
delete [SELECT Id FROM Approval_Rule__c WHERE Process__c = :process.Id];

insert new List<Approval_Rule__c>{

    // ── Stage 1: Sales Managers review ───────────────────────────────────────
    new Approval_Rule__c(
        Name              = 'Step 1 – Sales Managers',
        Process__c        = process.Id,
        Approver_Type__c  = 'Public Group',
        Approver_Value__c = 'Opp Approval - Sales Managers',
        Approval_Mode__c  = 'All must approve',
        Parallelity__c    = 'Parallel',
        Rule_Order__c     = 1,
        Days_to_Decision__c = 3
    ),

    // ── Stage 2: Finance Approvers (parallel with Legal) ─────────────────────
    // Both Step 2 rules share Rule_Order__c = 2.
    // The resolver collects members from BOTH groups and creates one task per
    // member. All tasks must be approved before advancing to Stage 3.
    new Approval_Rule__c(
        Name              = 'Step 2a – Finance Approvers',
        Process__c        = process.Id,
        Approver_Type__c  = 'Public Group',
        Approver_Value__c = 'Opp Approval - Finance Approvers',
        Approval_Mode__c  = 'All must approve',
        Parallelity__c    = 'Parallel',
        Rule_Order__c     = 2,
        Days_to_Decision__c = 3
    ),

    // ── Stage 2: Legal Approvers (parallel with Finance) ─────────────────────
    new Approval_Rule__c(
        Name              = 'Step 2b – Legal Approvers',
        Process__c        = process.Id,
        Approver_Type__c  = 'Public Group',
        Approver_Value__c = 'Opp Approval - Legal Approvers',
        Approval_Mode__c  = 'All must approve',
        Parallelity__c    = 'Parallel',
        Rule_Order__c     = 2,
        Days_to_Decision__c = 3
    ),

    // ── Stage 3: VP Sales final sign-off ─────────────────────────────────────
    new Approval_Rule__c(
        Name              = 'Step 3 – VP Sales Final Approval',
        Process__c        = process.Id,
        Approver_Type__c  = 'Public Group',
        Approver_Value__c = 'Opp Approval - VP Sales',
        Approval_Mode__c  = 'All must approve',
        Parallelity__c    = 'Sequential',
        Rule_Order__c     = 3,
        Days_to_Decision__c = 2
    )
};
System.debug('Approval Rules created (4 rules across 3 stages).');


// ── Summary ───────────────────────────────────────────────────────────────────
System.debug('');
System.debug('=== Setup Complete ===');
System.debug('Process Id : ' + process.Id);
System.debug('');
System.debug('NEXT STEP — Add users to each Public Group in Setup → Public Groups:');
System.debug('');
System.debug('  Step 1  │ Opp Approval - Sales Managers   │ ' + grpSalesManagers);
System.debug('  Step 2a │ Opp Approval - Finance Approvers│ ' + grpFinanceApprovers);
System.debug('  Step 2b │ Opp Approval - Legal Approvers  │ ' + grpLegalApprovers);
System.debug('  Step 3  │ Opp Approval - VP Sales         │ ' + grpVPSales);
System.debug('');
System.debug('The approval engine resolves group members at runtime —');
System.debug('no code changes needed when group membership changes.');
