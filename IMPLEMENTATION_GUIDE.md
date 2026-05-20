# Advanced Approval Process - Implementation Guide

## Overview
This guide explains how to deploy and configure the custom advanced approval solution built with Apex, Lightning Web Components, and Salesforce DX.

---

## Deployment Steps

### 1. Prerequisites
- Salesforce Org (Developer, Sandbox, or Production)
- Salesforce CLI installed
- VS Code with Salesforce Extension Pack
- Access to force-app directory structure

### 2. Authenticate to Salesforce Org
```bash
sfdx force:auth:web:login -a YourOrgAlias
```

### 3. Deploy Metadata
```bash
sfdx force:source:deploy -p force-app -u YourOrgAlias
```

Or deploy specific components:
```bash
# Deploy custom objects
sfdx force:source:deploy -p force-app/main/default/objects -u YourOrgAlias

# Deploy Apex classes
sfdx force:source:deploy -p force-app/main/default/classes -u YourOrgAlias

# Deploy Lightning Web Components
sfdx force:source:deploy -p force-app/main/default/lwc -u YourOrgAlias
```

### 4. Verify Deployment
Check that all objects and components deployed successfully:
```bash
sfdx force:source:status -u YourOrgAlias
```

---

## Configuration Guide

### Step 1: Create an Approval Process

1. Navigate to **Setup > Approval Processes**
2. Create a new **Approval_Process__c** record:
   - **Process Name**: e.g., "Account Approval"
   - **Target Object**: "Account"
   - **Active**: Checked
   - **Start Condition**: Leave blank or add custom logic
   - **Escalation Rule**: Optional

### Step 2: Define Approval Rules

For each stage in your process, create **Approval_Rule__c** records:

1. Navigate to the **Approval Process** record created above
2. In the **Approval Rules** related list, click **New**
3. Fill in the following:
   - **Rule Name**: e.g., "Manager Approval"
   - **Rule Order**: 1 (for first stage)
   - **Approver Type**: Select "User", "Role", or "Public Group"
   - **Approver Value**: Enter the ID, role name, or group name
   - **Parallelity**: "Parallel" or "Sequential"
   - **Approval Mode**: "All must approve", "Any can approve", or "Majority"
   - **Condition Formula**: Optional formula to filter when rule applies

**Example Setup**:
- Rule 1: Manager (Role) - Parallel, All must approve
- Rule 2: Director (Role) - Sequential after Rule 1

### Step 3: Add Records to Approval Process

#### Using Lightning Component
1. Add the **advancedApprovalRequest** LWC to your record page layout
2. Open a record (e.g., Account)
3. Click **Start Approval** to submit for approval

#### Using Flow
1. Create a Record-Triggered Flow on your target object
2. Add an "Apex Action" that calls **SubmitForApprovalAction**
3. Pass parameters:
   - **targetRecordId**: {!$Record.Id}
   - **processId**: {!$Record.Approval_Process_Id_Field} (if you add a lookup field)
   - **parallelMode**: "All"

#### Using Apex
```apex
SubmitForApprovalAction.ApprovalRequest req = new SubmitForApprovalAction.ApprovalRequest();
req.targetRecordId = '0015700000IZ3Z';
req.processId = 'a065700000UAO1';
req.parallelMode = 'All';

List<SubmitForApprovalAction.ApprovalResult> results = SubmitForApprovalAction.submitForApproval(
    new List<SubmitForApprovalAction.ApprovalRequest> { req }
);
```

### Step 4: Configure Escalation (Optional)

1. Schedule the **ApprovalEscalationScheduler** in Setup:
   - Navigate to **Setup > Schedule Apex Jobs**
   - Create a scheduled job to run daily or hourly
   - Call: `ApprovalEscalationScheduler`

```apex
// Schedule in Apex
System.schedule('Approval Escalation', '0 0 * * * ?', new ApprovalEscalationScheduler());
```

---

## Usage - Approver Actions

### For Approvers
Once approval tasks are assigned, approvers can:

1. **View Tasks**: See all pending approval tasks assigned to them
2. **Use Lightning Component**: 
   - Add **approvalTaskAction** LWC to their task management page
   - Click **Approve** or **Reject**
3. **Add Comments**: Include decision notes or feedback

### Approval Task Statuses
- **Open**: Awaiting approver action
- **Approved**: Approved by the assigned user
- **Rejected**: Rejected by the assigned user
- **Delegated**: Reassigned to another user
- **Escalated**: Overdue and escalated by system

---

