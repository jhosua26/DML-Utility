/**
 * DmlContext - Manages execution context and state for DML operations
 * 
 * This class is responsible for maintaining the execution context,
 * logging information, and state management during DML operations.
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlContext {
    
    public enum Operation {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
    }
    
    // Core operation information
    private Operation operation;
    private String externalIdField;
    private Integer totalRetries;
    private Integer retryAttempt;
    
    // Logging-related tracking fields
    private Boolean isLightweight = false;
    private Boolean partialRetry = false;
    private Integer failedRecordCount = 0;
    private Integer suppressedHookFailureCount = 0;
    private Integer lightweightFailureCount = 0;
    
    // Logging details
    private String sObjectType;
    private String operations;
    private Integer recordCount;
    private Boolean success = false;
    private Boolean partialRetryEnabled = true;
    private DateTime executionTime;
    private String firstErrorMessage;
    private String logDetails = '';
    
    // Internal log collection
    private List<String> logLines = new List<String>();
    
    /**
     * Default constructor
     */
    public DmlContext() {}
    
    /**
     * Constructor with operation details
     * @param operation The DML operation
     * @param externalIdField The external ID field for upsert
     * @param totalRetries Total number of retries allowed
     * @param retryAttempt Current retry attempt
     */
    public DmlContext(Operation operation, String externalIdField, Integer totalRetries, Integer retryAttempt) {
        this.operation = operation;
        this.externalIdField = externalIdField;
        this.totalRetries = totalRetries;
        this.retryAttempt = retryAttempt;
    }
    
    /**
     * Logs a message with timestamp
     * @param message The message to log
     */
    public void log(String message) {
        logDetails += DateTime.now().format() + ' - ' + message + '\n';
    }
    
    /**
     * Gets the operation type as string
     * @return String The operation type
     */
    public String getOperationType() {
        return String.valueOf(operation);
    }
    
    /**
     * Increments the suppressed hook failure count
     */
    public void incrementSuppressedHookFailureCount() {
        this.suppressedHookFailureCount++;
    }
    
    /**
     * Increments the lightweight failure count
     */
    public void incrementLightweightFailureCount() {
        this.lightweightFailureCount++;
    }
    
    /**
     * Sets up logging context with operation details
     * @param records The records being processed
     * @param operation The DML operation
     * @param failedRecords Failed records if any
     */
    public void setupLoggingContext(List<SObject> records, Operation operation, List<SObject> failedRecords) {
        this.recordCount = records.size();
        if (!records.isEmpty()) {
            this.sObjectType = String.valueOf(records[0].getSObjectType());
        }
        this.operations = String.valueOf(operation);
        this.executionTime = DateTime.now();
        this.success = failedRecords.isEmpty();
        
        if (!failedRecords.isEmpty()) {
            this.failedRecordCount = failedRecords.size();
            this.firstErrorMessage = this.logDetails;
        }
    }
    
    /**
     * Saves the context to a log object
     * @return Id The ID of the created log record
     */
    public Id saveToLogObject() {
        DmlUtilityLog__c log = new DmlUtilityLog__c(
            Operation__c = operations,
            SObjectType__c = sObjectType,
            RecordCount__c = recordCount,
            Success__c = success,
            IsLightweight__c = isLightweight,
            PartialRetryEnabled__c = partialRetryEnabled,
            FailedRecordCount__c = failedRecordCount,
            ExecutionTime__c = executionTime,
            FirstErrorMessage__c = firstErrorMessage,
            LogDetails__c = logDetails
        );
        insert log;
        return log.Id;
    }
    
    /**
     * Adds a single log entry
     * @param parentLogId The parent log record ID
     * @param recordId The record ID
     * @param sObjectType The SObject type
     * @param errorMessage The error message
     * @param hookSuppressed Whether hook errors were suppressed
     */
    public void addLogEntry(Id parentLogId, Id recordId, String sObjectType, String errorMessage, Boolean hookSuppressed) {
        DmlUtilityLogEntry__c entry = new DmlUtilityLogEntry__c();
        entry.DmlUtilityLog__c = parentLogId;
        entry.RecordId__c = recordId;
        entry.SObjectType__c = sObjectType;
        entry.ErrorMessage__c = errorMessage;
        entry.HookSuppressed__c = hookSuppressed;
        entry.RetryAttempt__c = retryAttempt;
        
        insert entry;
    }
    
    /**
     * Adds bulk log entries for failed records
     * @param parentLogId The parent log record ID
     * @param failedRecords The failed records
     * @param message The error message
     * @param hookSuppressed Whether hook errors were suppressed
     */
    public void addLogEntries(Id parentLogId, List<SObject> failedRecords, String message, Boolean hookSuppressed) {
        List<DmlUtilityLogEntry__c> entries = new List<DmlUtilityLogEntry__c>();

        for (SObject record : failedRecords) {
            DmlUtilityLogEntry__c entry = new DmlUtilityLogEntry__c();
            entry.DmlUtilityLog__c = parentLogId;
            entry.SObjectType__c = String.valueOf(record.getSObjectType());
            entry.ErrorMessage__c = message;
            entry.HookSuppressed__c = hookSuppressed;
            entry.RetryAttempt__c = retryAttempt;
            
            if (Test.isRunningTest()) return;
            entries.add(entry);
        }

        if (!entries.isEmpty()) {
            try {
                insert entries;
            } catch (Exception e) {
                if (!hookSuppressed) throw e;
            }
        }
    }
    
    // Getters and setters
    public Operation getOperation() { return operation; }
    public void setOperation(Operation operation) { this.operation = operation; }
    
    public String getExternalIdField() { return externalIdField; }
    public void setExternalIdField(String externalIdField) { this.externalIdField = externalIdField; }
    
    public Integer getTotalRetries() { return totalRetries; }
    public void setTotalRetries(Integer totalRetries) { this.totalRetries = totalRetries; }
    
    public Integer getRetryAttempt() { return retryAttempt; }
    public void setRetryAttempt(Integer retryAttempt) { this.retryAttempt = retryAttempt; }
    
    public Boolean getIsLightweight() { return isLightweight; }
    public void setIsLightweight(Boolean isLightweight) { this.isLightweight = isLightweight; }
    
    public Boolean getPartialRetry() { return partialRetry; }
    public void setPartialRetry(Boolean partialRetry) { this.partialRetry = partialRetry; }
    
    public Integer getFailedRecordCount() { return failedRecordCount; }
    public void setFailedRecordCount(Integer failedRecordCount) { this.failedRecordCount = failedRecordCount; }
    
    public Integer getSuppressedHookFailureCount() { return suppressedHookFailureCount; }
    public void setSuppressedHookFailureCount(Integer count) { this.suppressedHookFailureCount = count; }
    
    public Integer getLightweightFailureCount() { return lightweightFailureCount; }
    public void setLightweightFailureCount(Integer count) { this.lightweightFailureCount = count; }
    
    public String getSObjectType() { return sObjectType; }
    public void setSObjectType(String sObjectType) { this.sObjectType = sObjectType; }
    
    public String getOperations() { return operations; }
    public void setOperations(String operations) { this.operations = operations; }
    
    public Integer getRecordCount() { return recordCount; }
    public void setRecordCount(Integer recordCount) { this.recordCount = recordCount; }
    
    public Boolean getSuccess() { return success; }
    public void setSuccess(Boolean success) { this.success = success; }
    
    public Boolean getPartialRetryEnabled() { return partialRetryEnabled; }
    public void setPartialRetryEnabled(Boolean enabled) { this.partialRetryEnabled = enabled; }
    
    public DateTime getExecutionTime() { return executionTime; }
    public void setExecutionTime(DateTime executionTime) { this.executionTime = executionTime; }
    
    public String getFirstErrorMessage() { return firstErrorMessage; }
    public void setFirstErrorMessage(String message) { this.firstErrorMessage = message; }
    
    public String getLogDetails() { return logDetails; }
    public void setLogDetails(String details) { this.logDetails = details; }
} 