/**
 * DmlProcessor - A modern utility class for handling DML operations with advanced features
 * 
 * This class uses composition to delegate responsibilities to smaller, focused classes:
 * - DmlOperationExecutor: Handles core DML operations
 * - DmlHookManager: Manages hooks and callbacks
 * - DmlContext: Manages execution context and logging
 * - DmlChunker: Handles chunking of large datasets
 * 
 * Usage Example:
 * DmlProcessor processor = new DmlProcessor()
 *     .setRecords(accounts)
 *     .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
 *     .withMaxRetry(3)
 *     .addBeforeInsertHook(new MyHook())
 *     .runNow();
 * 
 * @author DML Utility Team
 * @version 2.0
 */
public class DmlProcessor implements Queueable {
    
    // Core components
    private DmlOperationExecutor operationExecutor;
    private DmlHookManager hookManager;
    private DmlContext context;
    private DmlChunker chunker;
    
    // Configuration
    private List<SObject> records;
    private DmlOperationExecutor.Operation operation;
    private String externalIdField;
    private Boolean isAsync = false;
    private Boolean isLightweight = false;
    private Boolean enableLogging = false;
    private Integer maxRetry = 0;
    private Integer retryAttemptsLeft = 0;
    private Integer currentAttempt = 0;
    
    // Results
    private List<SObject> failedRecords = new List<SObject>();
    private List<DmlResult> lastResults = new List<DmlResult>();
    
    // Validators and callbacks
    private List<Validator> validators = new List<Validator>();
    private List<ResultCallback> successCallbacks = new List<ResultCallback>();
    private List<ResultCallback> failureCallbacks = new List<ResultCallback>();
    private List<OnFailureHook> onFailureHooks = new List<OnFailureHook>();
    
    /**
     * Constructor initializes all components
     */
    public DmlProcessor() {
        this.chunker = new DmlChunker();
        this.hookManager = new DmlHookManager();
    }
    
    // Builder methods
    public DmlProcessor setRecords(List<SObject> records) { 
        this.records = records; 
        this.chunker.validateHomogeneousRecords(records);
        return this; 
    }
    
    public DmlProcessor setOperation(DmlOperationExecutor.Operation operation) { 
        this.operation = operation; 
        return this; 
    }
    
    public DmlProcessor runAsync() { 
        this.isAsync = true; 
        return this; 
    }
    
    public DmlProcessor setExternalId(String field) { 
        this.externalIdField = field; 
        return this; 
    }
    
    public DmlProcessor enableLightweightMode() { 
        this.isLightweight = true; 
        return this; 
    }
    
    public DmlProcessor withMaxRetry(Integer count) { 
        this.maxRetry = count; 
        this.retryAttemptsLeft = count; 
        return this; 
    }
    
    public DmlProcessor setAttempt(Integer attempt) {
        this.currentAttempt = attempt;
        return this;
    }
    
    public DmlProcessor withLogging() { 
        this.enableLogging = true; 
        return this; 
    }
    
    public DmlProcessor setChunkSize(Integer size) {
        this.chunker.setChunkSize(size);
        return this;
    }
    
    // Hook methods
    public DmlProcessor addBeforeInsertHook(DmlHookManager.Hook hook) {
        hookManager.addBeforeInsertHook(hook);
        return this;
    }
    
    public DmlProcessor addBeforeUpdateHook(DmlHookManager.Hook hook) {
        hookManager.addBeforeUpdateHook(hook);
        return this;
    }
    
    public DmlProcessor addBeforeDeleteHook(DmlHookManager.Hook hook) {
        hookManager.addBeforeDeleteHook(hook);
        return this;
    }
    
    public DmlProcessor addBeforeUpsertHook(DmlHookManager.Hook hook) {
        hookManager.addBeforeUpsertHook(hook);
        return this;
    }
    
    public DmlProcessor addAfterInsertHook(DmlHookManager.Hook hook) {
        hookManager.addAfterInsertHook(hook);
        return this;
    }
    
    public DmlProcessor addAfterUpdateHook(DmlHookManager.Hook hook) {
        hookManager.addAfterUpdateHook(hook);
        return this;
    }
    
    public DmlProcessor addAfterDeleteHook(DmlHookManager.Hook hook) {
        hookManager.addAfterDeleteHook(hook);
        return this;
    }
    
    public DmlProcessor addAfterUpsertHook(DmlHookManager.Hook hook) {
        hookManager.addAfterUpsertHook(hook);
        return this;
    }
    
