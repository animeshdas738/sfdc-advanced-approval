global class ApprovalEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Approval_Task__c> overdueTasks = [
            SELECT Id, Approval_Request__c, Assignee__c, Task_Status__c, Escalation_Date__c
            FROM Approval_Task__c
            WHERE Task_Status__c = 'Open'
                AND Escalation_Date__c <= :System.now()
        ];

        if (overdueTasks.isEmpty()) {
            return;
        }

        List<Approval_Task__c> updates = new List<Approval_Task__c>();
        for (Approval_Task__c task : overdueTasks) {
            task.Task_Status__c = 'Escalated';
            updates.add(task);
        }

        update updates;
        // Additional notification or escalation logic can be added here.
    }
}
