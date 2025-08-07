public class DmlScheduledRetryHandler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        List<DmlRetryJob__c> jobs = [
            SELECT Id, SerializedRecord__c, Operation__c, ExternalIdField__c,
                   RetryLeft__c, Attempt__c, IsAsync__c, IsLightweight__c, SObjectType__c
            FROM DmlRetryJob__c
            WHERE Status__c = 'Pending'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (jobs.isEmpty()) return;

        DmlRetryJob__c job = jobs[0];

        try {
            // Fix: Use type-safe deserialization instead of unsafe casting
            List<SObject> records = deserializeRecords(job.SerializedRecord__c, job.SObjectType__c);

            // Handle empty records - complete successfully without processing
            if (records.isEmpty()) {
                job.Status__c = 'Completed';
                job.ErrorMessage__c = null;
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

            job.Status__c = 'Completed';
            job.ErrorMessage__c = null; // Clear any previous error
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'DmlScheduledRetryHandler failed for job ' + job.Id + ': ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + ex.getStackTraceString());
            
            job.Status__c = 'Failed';
            job.ErrorMessage__c = ex.getMessage();
            job.ErrorStackTrace__c = ex.getStackTraceString();
            
            // If retries are left, reschedule the job
            if (job.RetryLeft__c > 0) {
                scheduleRetryJob(job, ex);
            }
        }

        update job;
    }
    
    /**
     * Safely deserialize records with proper type handling
     */
    private List<SObject> deserializeRecords(String serializedRecords, String sObjectType) {
        if (String.isBlank(serializedRecords) || String.isBlank(sObjectType)) {
            throw new IllegalArgumentException('SerializedRecord and SObjectType cannot be blank');
        }
        
        try {
            // Use type-safe deserialization
            Type listType = Type.forName('List<' + sObjectType + '>');
            List<SObject> records = (List<SObject>) JSON.deserialize(serializedRecords, listType);
            
            if (records == null) {
                throw new IllegalArgumentException('Deserialized records cannot be null');
            }
            
            // Empty records are allowed - they should complete successfully without processing
            if (records.isEmpty()) {
                return records;
            }
            
            return records;
        } catch (Exception ex) {
            throw new IllegalArgumentException('Failed to deserialize records: ' + ex.getMessage(), ex);
        }
    }
    
    /**
     * Schedule a retry for a failed job
     */
    private void scheduleRetryJob(DmlRetryJob__c failedJob, Exception originalException) {
        try {
            // Calculate retry delay with exponential backoff
            Integer delaySeconds = calculateRetryDelay((Integer)failedJob.Attempt__c);
            Datetime runTime = Datetime.now().addSeconds(delaySeconds);
            String cron = getCronExpression(runTime);
            
            // Create new retry job with decremented retry count
            DmlRetryJob__c retryJob = new DmlRetryJob__c(
                SerializedRecord__c = failedJob.SerializedRecord__c,
                Operation__c = failedJob.Operation__c,
                ExternalIdField__c = failedJob.ExternalIdField__c,
                SObjectType__c = failedJob.SObjectType__c,
                RetryLeft__c = failedJob.RetryLeft__c - 1,
                Attempt__c = failedJob.Attempt__c + 1,
                IsAsync__c = failedJob.IsAsync__c,
                IsLightweight__c = failedJob.IsLightweight__c,
                Status__c = 'Pending',
                ErrorMessage__c = 'Retry of job ' + failedJob.Id + ': ' + originalException.getMessage()
            );
            insert retryJob;
            
            // Schedule the retry
            System.schedule('RetryJob_' + retryJob.Id, cron, new DmlScheduledRetryHandler());
            
            System.debug(LoggingLevel.INFO, 'Scheduled retry job ' + retryJob.Id + ' for failed job ' + failedJob.Id);
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to schedule retry for job ' + failedJob.Id + ': ' + ex.getMessage());
        }
    }
    
    /**
     * Calculate retry delay with exponential backoff
     */
    private Integer calculateRetryDelay(Integer attempt) {
        // Exponential backoff: 1min, 2min, 4min, 8min, 16min, capped at 30min
        Integer baseDelay = 60; // 1 minute
        Integer delay = Math.min(baseDelay * (Integer)Math.pow(2, attempt - 1), 1800); // Cap at 30 minutes
        return delay;
    }
    
    /**
     * Generate cron expression for given datetime
     */
    private String getCronExpression(Datetime dt) {
        return dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + 
               dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
    }
}