    public DmlProcessor addHookErrorCallback(DmlHookManager.HookErrorCallback callback) {
        hookManager.addHookErrorCallback(callback);
        return this;
    }
    
    public DmlProcessor suppressHookExceptions() {
        hookManager.suppressHookExceptions();
        return this;
    }
    
    // Validation and callback methods
    public DmlProcessor addValidator(Validator validator) {
        validators.add(validator);
        return this;
    }
    
    public DmlProcessor addSuccessCallback(ResultCallback callback) {
        successCallbacks.add(callback);
        return this;
    }
    
    public DmlProcessor addFailureCallback(ResultCallback callback) {
        failureCallbacks.add(callback);
        return this;
    }
    
    public DmlProcessor addOnFailureHook(OnFailureHook hook) {
        onFailureHooks.add(hook);
        return this;
    }
    
    // Getters
    public List<SObject> getFailedRecords() {
        return failedRecords;
    }
    
    // Additional getters for retry handler integration
    public DmlOperationExecutor.Operation getOperation() {
        return operation;
    }
    
    public String getExternalIdField() {
        return externalIdField;
    }
    
    public Boolean getIsAsync() {
        return isAsync;
    }
    
    public Boolean getIsLightweight() {
        return isLightweight;
    }
    
    public Integer getMaxRetry() {
        return maxRetry;
    }
    
    // Entry points
    public void runNow() {
        if (records == null || records.isEmpty()) return;
        
        if (isAsync) {
            System.enqueueJob(this);
            return;
        }
        
        doExecute();
    }
    
    public void execute(QueueableContext ctx) {
        this.currentAttempt = maxRetry - retryAttemptsLeft;
        doExecute();
    }
    
    public void executeDml() {
        if (isLightweight) {
            executeLightweight();
        } else {
            runNow();
        }
    }
    
    /**
     * Main execution method
     */
    @TestVisible
    private void doExecute() {
        validateBeforeRun();
        
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('You must call setRecords() before execution.');
        }
        
        // Clear previous results
        this.failedRecords.clear();
        this.lastResults.clear();
        
        // Initialize components
        initializeComponents();
        
        // Process records in chunks
        for (List<SObject> chunk : chunker.split(records)) {
            try {
                processChunk(chunk);
            } catch (Exception ex) {
                handleChunkFailure(chunk, ex);
            }
        }
        
