public class DmlRetryHandler {
    
    /**
     * Schedules a retry for DmlProcessor
     * @param processor The DmlProcessor instance
     * @param failedRecords Records that failed
     * @param retryLeft Number of retries remaining
     * @param attempt Current attempt number
     */
    public static void scheduleRetry(DmlProcessor processor, List<SObject> failedRecords, Integer retryLeft, Integer attempt) {
        // Validate input parameters
        validateInputs(failedRecords, retryLeft, attempt);
        
        if (processor == null) {
            throw new IllegalArgumentException('Processor cannot be null');
        }
        
        if (failedRecords.isEmpty()) {
            return; // No point in scheduling retry for empty records
        }
        
        // Extract SObject type from failed records
        String sObjectType = getSObjectType(failedRecords);
        
        // Use shared implementation
        scheduleRetryInternal(
            JSON.serialize(failedRecords),
            String.valueOf(processor.getOperation()),
            processor.getExternalIdField(),
            sObjectType,
            retryLeft,
            attempt,
            processor.getIsAsync(),
            processor.getIsLightweight(),
            processor.getMaxRetry()
        );
    }
    
    /**
     * Shared internal method for scheduling retries
     */
    private static void scheduleRetryInternal(
        String serializedRecords, 
        String operation, 
        String externalIdField, 
        String sObjectType,
        Integer retryLeft, 
        Integer attempt, 
        Boolean isAsync, 
        Boolean isLightweight, 
        Integer maxRetry
    ) {
        
        // Validate serialized data size to prevent field length issues
        validateSerializedDataSize(serializedRecords);
        
        // Create retry job record
        DmlRetryJob__c job = new DmlRetryJob__c(
            SerializedRecord__c = serializedRecords,
            Operation__c = operation,
            ExternalIdField__c = externalIdField,
            SObjectType__c = sObjectType,
            RetryLeft__c = retryLeft,
            Attempt__c = attempt,
            IsAsync__c = isAsync,
            IsLightweight__c = isLightweight,
            Status__c = 'Pending'
        );
        
        try {
            insert job;
        } catch (DmlException ex) {
            throw new IllegalArgumentException('Failed to create retry job: ' + ex.getMessage(), ex);
        }

        // Schedule job using default constructor
        Integer delaySeconds = calculateRetryDelay(maxRetry, attempt);
        Datetime runTime = Datetime.now().addSeconds(delaySeconds);
        String cron = getCronExpression(runTime);
        
        try {
            System.schedule('RetryJob_' + job.Id, cron, new DmlScheduledRetryHandler());
            System.debug(LoggingLevel.INFO, 'Scheduled retry job ' + job.Id + ' with delay of ' + delaySeconds + ' seconds');
        } catch (Exception ex) {
            // Clean up the job if scheduling fails
            delete job;
            throw new IllegalArgumentException('Failed to schedule retry job: ' + ex.getMessage(), ex);
        }
    }
    
    /**
     * Validates common input parameters
     */
    private static void validateInputs(List<SObject> failedRecords, Integer retryLeft, Integer attempt) {
        if (failedRecords == null) {
            throw new IllegalArgumentException('Failed records cannot be null');
        }
        
        if (retryLeft == null || retryLeft < 0) {
            throw new IllegalArgumentException('RetryLeft must be non-negative, got: ' + retryLeft);
        }
        
        if (attempt == null || attempt < 1) {
            throw new IllegalArgumentException('Attempt must be greater than 0, got: ' + attempt);
        }
        
        // Note: We allow retryLeft == 0 for the final attempt, but warn that no further retries will be scheduled
    }
    
    /**
     * Extracts SObject type from the failed records list
     */
    private static String getSObjectType(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('Cannot determine SObject type from empty records list');
        }
        
        // Additional safety check - ensure first record is not null
        if (records[0] == null) {
            throw new IllegalArgumentException('First record in the list cannot be null');
        }
        
        // Get the SObject type from the first record
        SObjectType sObjectType = records[0].getSObjectType();
        if (sObjectType == null) {
            throw new IllegalArgumentException('Unable to determine SObject type from records');
        }
        
        return String.valueOf(sObjectType);
    }
    
    /**
     * Validates that serialized data won't exceed field limits
     */
    private static void validateSerializedDataSize(String serializedRecords) {
        if (String.isBlank(serializedRecords)) {
            throw new IllegalArgumentException('Serialized records cannot be blank');
        }
        
        // Check if the serialized data is too large for a Long Text Area field
        // Using 32,768 as the standard Long Text Area limit (32KB)
        Integer maxFieldSize = 32768; // Standard Long Text Area limit
        if (serializedRecords.length() > maxFieldSize) {
            throw new IllegalArgumentException(
                'Serialized records too large (' + serializedRecords.length() + 
                ' characters). Maximum allowed: ' + maxFieldSize + ' characters. ' +
                'Consider chunking the records into smaller batches.'
            );
        }
    }

    /**
     * Calculates retry delay with exponential backoff
     */
    private static Integer calculateRetryDelay(Integer maxRetries, Integer attempt) {
        if (maxRetries == null || maxRetries <= 0) {
            maxRetries = 3; // Default fallback
        }
        
        if (attempt == null || attempt <= 0) {
            attempt = 1; // Default fallback
        }
        
        // Exponential backoff, capped at 1 hour (3600 seconds)
        Integer baseDelay = 60; // start with 1 minute
        Integer delay = Math.min(baseDelay * (Integer)Math.pow(2, attempt), 3600);
        return delay;
    }

    /**
     * Generates cron expression for the given datetime
     */
    private static String getCronExpression(Datetime dt) {
        if (dt == null) {
            throw new IllegalArgumentException('Datetime cannot be null for cron expression');
        }
        
        return dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + 
               dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
    }
}