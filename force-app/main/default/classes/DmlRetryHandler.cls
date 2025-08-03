public class DmlRetryHandler {
    public static void scheduleRetry(DmlUtility originalJob, List<SObject> failedRecords, Integer retryLeft, Integer attempt) {
        String serializedRecords = JSON.serialize(failedRecords);

        // Create retry job record
        DmlRetryJob__c job = new DmlRetryJob__c(
            SerializedRecord__c = serializedRecords,
            Operation__c = String.valueOf(originalJob.operation),
            ExternalIdField__c = originalJob.externalIdField,
            RetryLeft__c = retryLeft,
            Attempt__c = attempt,
            IsAsync__c = originalJob.isAsync,
            IsLightweight__c = originalJob.isLightweight,
            Status__c = 'Pending'
        );
        insert job;

        // Schedule job using default constructor
        Integer delaySeconds = calculateRetryDelay(originalJob.maxRetry, attempt);
        Datetime runTime = Datetime.now().addSeconds(delaySeconds);
        String cron = getCronExpression(runTime);
        System.schedule('RetryJob_' + job.Id, cron, new DmlScheduledRetryHandler());
    }
    
    /**
     * Schedules a retry for DmlProcessor
     * @param processor The DmlProcessor instance
     * @param failedRecords Records that failed
     * @param retryLeft Number of retries remaining
     * @param attempt Current attempt number
     */
    public static void scheduleRetry(DmlProcessor processor, List<SObject> failedRecords, Integer retryLeft, Integer attempt) {
        String serializedRecords = JSON.serialize(failedRecords);

        // Create retry job record
        DmlRetryJob__c job = new DmlRetryJob__c(
            SerializedRecord__c = serializedRecords,
            Operation__c = String.valueOf(processor.getOperation()),
            ExternalIdField__c = processor.getExternalIdField(),
            RetryLeft__c = retryLeft,
            Attempt__c = attempt,
            IsAsync__c = processor.getIsAsync(),
            IsLightweight__c = processor.getIsLightweight(),
            Status__c = 'Pending'
        );
        insert job;

        // Schedule job using default constructor
        Integer delaySeconds = calculateRetryDelay(processor.getMaxRetry(), attempt);
        Datetime runTime = Datetime.now().addSeconds(delaySeconds);
        String cron = getCronExpression(runTime);
        System.schedule('RetryJob_' + job.Id, cron, new DmlScheduledRetryHandler());
    }

    private static Integer calculateRetryDelay(Integer maxRetries, Integer attempt) {
        // Exponential backoff, capped at 1 hour (3600 seconds)
        Integer baseDelay = 60; // start with 1 minute
        Integer delay = Math.min(baseDelay * (Integer)Math.pow(2, attempt), 3600);
        return delay;
    }

    private static String getCronExpression(Datetime dt) {
        return String.format('%d %d %d %d %d ? %d',
            new List<Object>{
                dt.second(), dt.minute(), dt.hour(),
                dt.day(), dt.month(), dt.year()
            }
        );
    }
}