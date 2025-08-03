/**
 * DmlUtility - A comprehensive utility class for handling DML operations with advanced features
 * 
 * This class provides a fluent API for performing DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * with built-in support for:
 * - Retry mechanisms with exponential backoff
 * - Before/after hooks for custom processing
 * - Async processing using Queueable
 * - Lightweight mode for high-volume operations
 * - Comprehensive error handling and logging
 * - Chunking for large datasets
 * - Validation and callback support
 * 
 * Usage Example:
 * DmlUtility utility = new DmlUtility()
 *     .setRecords(accounts)
 *     .setOperation(DmlUtility.Operation.DO_INSERT)
 *     .withMaxRetry(3)
 *     .addBeforeInsertHook(new MyHook())
 *     .runNow();
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlUtility implements Queueable {
    public enum Operation {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
    }

    private List<SObject> records;
    public Operation operation;
    public String externalIdField;
    private Integer chunkSize = 100;

    public Boolean isAsync = false;
    public Boolean isLightweight = false;
    private Boolean enablePartialRetry = false;
    private Boolean enableLogging = false;
    private List<SObject> failedRecords = new List<SObject>();

    public Integer maxRetry = 0;
    public Integer retryAttemptsLeft = 0;
    
    public Integer currentAttempt = 0;
    private Boolean suppressHookFailure = false;
    private Boolean suppressHookErrors = false;

    private DmlUtilityContext context;
    private List<DmlResult> lastResults = new List<DmlResult>();

    private List<Validator> validators = new List<Validator>();
    private List<ResultCallback> successCallbacks = new List<ResultCallback>();
    private List<ResultCallback> failureCallbacks = new List<ResultCallback>();
    private List<OnFailureHook> onFailureHooks = new List<OnFailureHook>();
    private List<HookErrorCallback> hookErrorCallbacks = new List<HookErrorCallback>();
    private List<LightweightErrorCallback> lightweightErrorCallbacks = new List<LightweightErrorCallback>();

    private List<Hook> beforeInsertHooks = new List<Hook>();
    private List<Hook> beforeUpdateHooks = new List<Hook>();
    private List<Hook> beforeDeleteHooks = new List<Hook>();
    private List<Hook> beforeUpsertHooks = new List<Hook>();

    private List<Hook> afterInsertHooks  = new List<Hook>();
    private List<Hook> afterUpdateHooks  = new List<Hook>();
    private List<Hook> afterDeleteHooks  = new List<Hook>();
    private List<Hook> afterUpsertHooks = new List<Hook>();

    // Builder methods
    public DmlUtility setRecords(List<SObject> records) { guard_HomogeneousRecords(records); this.records = records; return this; }
    public DmlUtility setOperation(Operation op) { this.operation = op; return this; }
    public DmlUtility runAsync() { this.isAsync = true; return this; }
    public DmlUtility setExternalId(String field) { this.externalIdField = field; return this; }
    public DmlUtility suppressHookExceptions() { this.suppressHookErrors = true; return this; }
    public DmlUtility addHookErrorCallback(HookErrorCallback cb) { hookErrorCallbacks.add(cb); return this; }
    public DmlUtility addLightweightErrorCallback(LightweightErrorCallback cb) { lightweightErrorCallbacks.add(cb); return this; }
    public DmlUtility withPartialRetryEnabled() { this.enablePartialRetry = true; return this; }
    public DmlUtility withLogging() { this.enableLogging = true; return this; }
    
    public DmlUtility enableLightweightMode() { this.isLightweight = true; return this; }
    public DmlUtility withMaxRetry(Integer count) { this.maxRetry = count; this.retryAttemptsLeft = count; return this; }

    // Hook additions
    public DmlUtility addValidator(Validator v) { validators.add(v); return this; }
    public DmlUtility addSuccessCallback(ResultCallback cb) { successCallbacks.add(cb); return this; }
    public DmlUtility addFailureCallback(ResultCallback cb) { failureCallbacks.add(cb); return this; }
    public DmlUtility addOnFailureHook(OnFailureHook hook) { onFailureHooks.add(hook); return this; }
    public DmlUtility addHook(Hook hook) { beforeInsertHooks.add(hook);  return this; }

    public DmlUtility addBeforeInsertHook(Hook h) { beforeInsertHooks.add(h); return this; }
    public DmlUtility addBeforeUpdateHook(Hook h) { beforeUpdateHooks.add(h); return this; }
    public DmlUtility addBeforeDeleteHook(Hook h) { beforeDeleteHooks.add(h); return this; }
    public DmlUtility addBeforeUpsertHook(Hook h) { beforeUpsertHooks.add(h); return this; }
    public DmlUtility addAfterInsertHook(Hook h) { afterInsertHooks.add(h); return this; }
    public DmlUtility addAfterUpdateHook(Hook h) { afterUpdateHooks.add(h); return this; }
    public DmlUtility addAfterDeleteHook(Hook h) { afterDeleteHooks.add(h); return this; }
    public DmlUtility addAfterUpsertHook(Hook h) { afterUpsertHooks.add(h); return this; }
    
    //Getters
    public List<SObject> getFailedRecords() {
        return failedRecords;
    }
    
    private void guard_HomogeneousRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) return;
    
        Schema.SObjectType expectedType = records[0].getSObjectType();
        for (SObject rec : records) {
            if (rec.getSObjectType() != expectedType) {
                throw new DmlException('All records must be of the same SObject type.');
            }
        }
    }

    // Entry point
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

    @TestVisible
    private void doExecute() {
        validateBeforeRun();
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('You must call setRecords() before execution.');
        }
        
        context = new DmlUtilityContext(operation, externalIdField, maxRetry, currentAttempt);
        
        // Process records in chunks
        for (List<SObject> chunk : split(records)) {
            try {
                processChunk(chunk);
            } catch (Exception ex) {
                handleChunkFailure(chunk, ex);
            }
        }
        
        // Process DML operations and handle failures
        processDmlOperations();
        
        // Handle logging if enabled
        if (enableLogging) {
            handleLogging();
        }
    }
    
    /**
     * Processes DML operations based on the operation type
     * Handles INSERT, UPDATE, DELETE, and UPSERT operations
     */
    private void processDmlOperations() {
        if (operation == DmlUtility.Operation.DO_INSERT) {
            processInsertOperation();
        } else if (operation == DmlUtility.Operation.DO_UPDATE) {
            processUpdateOperation();
        } else if (operation == DmlUtility.Operation.DO_DELETE) {
            processDeleteOperation();
        } else if (operation == DmlUtility.Operation.DO_UPSERT) {
            processUpsertOperation();
        } else {
            throw new UnsupportedOperationException('Unsupported DML operation: ' + operation);
        }
    }
    
    /**
     * Processes INSERT operation and handles failures
     */
    private void processInsertOperation() {
        Database.SaveResult[] results = Database.insert(records, false);
        processSaveResults(results, 'INSERT');
    }
    
    /**
     * Processes UPDATE operation and handles failures
     */
    private void processUpdateOperation() {
        Database.SaveResult[] results = Database.update(records, false);
        processSaveResults(results, 'UPDATE');
    }
    
    /**
     * Processes DELETE operation and handles failures
     */
    private void processDeleteOperation() {
        Database.DeleteResult[] results = Database.delete(records, false);
        processDeleteResults(results);
    }
    
    /**
     * Processes UPSERT operation and handles failures
     */
    private void processUpsertOperation() {
        guard_ValidateUpsertFields(records);
        Schema.SObjectField extIdField = getExternalIdField();
        Database.UpsertResult[] results = Database.upsert(records, extIdField, false);
        processUpsertResults(results);
    }
    
    /**
     * Processes save results (INSERT/UPDATE) and extracts failed records
     * @param results Database save results
     * @param operationType Type of operation for error messages
     */
    private void processSaveResults(Database.SaveResult[] results, String operationType) {
        failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} ({1}): {2}', 
                        new List<String>{ String.valueOf(i), operationType, err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        updateContextWithFailures(errorMessages);
    }
    
    /**
     * Processes delete results and extracts failed records
     * @param results Database delete results
     */
    private void processDeleteResults(Database.DeleteResult[] results) {
        failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} (DELETE): {1}', 
                        new List<String>{ String.valueOf(i), err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        updateContextWithFailures(errorMessages);
    }
    
    /**
     * Processes upsert results and extracts failed records
     * @param results Database upsert results
     */
    private void processUpsertResults(Database.UpsertResult[] results) {
        failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} (UPSERT): {1}', 
                        new List<String>{ String.valueOf(i), err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        updateContextWithFailures(errorMessages);
    }
    
    /**
     * Gets the external ID field for upsert operations
     * @return Schema.SObjectField The external ID field
     */
    private Schema.SObjectField getExternalIdField() {
        if (String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert operation.');
        }
        
        Schema.SObjectType objType = records[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        
        if (!fieldsMap.containsKey(externalIdField)) {
            throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
        }
        
        return fieldsMap.get(externalIdField);
    }
    
    /**
     * Updates context with failure information
     * @param errorMessages List of error messages
     */
    private void updateContextWithFailures(List<String> errorMessages) {
        if (!failedRecords.isEmpty() && context != null) {
            context.logDetails = String.join(errorMessages, '\n');
        }
    }
    
    /**
     * Handles chunk processing failures
     * @param chunk The chunk that failed
     * @param ex The exception that occurred
     */
    private void handleChunkFailure(List<SObject> chunk, Exception ex) {
        handleFailureCallbacks(chunk, ex);
        for (OnFailureHook hook : onFailureHooks) {
            hook.onFailure(chunk, context, ex);
        }
    }
    
    /**
     * Handles logging when enabled
     */
    private void handleLogging() {
        if (context == null) {
            context = new DmlUtility.DmlUtilityContext();
        }
        
        if (!context.isLightweight) {
            setupLoggingContext();
            Id logId = context.saveToLogObject();
            
            if (!failedRecords.isEmpty()) {
                context.addLogEntries(
                    logId,
                    failedRecords,
                    'DML failure during ' + String.valueOf(operation),
                    suppressHookErrors
                );
            }
        }
    }
    
    /**
     * Sets up logging context with operation details
     */
    private void setupLoggingContext() {
        context.recordCount = records.size();
        if (!records.isEmpty()) {
            context.sObjectType = String.valueOf(records[0].getSObjectType());
        }
        context.operations = String.valueOf(operation);
        context.executionTime = DateTime.now();
        context.success = failedRecords.isEmpty();
        
        if (!failedRecords.isEmpty()) {
            context.failedRecordCount = failedRecords.size();
            context.firstErrorMessage = context.logDetails;
        }
    }
    
    private void validateBeforeRun() {
        guard_HomogeneousRecords(records);
        if (operation == DmlUtility.Operation.DO_UPSERT) {
            guard_ValidateUpsertFields(records);
        }
        if (isLightweight) {
            guard_ValidateLightweightMode();
        }
    }
    
    private void processChunk(List<SObject> chunk) {
        
        lastResults.clear();
    
        try {
            runHooks(chunk, true);     // Handles its own suppression internally
            validate(chunk);
    
            List<DmlResult> results = performDml(chunk);
            lastResults.addAll(results);
    
            runHooks(chunk, false);    // Also handles its own suppression
            routeResults(results);
    
            // Retry only failed records
            Boolean anyFailures = false;
            List<SObject> failedRecords = new List<SObject>();
            
            for (DmlResult result : results) {
                if (!result.success) {
                    anyFailures = true;
                    failedRecords.add(result.record);
                }
            }
    
            if (anyFailures && retryAttemptsLeft > 0 && isRetryWorthy(results)) {
                DmlRetryHandler.scheduleRetry(this, failedRecords, retryAttemptsLeft - 1, currentAttempt + 1);
            }
    
        } catch (Exception ex) {
            // Entire chunk failed (e.g. validation or DML exception)
            if (retryAttemptsLeft > 0) {
                DmlRetryHandler.scheduleRetry(this, chunk, retryAttemptsLeft - 1, currentAttempt + 1);
            } else {
                handleFailureCallbacks(chunk, ex);
                for (OnFailureHook hook : onFailureHooks) {
                    hook.onFailure(chunk, context, ex);
                }
            }
        }
    }

    /**
     * Determines if a failed DML operation is worth retrying
     * Custom validation exceptions are not retryable as they represent business logic failures
     * @param results List of DML results to evaluate
     * @return Boolean True if the operation should be retried
     */
    private Boolean isRetryWorthy(List<DmlResult> results) {
        for (DmlResult res : results) {
            if (!res.success) {
                for (Database.Error err : res.errors) {
                    // Don't retry custom validation exceptions as they represent business logic failures
                    if (err.getStatusCode() == StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
                        return false;
                    }
                    // Add other non-retryable error types here as needed
                }
            }
        }
        return true;
    }


    /**
     * Executes DML operations in lightweight mode for high-volume processing
     * Lightweight mode skips hooks and validation for performance
     */
    private void executeLightweight() {
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('You must call setRecords() before execution.');
        }
        
        guard_ValidateLightweightMode();
        
        for (List<SObject> chunk : split(records)) {
            try {
                performDml(chunk); // minimal processing without hooks
            } catch (Exception e) {
                handleLightweightChunkFailure(chunk, e);
            }
        }
    }
    
    /**
     * Handles lightweight chunk processing failures
     * @param chunk The chunk that failed
     * @param e The exception that occurred
     */
    private void handleLightweightChunkFailure(List<SObject> chunk, Exception e) {
        String errorMsg = String.format('[DmlUtility] Lightweight DML chunk failed: {0}', new List<String>{ e.getMessage() });
        System.debug(LoggingLevel.WARN, errorMsg);
        
        if (context != null) {
            context.lightweightFailureCount++;
        }

        if (enablePartialRetry) {
            retryIndividually(chunk);
        } else {
            failedRecords.addAll(chunk);
        }
    }
    
    private void retryIndividually(List<SObject> chunk) {
        for (SObject record : chunk) {
            try {
                performDml(new List<SObject>{ record });
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, '[DmlUtility] Lightweight individual retry failed: ' + ex.getMessage());
                failedRecords.add(record);
                if (context != null) {
                    context.lightweightFailureCount++;
                }
            }
        }
    }
    
    private void guard_ValidateLightweightMode() {
        if (operation == DmlUtility.Operation.DO_UPSERT) {
            throw new DmlException('Lightweight mode does not support upsert operations.');
        }
    }

    /**
     * Performs DML operations on a chunk of records
     * @param chunk List of SObjects to process
     * @return List<DmlResult> Results of the DML operation
     */
    private List<DmlResult> performDml(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();

        if (operation == DmlUtility.Operation.DO_INSERT) {
            results = performInsertOperation(chunk);
        } else if (operation == DmlUtility.Operation.DO_UPDATE) {
            results = performUpdateOperation(chunk);
        } else if (operation == DmlUtility.Operation.DO_DELETE) {
            results = performDeleteOperation(chunk);
        } else if (operation == DmlUtility.Operation.DO_UPSERT) {
            results = performUpsertOperation(chunk);
        } else {
            throw new UnsupportedOperationException('Unsupported DML operation: ' + operation);
        }
        
        return results;
    }
    
    /**
     * Performs INSERT operation on chunk
     * @param chunk Records to insert
     * @return List<DmlResult> Results
     */
    private List<DmlResult> performInsertOperation(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();
        Database.SaveResult[] saveResults = Database.insert(chunk, false);
        
        for (Integer i = 0; i < chunk.size(); i++) {
            SObject rec = chunk[i];
            Database.SaveResult sr = saveResults[i];
            results.add(sr.isSuccess() ? new DmlResult(rec, sr) : new DmlResult(rec, sr.getErrors()));
        }
        
        return results;
    }
    
    /**
     * Performs UPDATE operation on chunk
     * @param chunk Records to update
     * @return List<DmlResult> Results
     */
    private List<DmlResult> performUpdateOperation(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();
        Database.SaveResult[] saveResults = Database.update(chunk, false);
        
        for (Integer i = 0; i < chunk.size(); i++) {
            SObject rec = chunk[i];
            Database.SaveResult sr = saveResults[i];
            results.add(sr.isSuccess() ? new DmlResult(rec, sr) : new DmlResult(rec, sr.getErrors()));
        }
        
        return results;
    }
    
    /**
     * Performs DELETE operation on chunk
     * @param chunk Records to delete
     * @return List<DmlResult> Results
     */
    private List<DmlResult> performDeleteOperation(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();
        Database.DeleteResult[] delResults = Database.delete(chunk, false);
        
        for (Integer i = 0; i < chunk.size(); i++) {
            SObject rec = chunk[i];
            Database.DeleteResult dr = delResults[i];
            results.add(dr.isSuccess() ? new DmlResult(rec, dr) : new DmlResult(rec, dr.getErrors()));
        }
        
        return results;
    }
    
    /**
     * Performs UPSERT operation on chunk
     * @param chunk Records to upsert
     * @return List<DmlResult> Results
     */
    private List<DmlResult> performUpsertOperation(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();
        guard_ValidateUpsertFields(chunk);
        
        Schema.SObjectField extIdField = getExternalIdFieldForChunk(chunk);
        Database.UpsertResult[] upsertResults = Database.upsert(chunk, extIdField, false);
        
        for (Integer i = 0; i < chunk.size(); i++) {
            SObject rec = chunk[i];
            Database.UpsertResult ur = upsertResults[i];
            results.add(ur.isSuccess() ? new DmlResult(rec, ur) : new DmlResult(rec, ur.getErrors()));
        }
        
        return results;
    }
    
    /**
     * Gets the external ID field for a chunk of records
     * @param chunk Records to get external ID field for
     * @return Schema.SObjectField The external ID field
     */
    private Schema.SObjectField getExternalIdFieldForChunk(List<SObject> chunk) {
        if (String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert operation.');
        }
        
        Schema.SObjectType objType = chunk[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        
        if (!fieldsMap.containsKey(externalIdField)) {
            throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
        }
        
        return fieldsMap.get(externalIdField);
    }
    
    private void guard_ValidateUpsertFields(List<SObject> chunk) {
        if (String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert.');
        }
    
        Schema.SObjectType objType = chunk[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
    
        if (!fieldsMap.containsKey(externalIdField)) {
            throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
        }
    }

    private void runHooks(List<SObject> chunk, Boolean isBefore) {
        List<Hook> hooks = new List<Hook>();
        
        if (isBefore) {
            if (operation == DmlUtility.Operation.DO_INSERT) hooks = beforeInsertHooks;
            if (operation == DmlUtility.Operation.DO_UPDATE) hooks = beforeUpdateHooks;
            if (operation == DmlUtility.Operation.DO_DELETE) hooks = beforeDeleteHooks;
            if (operation == DmlUtility.Operation.DO_UPSERT) hooks = beforeUpsertHooks;
        } else {
            if (operation == DmlUtility.Operation.DO_INSERT) hooks = afterInsertHooks;
            if (operation == DmlUtility.Operation.DO_UPDATE) hooks = afterUpdateHooks;
            if (operation == DmlUtility.Operation.DO_DELETE) hooks = afterDeleteHooks;
            if (operation == DmlUtility.Operation.DO_UPSERT) hooks = afterUpsertHooks;
        }
    
        for (Hook h : hooks) {
            try {
                h.run(chunk, context);
            } catch (Exception e) {
                if (suppressHookErrors) {
                    context.suppressedHookFailureCount += 1;
                    String errorMsg = 'Suppressed hook exception during '
                        + (isBefore ? 'before' : 'after') + ' ' + String.valueOf(operation)
                        + ' hook: ' + e.getMessage();
                
                    System.debug(LoggingLevel.WARN, errorMsg);
                
                    context.log(errorMsg); // logs via DmlUtilityContext.log()
                
                    for (SObject rec : chunk) {
                        for (HookErrorCallback cb : hookErrorCallbacks) {
                            cb.onHookError(rec, context, e);
                        }
                    }
                    continue;
                } else {
                    throw new HookExecutionException('Hook failed: ' + e.getMessage(), e);
                }
            }
        }
    }


    private void validate(List<SObject> chunk) {
        for (Validator v : validators) v.validate(chunk);
    }

    private void routeResults(List<DmlResult> results) {
        for (DmlResult res : results) {
            if (res.success) {
                for (ResultCallback cb : successCallbacks) cb.handle(res.record, context, res.saveResult);
            } else {
                for (ResultCallback cb : failureCallbacks) cb.handle(res.record, context, res.getFirstError());
            }
        }
    }

    private void handleFailureCallbacks(List<SObject> chunk, Exception ex) {
        for (SObject rec : chunk) {
            for (ResultCallback cb : failureCallbacks) {
                cb.handle(rec, context, ex);
            }
        }
    }

    @TestVisible
    private List<List<SObject>> split(List<SObject> input) {
        List<List<SObject>> parts = new List<List<SObject>>();
        for (Integer i = 0; i < input.size(); i += chunkSize) {
            Integer toIndex = (i + chunkSize < input.size()) ? i + chunkSize : input.size();
            List<SObject> chunk = new List<SObject>();
            for (Integer j = i; j < toIndex; j++) {
                chunk.add(input[j]);
            }
            parts.add(chunk);
        }
        return parts;
    }


    public DmlUtility cloneWith(List<SObject> newRecords, Integer retryLeft, Integer attempt) {
        List<SObject> clonedRecords = new List<SObject>();
        for (SObject rec : newRecords) {
            clonedRecords.add(rec.clone(false, true, true, true));
        }
        DmlUtility cloned = new DmlUtility()
            .setRecords(clonedRecords)
            .setOperation(operation)
            .setExternalId(externalIdField)
            // .runAsync() This forces all clones to run async!
            .withMaxRetry(maxRetry)
            // .withMaxRetry(retryLeft)
            .setAttempt(attempt)
            .copyHooksAndCallbacks(this);
        cloned.retryAttemptsLeft = retryLeft;
        
        if (this.isAsync) {
            cloned.runAsync();
        }
        
        if (this.isLightweight) {
            cloned.enableLightweightMode();
        }
        return cloned;
    }

    public DmlUtility setChunkSize(Integer size) {
        this.chunkSize = size;
        return this;
    }

    public DmlUtility setAttempt(Integer attempt) {
        this.currentAttempt = attempt;
        return this;
    }

    private DmlUtility copyHooksAndCallbacks(DmlUtility src) {
        this.validators.addAll(src.validators);
        this.successCallbacks.addAll(src.successCallbacks);
        this.failureCallbacks.addAll(src.failureCallbacks);
        this.onFailureHooks.addAll(src.onFailureHooks);
        this.hookErrorCallbacks.addAll(src.hookErrorCallbacks);

        this.beforeInsertHooks.addAll(src.beforeInsertHooks);
        this.beforeUpdateHooks.addAll(src.beforeUpdateHooks);
        this.beforeDeleteHooks.addAll(src.beforeDeleteHooks);
        this.beforeUpsertHooks.addAll(src.beforeUpsertHooks);
        
        this.afterInsertHooks.addAll(src.afterInsertHooks);
        this.afterUpdateHooks.addAll(src.afterUpdateHooks);
        this.afterDeleteHooks.addAll(src.afterDeleteHooks);
        this.afterUpsertHooks.addAll(src.afterUpsertHooks);
        return this;
    }

    // Interfaces and DTOs
    public interface Hook { void run(List<SObject> records, DmlUtilityContext ctx); }
    public interface Validator { void validate(List<SObject> records); }
    public interface HookErrorCallback { void onHookError(SObject record, DmlUtilityContext ctx, Exception ex); }
    public interface LightweightErrorCallback { void onError(List<SObject> failedChunk, Exception ex); }
    public interface DmlOperationCallback { void execute(); }
    public interface ResultCallback {
        void handle(SObject record, DmlUtilityContext ctx, Object resultOrError);
    }
    public interface OnFailureHook {
        void onFailure(List<SObject> failed, DmlUtilityContext ctx, Exception ex);
    }

    public class HookContext {
        public Operation operation;
        public Boolean isBefore;
        public HookContext(Operation op, Boolean isBefore) {
            this.operation = op;
            this.isBefore = isBefore;
        }
    }

    public class DmlUtilityContext {
        public Operation operation;
        public String externalIdField;
        public Integer totalRetries;
        public Integer retryAttempt;
        
        // Logging-related tracking fields
        public Boolean isLightweight = false;
        public Boolean partialRetry = false;
        public Integer failedRecordCount = 0;
        public Integer suppressedHookFailureCount = 0;
        public Integer lightweightFailureCount = 0;
        
        public String sObjectType;
        public String operations;
        public Integer recordCount;
        public Boolean success = false;
        public Boolean partialRetryEnabled = true;
        public DateTime executionTime;
        public String firstErrorMessage;
        public String logDetails = '';
        
        public DmlUtilityContext() {}
        
        // Internal log collection
        private List<String> logLines = new List<String>();

        public DmlUtilityContext(Operation op, String ext, Integer total, Integer attempt) {
            this.operation = op;
            this.externalIdField = ext;
            this.totalRetries = total;
            this.retryAttempt = attempt;
        }
        
        public void log(String message) {
            logDetails += DateTime.now().format() + ' - ' + message + '\n';
        }
    
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
        
        //for bulk logging
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
        
    }
    
    public static void runWithRetries(DmlOperationCallback callback, DmlUtilityContext context, Integer maxRetries) {
        Exception lastException;
        for (Integer i = 0; i <= maxRetries; i++) {
            try {
                context.retryAttempt = i;
                callback.execute();
                context.log('DML operation successful on attempt #' + i);
                return;
            } catch (Exception ex) {
                lastException = ex;
                context.failedRecordCount++;
                context.log('Attempt #' + i + ' failed: ' + ex.getMessage());
                if (i == maxRetries) {
                    throw ex;
                }
            }
        }
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
            this.record = record; this.success = true; this.saveResult = res;
        }
        public DmlResult(SObject record, Database.DeleteResult res) {
            this.record = record; this.success = true; this.deleteResult = res;
        }
        public DmlResult(SObject record, Database.UpsertResult res) {
            this.record = record; this.success = true; this.upsertResult = res;
        }
        public DmlResult(SObject record, List<Database.Error> errors) {
            this.record = record; this.success = false; this.errors = errors;
        }
        public Exception getFirstError() {
            return (!errors.isEmpty()) ? new DmlException(errors[0].getMessage()) : new DmlException('Unknown failure');
        }
    }

    public class HookExecutionException extends Exception {}
    public class DmlException extends Exception {}
}