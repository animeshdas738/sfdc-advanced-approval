# Advanced Approval Process - Quick Reference

## Core Objects

| Object | Purpose | Key Fields |
|--------|---------|-----------|
| `Approval_Request__c` | Approval instance | Status, Outcome, Target_Record_Id, Parallel_Mode |
| `Approval_Task__c` | Work item for approver | Task_Status, Decision, Comments, Escalation_Date |
| `Approval_Process__c` | Process configuration | Target_Object, Active, Start_Condition |
| `Approval_Rule__c` | Routing rule | Approver_Type, Approver_Value, Rule_Order |
| `Approval_History__c` | Audit trail | Action, Actor, Previous_State, New_State |

---

## Common Code Snippets

### Submit for Approval (Apex)
```apex
ApprovalRequestService.ApprovalRequestResult result = 
    ApprovalRequestService.createApprovalRequest(
        accountId, 
        processId, 
        UserInfo.getUserId()
    );
```

### Submit for Approval (Flow)
- Use **Apex Action**: `SubmitForApprovalAction`
- Input:
  - `targetRecordId`: Record ID to approve
  - `processId`: Approval_Process__c ID
  - `parallelMode`: "All", "Any", or "Majority"
- Output: `approvalRequestId`

### Approve Task (Apex)
```apex
ApprovalTaskService.approveTask(taskId, 'Looks good!');
```

### Reject Task (Apex)
```apex
ApprovalTaskService.rejectTask(taskId, 'Needs revision');
```

### Get Pending Approvals
```apex
List<Approval_Request__c> pending = 
    ApprovalRequestService.getPendingRequests(
        new List<Id> { recordId }
    );
```

### Create History Entry
```apex
ApprovalHistoryLogger.logAction(
    approvalRequestId, 
    'Status Change', 
    'Pending', 
    'Approved', 
    'Approved by manager'
);
```

---

## SOQL Queries

### All Pending Requests for a Record
```sql
SELECT Id, Status__c, Outcome__c, Process__c, Parallel_Mode__c 
FROM Approval_Request__c 
WHERE Target_Record_Id__c = 'YOUR_RECORD_ID' 
  AND Status__c = 'Pending'
```

### All Open Tasks
```sql
SELECT Id, Assignee__c, Approval_Request__c, Task_Status__c, Escalation_Date__c 
FROM Approval_Task__c 
WHERE Task_Status__c = 'Open'
ORDER BY Escalation_Date__c ASC
```

### Tasks for a Specific User
```sql
SELECT Id, Approval_Request__c, Task_Status__c, Comments__c, Decision_Date__c 
FROM Approval_Task__c 
WHERE Assignee__c = :userId 
  AND Task_Status__c = 'Open'
```

### Escalated Tasks
```sql
SELECT Id, Assignee__c, Task_Status__c, Escalation_Date__c 
FROM Approval_Task__c 
WHERE Task_Status__c = 'Escalated'
  AND Escalation_Date__c <= :System.now()
```

### Approval History for a Request
```sql
SELECT Id, Action__c, Actor__c, Previous_State__c, New_State__c, Activity_Date__c, Comments__c 
FROM Approval_History__c 
WHERE Approval_Request__c = 'REQUEST_ID' 
ORDER BY Activity_Date__c DESC
```

---

## Parallel Mode Comparison

| Mode | Behavior | Use Case |
|------|----------|----------|
| **All** | All approvers must approve | Finance, Compliance approvals |
| **Any** | Any single approval succeeds | Quick decision escalations |
| **Majority** | >50% approvers must approve | Consensus-based approvals |

---

## Approval Outcome Calculations

### All Mode
- **Approved**: All tasks approved
- **Rejected**: Any task rejected

### Any Mode
- **Approved**: At least one task approved
- **Rejected**: All tasks rejected

### Majority Mode
- **Approved**: Total approvals > 50% of tasks
- **Rejected**: Total rejections > 50% of tasks

---

## Lightning Component Integration

### Add Component to Record Page
1. Open record layout in Setup
2. Drag **Advanced Approval Request** component to page
3. Configure property: `recordId` → `{!recordId}`

### Add Component to App Page
1. Edit App Page in Lightning App Builder
2. Add **Advanced Approval Request** component
3. Set `recordId` via page property or hardcode

---

## Test Data Setup

### Create Test Approval Process
```apex
Approval_Process__c proc = new Approval_Process__c();
proc.Name = 'Test Approval';
proc.Target_Object__c = 'Account';
proc.Active__c = true;
insert proc;

Approval_Rule__c rule = new Approval_Rule__c();
rule.Process__c = proc.Id;
rule.Rule_Order__c = 1;
rule.Approver_Type__c = 'User';
rule.Approver_Value__c = UserInfo.getUserId();
rule.Parallelity__c = 'Parallel';
rule.Approval_Mode__c = 'All must approve';
insert rule;
```

### Create Test Approval Request
```apex
Approval_Request__c req = new Approval_Request__c();
req.Target_Record_Id__c = account.Id;
req.Process__c = proc.Id;
req.Status__c = 'Pending';
req.Parallel_Mode__c = 'All';
req.Requested_By__c = UserInfo.getUserId();
req.Requested_Date__c = System.now();
insert req;

ApprovalTaskService.createInitialTasks(req);
```

---

## Error Handling

### Common Error Scenarios

**No approval process found**
- Verify `Approval_Process__c` exists and `Active__c = true`

**Tasks not created**
- Check `Approval_Rule__c` records exist
- Verify approver references are valid

**Outcome not evaluating**
- Ensure `Parallel_Mode__c` is set on request
- Verify task statuses are updated

---

## Troubleshooting Checklist

- [ ] Is the Approval Process active?
- [ ] Are Approval Rules defined with correct order?
- [ ] Are approvers (Users/Roles) valid?
- [ ] Was the Approval Request created with correct data?
- [ ] Are Approval Tasks created for the request?
- [ ] Is Parallel Mode configured correctly?
- [ ] Have all required tasks been decided?

---

## Performance Tips

1. **Bulk Operations**: Use batch processing for large approval loads
2. **Indexes**: Add custom indexes on frequently queried fields
3. **Caching**: Use platform cache for approver lists
4. **Async Processing**: Use batch or future methods for evaluations
5. **Pagination**: Implement pagination in LWC for large task lists

---

## Useful Admin Tasks

### Monitor Approval Status
```apex
// Dashboard query
SELECT Status__c, COUNT() cnt 
FROM Approval_Request__c 
GROUP BY Status__c
```

### Find Escalated Tasks
```apex
SELECT Id, Assignee__c, Escalation_Date__c 
FROM Approval_Task__c 
WHERE Task_Status__c = 'Escalated'
```

### Generate Approval Report
```apex
SELECT Approval_Request__c, COUNT() task_count, 
       MAX(Decision_Date__c) recent_decision 
FROM Approval_Task__c 
GROUP BY Approval_Request__c
```

---

## Known Limits

- **Task Limit**: Monitor Governor Limits for bulk task creation
- **Query Limit**: Each approval evaluation runs queries; batch appropriately
- **History Size**: Audit trail grows with each action; periodically archive

---

## Support & Docs

- **Solution Design**: See `Advanced_Approval_Solution_Design.md`
- **Full Guide**: See `IMPLEMENTATION_GUIDE.md`
- **Salesforce Docs**: https://developer.salesforce.com/
