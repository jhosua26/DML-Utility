public class DmlScheduledRetryHandler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        List<DmlRetryJob__c> jobs = [
            SELECT Id, SerializedRecord__c, Operation__c, ExternalIdField__c,
                   RetryLeft__c, Attempt__c, IsAsync__c, IsLightweight__c
            FROM DmlRetryJob__c
            WHERE Status__c = 'Pending'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (jobs.isEmpty()) return;

        DmlRetryJob__c job = jobs[0];

        try {
            List<SObject> records = (List<SObject>) JSON.deserializeUntyped(job.SerializedRecord__c);
            
            // Convert operation string to enum
            DmlOperationExecutor.Operation op = DmlOperationExecutor.Operation.valueOf(job.Operation__c);

            DmlProcessor processor = new DmlProcessor()
                .setRecords(records)
                .setOperation(op)
                .setExternalId(job.ExternalIdField__c)
                .withMaxRetry((Integer)(job.RetryLeft__c + job.Attempt__c))
                .setAttempt((Integer) job.Attempt__c);

            if (job.IsAsync__c) processor.runAsync();
            if (job.IsLightweight__c) processor.enableLightweightMode();

            processor.runNow();

            job.Status__c = 'Completed';
        } catch (Exception ex) {
            job.Status__c = 'Failed';
        }

        update job;
    }
}