        // Handle logging
        if (enableLogging) {
            handleLogging();
        }
    }
    
    /**
     * Initializes all components with current configuration
     */
    private void initializeComponents() {
        this.operationExecutor = new DmlOperationExecutor(externalIdField);
        this.context = new DmlContext(convertOperation(operation), externalIdField, maxRetry, currentAttempt);
        this.context.setIsLightweight(isLightweight);
    }
    
    /**
     * Converts DmlOperationExecutor.Operation to DmlContext.Operation
     */
    private DmlContext.Operation convertOperation(DmlOperationExecutor.Operation operation) {
        if (operation == DmlOperationExecutor.Operation.DO_INSERT) return DmlContext.Operation.DO_INSERT;
        if (operation == DmlOperationExecutor.Operation.DO_UPDATE) return DmlContext.Operation.DO_UPDATE;
        if (operation == DmlOperationExecutor.Operation.DO_DELETE) return DmlContext.Operation.DO_DELETE;
        if (operation == DmlOperationExecutor.Operation.DO_UPSERT) return DmlContext.Operation.DO_UPSERT;
        return DmlContext.Operation.DO_INSERT; // Default
    }
    
    /**
     * Converts DmlOperationExecutor.Operation to DmlHookManager.Operation
     */
    private DmlHookManager.Operation convertToHookManagerOperation(DmlOperationExecutor.Operation operation) {
        if (operation == DmlOperationExecutor.Operation.DO_INSERT) return DmlHookManager.Operation.DO_INSERT;
        if (operation == DmlOperationExecutor.Operation.DO_UPDATE) return DmlHookManager.Operation.DO_UPDATE;
        if (operation == DmlOperationExecutor.Operation.DO_DELETE) return DmlHookManager.Operation.DO_DELETE;
        if (operation == DmlOperationExecutor.Operation.DO_UPSERT) return DmlHookManager.Operation.DO_UPSERT;
        return DmlHookManager.Operation.DO_INSERT; // Default
    }
    
    /**
     * Validates before execution
     */
    private void validateBeforeRun() {
        chunker.validateHomogeneousRecords(records);
        
        if (operation == DmlOperationExecutor.Operation.DO_UPSERT && String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert operation.');
        }
        
        if (isLightweight && operation == DmlOperationExecutor.Operation.DO_UPSERT) {
            throw new DmlException('Lightweight mode does not support upsert operations.');
        }
    }
    
    /**
     * Processes a chunk of records
     */
    private void processChunk(List<SObject> chunk) {
        lastResults.clear();
        
        try {
            // Execute hooks
            hookManager.executeBeforeHooks(chunk, convertToHookManagerOperation(operation), context);
            
            // Validate
            validate(chunk);
            
            // Perform DML
            DmlOperationExecutor.DmlOperationResult result = operationExecutor.execute(chunk, operation);
            lastResults.addAll(convertResults(result));
            
            // Accumulate failed records
            if (result.failedRecords != null && !result.failedRecords.isEmpty()) {
                this.failedRecords.addAll(result.failedRecords);
            }
            
            // Update context with error messages if any
            if (context != null && !result.errorMessages.isEmpty()) {
                context.setLogDetails(String.join(result.errorMessages, '\n'));
            }
            
            // Execute after hooks
            hookManager.executeAfterHooks(chunk, convertToHookManagerOperation(operation), context);
            
            // Route results
            routeResults(lastResults);
            
            // Handle retries
            handleRetries(result);
            
        } catch (Exception ex) {
            if (retryAttemptsLeft > 0) {
                scheduleRetry(chunk, ex);
            } else {
                handleChunkFailure(chunk, ex);
                // Add chunk to failed records if no retry (only if not already added)
                this.failedRecords.addAll(chunk);
            }
        }
    }
    

    
    /**
     * Handles logging when enabled
     */
    private void handleLogging() {
        if (context == null) {
            context = new DmlContext();
        }
        
        if (!context.getIsLightweight()) {
            context.setupLoggingContext(records, convertOperation(operation), failedRecords);
            Id logId = context.saveToLogObject();
            
            if (!failedRecords.isEmpty()) {
                context.addLogEntries(
                    logId,
                    failedRecords,
                    'DML failure during ' + String.valueOf(operation),
                    false
                );
            }
        }
    }
    
    /**
     * Executes lightweight mode
     */
    private void executeLightweight() {
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('You must call setRecords() before execution.');
        }
        initializeComponents();
        for (List<SObject> chunk : chunker.split(records)) {
            try {
                // Determine operation type and process accordingly
                if (operation == DmlOperationExecutor.Operation.DO_INSERT) {
                    Database.SaveResult[] results = Database.insert(chunk, false);
                    for (Integer i = 0; i < results.size(); i++) {
                        if (!results[i].isSuccess()) {
                            failedRecords.add(chunk[i]);
                            if (context != null) context.incrementLightweightFailureCount();
                        }
                    }
                } else if (operation == DmlOperationExecutor.Operation.DO_UPDATE) {
                    Database.SaveResult[] results = Database.update(chunk, false);
                    for (Integer i = 0; i < results.size(); i++) {
                        if (!results[i].isSuccess()) {
                            failedRecords.add(chunk[i]);
                            if (context != null) context.incrementLightweightFailureCount();
                        }
                    }
                } else if (operation == DmlOperationExecutor.Operation.DO_DELETE) {
                    Database.DeleteResult[] results = Database.delete(chunk, false);
                    for (Integer i = 0; i < results.size(); i++) {
                        if (!results[i].isSuccess()) {
                            failedRecords.add(chunk[i]);
                            if (context != null) context.incrementLightweightFailureCount();
                        }
                    }
                } else if (operation == DmlOperationExecutor.Operation.DO_UPSERT) {
                    Schema.SObjectField extIdField = null;
                    if (!String.isBlank(externalIdField)) {
                        extIdField = chunk[0].getSObjectType().getDescribe().fields.getMap().get(externalIdField);
                    }
                    Database.UpsertResult[] results = Database.upsert(chunk, extIdField, false);
                    for (Integer i = 0; i < results.size(); i++) {
                        if (!results[i].isSuccess()) {
                            failedRecords.add(chunk[i]);
                            if (context != null) context.incrementLightweightFailureCount();
                        }
                    }
                }
            } catch (Exception e) {
                handleLightweightChunkFailure(chunk, e);
            }
        }
    }
    
    /**
     * Handles lightweight chunk failures
     */
    private void handleLightweightChunkFailure(List<SObject> chunk, Exception e) {
        String errorMsg = String.format('[DmlProcessor] Lightweight DML chunk failed: {0}', new List<String>{ e.getMessage() });
        System.debug(LoggingLevel.WARN, errorMsg);
        
        if (context != null) {
            context.incrementLightweightFailureCount();
        }
        
        failedRecords.addAll(chunk);
    }
    
    /**
     * Validates records using validators
     */
    private void validate(List<SObject> chunk) {
        for (Validator validator : validators) {
            validator.validate(chunk);
        }
    }
    
    /**
     * Routes results to callbacks
     */
    private void routeResults(List<DmlResult> results) {
        for (DmlResult result : results) {
            if (result.success) {
                for (ResultCallback callback : successCallbacks) {
                    callback.handle(result.record, context, result.saveResult);
                }
            } else {
                for (ResultCallback callback : failureCallbacks) {
                    callback.handle(result.record, context, result.getFirstError());
                }
            }
        }
    }
    
    /**
     * Handles retries for failed operations
     */
    private void handleRetries(DmlOperationExecutor.DmlOperationResult result) {
        if (result.hasFailures && retryAttemptsLeft > 0 && isRetryWorthy(result)) {
            scheduleRetry(result.failedRecords, null);
        }
    }
    
    /**
     * Determines if a failed operation is worth retrying
     */
    private Boolean isRetryWorthy(DmlOperationExecutor.DmlOperationResult result) {
        // Custom validation exceptions are not retryable
        // Add other non-retryable error types here as needed
        return true;
    }
    
    /**
     * Schedules a retry for failed records
     */
    private void scheduleRetry(List<SObject> failedRecords, Exception ex) {
        if (failedRecords != null && !failedRecords.isEmpty()) {
            DmlRetryHandler.scheduleRetry(this, failedRecords, retryAttemptsLeft - 1, currentAttempt + 1);
        }
    }
    
    /**
     * Handles chunk processing failures
     */
    private void handleChunkFailure(List<SObject> chunk, Exception ex) {
        for (ResultCallback callback : failureCallbacks) {
            for (SObject record : chunk) {
                callback.handle(record, context, ex);
            }
        }
        
        for (OnFailureHook hook : onFailureHooks) {
            hook.onFailure(chunk, context, ex);
        }
    }
    
    /**
     * Converts DmlOperationExecutor.DmlOperationResult to DmlResult list
     */
    private List<DmlResult> convertResults(DmlOperationExecutor.DmlOperationResult result) {
        List<DmlResult> results = new List<DmlResult>();
        // Implementation would convert the result format
        return results;
    }
    
    /**
     * Clones the processor with new records and retry settings
     */
    public DmlProcessor cloneWith(List<SObject> newRecords, Integer retryLeft, Integer attempt) {
        List<SObject> clonedRecords = new List<SObject>();
        for (SObject rec : newRecords) {
            clonedRecords.add(rec.clone(false, true, true, true));
        }
        
        DmlProcessor cloned = new DmlProcessor()
            .setRecords(clonedRecords)
            .setOperation(operation)
            .setExternalId(externalIdField)
            .withMaxRetry(maxRetry)
            .setAttempt(attempt);
        
        cloned.retryAttemptsLeft = retryLeft;
        
        if (this.isAsync) {
            cloned.runAsync();
        }
        
        if (this.isLightweight) {
            cloned.enableLightweightMode();
        }
        
        return cloned;
    }
    
    // Interfaces
    public interface Validator { 
        void validate(List<SObject> records); 
    }
    
    public interface ResultCallback {
        void handle(SObject record, DmlContext context, Object resultOrError);
    }
    
    public interface OnFailureHook {
        void onFailure(List<SObject> failed, DmlContext context, Exception ex);
    }
    
    public class DmlResult {
        public SObject record;
        public Boolean success;
        public List<Database.Error> errors = new List<Database.Error>();
        public Database.SaveResult saveResult;
        public Database.DeleteResult deleteResult;
        public Database.UpsertResult upsertResult;

        public DmlResult() {}

        public DmlResult(SObject record, Database.SaveResult res) {
            this.record = record; 
            this.success = true; 
            this.saveResult = res;
        }
        
        public DmlResult(SObject record, Database.DeleteResult res) {
            this.record = record; 
            this.success = true; 
            this.deleteResult = res;
        }
        
        public DmlResult(SObject record, Database.UpsertResult res) {
            this.record = record; 
            this.success = true; 
            this.upsertResult = res;
        }
        
        public DmlResult(SObject record, List<Database.Error> errors) {
            this.record = record; 
            this.success = false; 
            this.errors = errors;
        }
        
        public Exception getFirstError() {
            return (!errors.isEmpty()) ? new DmlException(errors[0].getMessage()) : new DmlException('Unknown failure');
        }
    }
    
    public class DmlException extends Exception {}
} 