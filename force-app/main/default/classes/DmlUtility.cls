
public class DmlUtility implements Queueable {
    public enum Operation {
        isInsert,
        isUpdate,
        isUpsert,
        isDelete
    }

    private List<SObject> records;
    private Operation operation;
    private String externalIdField;
    private Integer chunkSize = 100;

    private Boolean isAsync = false;
    private Boolean isLightweight = false;

    private Integer maxRetry = 0;
    private Integer retryAttemptsLeft = 0;
    private Integer currentAttempt = 0;

    private DmlUtilityContext context;
    private List<DmlResult> lastResults = new List<DmlResult>();

    private List<Validator> validators = new List<Validator>();
    private List<ResultCallback> successCallbacks = new List<ResultCallback>();
    private List<ResultCallback> failureCallbacks = new List<ResultCallback>();
    private List<OnFailureHook> onFailureHooks = new List<OnFailureHook>();

    private List<Hook> beforeInsertHooks = new List<Hook>();
    private List<Hook> beforeUpdateHooks = new List<Hook>();
    private List<Hook> beforeDeleteHooks = new List<Hook>();
    private List<Hook> beforeUpsertHooks = new List<Hook>();

    private List<Hook> afterInsertHooks  = new List<Hook>();
    private List<Hook> afterUpdateHooks  = new List<Hook>();
    private List<Hook> afterDeleteHooks  = new List<Hook>();
    private List<Hook> afterUpsertHooks = new List<Hook>();

    // Builder methods
    public DmlUtility setRecords(List<SObject> records) { this.records = records; return this; }
    public DmlUtility setOperation(Operation op) { this.operation = op; return this; }
    public DmlUtility setExternalId(String field) { this.externalIdField = field; return this; }
    public DmlUtility runAsync() { this.isAsync = true; return this; }
    public DmlUtility enableLightweightMode() { this.isLightweight = true; return this; }
    public DmlUtility withMaxRetry(Integer count) { this.maxRetry = count; this.retryAttemptsLeft = count; return this; }

    // Hook additions
    public DmlUtility addValidator(Validator v) { validators.add(v); return this; }
    public DmlUtility addSuccessCallback(ResultCallback cb) { successCallbacks.add(cb); return this; }
    public DmlUtility addFailureCallback(ResultCallback cb) { failureCallbacks.add(cb); return this; }
    public DmlUtility addOnFailureHook(OnFailureHook hook) { onFailureHooks.add(hook); return this; }

    public DmlUtility addBeforeInsertHook(Hook h) { beforeInsertHooks.add(h); return this; }
    public DmlUtility addBeforeUpdateHook(Hook h) { beforeUpdateHooks.add(h); return this; }
    public DmlUtility addBeforeDeleteHook(Hook h) { beforeDeleteHooks.add(h); return this; }
    public DmlUtility addAfterInsertHook(Hook h) { afterInsertHooks.add(h); return this; }
    public DmlUtility addAfterUpdateHook(Hook h) { afterUpdateHooks.add(h); return this; }
    public DmlUtility addAfterDeleteHook(Hook h) { afterDeleteHooks.add(h); return this; }

