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
            // Deserialize records - handle the JSON deserialization properly
            List<SObject> records = deserializeRecords(job.SerializedRecord__c);
            
            // Skip processing if no records (empty list should complete successfully)
            if (records.isEmpty()) {
                job.Status__c = 'Completed';
                update job;
                return;
            }
            
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

            // Check if there were any failed records after processing
            List<SObject> failedRecords = processor.getFailedRecords();
            if (failedRecords != null && !failedRecords.isEmpty()) {
                job.Status__c = 'Failed';
            } else {
                job.Status__c = 'Completed';
            }
        } catch (Exception ex) {
            job.Status__c = 'Failed';
        }

        update job;
    }
    
    /**
     * Helper method to properly deserialize SObject records from JSON
     * Handles the conversion from JSON to SObject instances
     */
    private List<SObject> deserializeRecords(String serializedRecords) {
        List<SObject> records = new List<SObject>();
        
        // Deserialize to generic objects first
        List<Object> rawObjects = (List<Object>) JSON.deserializeUntyped(serializedRecords);
        
        if (rawObjects.isEmpty()) {
            return records;
        }
        
        // Convert each object back to SObject
        for (Object rawObj : rawObjects) {
            Map<String, Object> recordMap = (Map<String, Object>) rawObj;
            
            // Extract the SObject type from the attributes
            Map<String, Object> attributes = (Map<String, Object>) recordMap.get('attributes');
            String objectType = (String) attributes.get('type');
            
            // Create a new SObject instance
            SObject record = Schema.getGlobalDescribe().get(objectType).newSObject();
            
            // Populate the fields
            for (String fieldName : recordMap.keySet()) {
                if (fieldName != 'attributes') {
                    Object fieldValue = recordMap.get(fieldName);
                    record.put(fieldName, fieldValue);
                }
            }
            
            records.add(record);
        }
        
        return records;
    }
}