## Monitoring & Reporting

### Approval Request Status
- **Pending**: Waiting for approvals
- **Approved**: All approvals completed successfully
- **Rejected**: One or more approvals rejected
- **Escalated**: Overdue and escalated
- **Cancelled**: Cancelled by submitter or admin

### Approval Outcome Values
- **Approved**: Final approval outcome
- **Rejected**: Final rejection outcome
- **Pending**: Still in progress

### Audit Trail
All decisions are logged in **Approval_History__c**:
- User actions (submitted, approved, rejected)
- Status changes
- Escalations
- Delegations
- Comments and decisions

View history for any approval request via the **Approval History** related list.

---

## Key Apex Classes & Methods

### ApprovalRequestService
```apex
// Create a new approval request
ApprovalRequestService.createApprovalRequest(targetRecordId, processId, userId);

// Get pending requests for records
ApprovalRequestService.getPendingRequests(List<Id> targetIds);
```

### ApprovalTaskService
```apex
// Approve a task
ApprovalTaskService.approveTask(taskId, comments);

// Reject a task
ApprovalTaskService.rejectTask(taskId, comments);

// Create initial approval tasks
ApprovalTaskService.createInitialTasks(approvalRequest);
```

### ApprovalDecisionEvaluator
```apex
// Evaluate task outcome and update request status
ApprovalDecisionEvaluator.evaluateTaskOutcome(approvalRequestId);
```

### ApprovalRouteResolver
```apex
// Resolve approver IDs from rules
ApprovalRouteResolver.resolveApproverIds(approvalRequest);
```

### SubmitForApprovalAction (Flow-Enabled)
```apex
// Invocable Apex action for Flows
List<ApprovalResult> results = SubmitForApprovalAction.submitForApproval(
    List<ApprovalRequest> requests
);
```

---

## Lightning Web Components

### advancedApprovalRequest
**Purpose**: Display approval request status and start new requests  
**Properties**:
- `recordId`: The target record ID

**Usage in Page Layout**:
```xml
<lightning:recordPage>
    <c:advancedApprovalRequest recordId="{!recordId}"></c:advancedApprovalRequest>
</lightning:recordPage>
```

### approvalTaskAction
**Purpose**: Allow approvers to approve/reject tasks  
**Properties**:
- `taskId`: The approval task ID

---

## Custom Fields to Add (Optional Enhancements)

If your records need approval metadata:

### On Target Object (e.g., Account)
- **Approval_Process__c** (Lookup to Approval_Process__c): Select the approval process
- **Status_Before_Approval__c** (Text): Store original status
- **Requires_Approval__c** (Checkbox): Flag records requiring approval

---

## Testing

### Run Unit Tests
```bash
sfdx force:apex:test:run -u YourOrgAlias -c -r human
```

### Test Classes Included
- `ApprovalRequestServiceTest`
- `ApprovalDecisionEvaluatorTest`
- Tests cover parallel/sequential/majority approval scenarios

### Coverage
Aim for >80% code coverage before deploying to Production:
```bash
sfdx force:apex:test:run -u YourOrgAlias -c -r json > test-results.json
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Approval tasks not created | Verify `Approval_Rule__c` records exist and point to valid approvers |
| Request status not updating | Check `ApprovalDecisionEvaluator` logs; ensure tasks are completed |
| Escalation not working | Verify scheduled job is active; check job logs in Monitoring |
| Flow action fails | Validate `processId` and `targetRecordId` are correct IDs |

---

## Security Best Practices

1. **Sharing Rules**: Approval records are controlled by parent; ensure proper sharing setup
2. **Permission Sets**: Create permission sets for approvers with access to approval objects
3. **Field-Level Security**: Restrict sensitive approval fields by role
4. **Audit Logging**: Use `Approval_History__c` for compliance and audits

---

## Extension Ideas

1. **Email Approvals**: Add email-based decision actions (approve/reject via email)
2. **Time-Based Escalation**: Automatically escalate overdue tasks to managers
3. **Approval Matrix**: Use `Approval_Matrix__mdt` for dynamic matrix-based approvals
4. **Notifications**: Send platform notifications when tasks are assigned
5. **Mobile Support**: Extend LWC components for mobile approval actions
6. **AI Suggestions**: Suggest most appropriate approvers using Apex actions

---

## Summary

This advanced approval solution provides flexibility beyond Salesforce's standard approval process. Deploy it incrementally, test thoroughly, and extend based on business needs.

For additional support, refer to the solution design document and code comments within each class.