    // Entry point
    public void execute() {
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
            execute();
        }
    }

    private void doExecute() {
        context = new DmlUtilityContext(operation, externalIdField, maxRetry, currentAttempt);
        for (List<SObject> chunk : split(records)) {
            try {
                processChunk(chunk);
            } catch (Exception ex) {
                if (retryAttemptsLeft > 0) {
                    new RetryHandler().scheduleRetry(this, chunk, retryAttemptsLeft - 1, currentAttempt + 1);
                } else {
                    handleFailureCallbacks(chunk, ex);
                    for (OnFailureHook hook : onFailureHooks) {
                        hook.onFailure(chunk, context, ex);
                    }
                }
            }
        }
    }

    private void processChunk(List<SObject> chunk) {
        runHooks(chunk, true);
        validate(chunk);

        List<DmlResult> results = performDml(chunk);
        lastResults.addAll(results);

        runHooks(chunk, false);
        routeResults(results);
    }

    private void executeLightweight() {
        for (List<SObject> chunk : split(records)) {
            try {
                performDml(chunk); // skip hooks and validation
            } catch (Exception e) {
                // lightweight: swallow or log
            }
        }
    }

    private List<DmlResult> performDml(List<SObject> chunk) {
        List<DmlResult> results = new List<DmlResult>();
        Database.SaveResult[] saveResults;

        switch on operation {
            when Operation.isInse {
                saveResults = Database.insert(chunk, false);
            }
            when Operation.isUpdate {
                saveResults = Database.update(chunk, false);
            }
            when Operation.isDelete {
                saveResults = Database.delete(chunk, false);
            }
            when Operation.isUpsert {
                if (String.isBlank(externalIdField)) throw new IllegalArgumentException('Missing External ID for upsert.');
                Schema.SObjectType objType = ((SObject)chunk[0]).getSObjectType();
                Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
                if (!fieldsMap.containsKey(externalIdField)) {
                    throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
                }
                Schema.SObjectField extIdField = fieldsMap.get(externalIdField);
                saveResults = Database.upsert(chunk, extIdField, false);
            }
        }

        for (Integer i = 0; i < chunk.size(); i++) {
            SObject rec = chunk[i];
            Database.SaveResult sr = saveResults[i];
            results.add(sr.isSuccess() ? DmlResult.success(rec, sr) : DmlResult.failure(rec, sr.getErrors()));
        }
        return results;
    }

    private void runHooks(List<SObject> chunk, Boolean isBefore) {
        List<Hook> hooks = new List<Hook>();
        if (isBefore) {
            if (operation == Operation.isInsert) hooks = beforeInsertHooks;
            if (operation == Operation.isUpdate) hooks = beforeUpdateHooks;
            if (operation == Operation.isDelete) hooks = beforeDeleteHooks;
            if (operation == Operation.isUpsert) hooks = beforeUpsertHooks;
        } else {
            if (operation == Operation.isInsert) hooks = afterInsertHooks;
            if (operation == Operation.isUpdate) hooks = afterUpdateHooks;
            if (operation == Operation.isDelete) hooks = afterDeleteHooks;
            if (operation == Operation.isUpsert) hooks = afterUpsertHooks;
        }

        for (Hook h : hooks) {
            try {
                h.run(chunk, new HookContext(operation, isBefore));
            } catch (Exception e) {
                throw new HookExecutionException('Hook failed: ' + e.getMessage(), e);
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

    private List<List<SObject>> split(List<SObject> input) {
        List<List<SObject>> parts = new List<List<SObject>>();
        for (Integer i = 0; i < input.size(); i += chunkSize) {
            parts.add(input.subList(i, Math.min(i + chunkSize, input.size())));
        }
        return parts;
    }

    // Retry support
    public class RetryHandler implements Queueable {
        private DmlUtility utility;

        public void scheduleRetry(DmlUtility original, List<SObject> chunk, Integer retryLeft, Integer attempt) {
            this.utility = original.cloneWith(chunk, retryLeft, attempt);
            System.enqueueJob(this);
        }

        public void execute(QueueableContext context) {
            utility.execute(context);
        }
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
            .runAsync()
            .withMaxRetry(retryLeft)
            .setAttempt(attempt)
            .copyHooksAndCallbacks(this);
        if (this.isLightweight) {
            cloned.enableLightweightMode();
        }
        return cloned;
    }

    public DmlUtility setChunkSize(Integer size) {
        this.chunkSize = size;
        return this;
    }

    private DmlUtility setAttempt(Integer attempt) {
        this.currentAttempt = attempt;
        return this;
    }

    private DmlUtility copyHooksAndCallbacks(DmlUtility src) {
        this.validators.addAll(src.validators);
        this.successCallbacks.addAll(src.successCallbacks);
        this.failureCallbacks.addAll(src.failureCallbacks);
        this.onFailureHooks.addAll(src.onFailureHooks);

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
    public interface Hook { void run(List<SObject> records, HookContext ctx); }
    public interface Validator { void validate(List<SObject> records); }
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

        public DmlUtilityContext(Operation op, String ext, Integer total, Integer attempt) {
            this.operation = op;
            this.externalIdField = ext;
            this.totalRetries = total;
            this.retryAttempt = attempt;
        }
    }

    public class DmlResult {
        public SObject record;
        public Boolean success;
        public List<Database.Error> errors = new List<Database.Error>();
        public Database.SaveResult saveResult;

        public static DmlResult success(SObject record, Database.SaveResult res) {
            DmlResult r = new DmlResult();
            r.record = record; r.success = true; r.saveResult = res;
            return r;
        }

        public static DmlResult failure(SObject record, List<Database.Error> errors) {
            DmlResult r = new DmlResult();
            r.record = record; r.success = false; r.errors = errors;
            return r;
        }

        public Exception getFirstError() {
            return (!errors.isEmpty()) ? new Exception(errors[0].getMessage()) : new Exception('Unknown failure');
        }
    }

    public class HookExecutionException extends Exception {}
}