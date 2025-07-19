public class DmlUtility implements Queueable {
    public enum Operation {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
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
    public DmlUtility addBeforeUpsertHook(Hook h) { beforeUpsertHooks.add(h); return this; }
    public DmlUtility addAfterInsertHook(Hook h) { afterInsertHooks.add(h); return this; }
    public DmlUtility addAfterUpdateHook(Hook h) { afterUpdateHooks.add(h); return this; }
    public DmlUtility addAfterDeleteHook(Hook h) { afterDeleteHooks.add(h); return this; }
    public DmlUtility addAfterUpsertHook(Hook h) { afterUpsertHooks.add(h); return this; }

    // Entry point
    public void runNow() {
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

    private void doExecute() {
        if (records == null || records.isEmpty()) {
            throw new IllegalArgumentException('You must call setRecords() before execution.');
        }
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

        if (operation == DmlUtility.Operation.DO_INSERT) {
            Database.SaveResult[] saveResults = Database.insert(chunk, false);
            for (Integer i = 0; i < chunk.size(); i++) {
                SObject rec = chunk[i];
                Database.SaveResult sr = saveResults[i];
                results.add(sr.isSuccess() ? new DmlResult(rec, sr) : new DmlResult(rec, sr.getErrors()));
            }
        } else if (operation == DmlUtility.Operation.DO_UPDATE) {
            Database.SaveResult[] saveResults = Database.update(chunk, false);
            for (Integer i = 0; i < chunk.size(); i++) {
                SObject rec = chunk[i];
                Database.SaveResult sr = saveResults[i];
                results.add(sr.isSuccess() ? new DmlResult(rec, sr) : new DmlResult(rec, sr.getErrors()));
            }
        } else if (operation == DmlUtility.Operation.DO_DELETE) {
            Database.DeleteResult[] delResults = Database.delete(chunk, false);
            for (Integer i = 0; i < chunk.size(); i++) {
                SObject rec = chunk[i];
                Database.DeleteResult dr = delResults[i];
                results.add(dr.isSuccess() ? new DmlResult(rec, dr) : new DmlResult(rec, dr.getErrors()));
            }
        } else if (operation == DmlUtility.Operation.DO_UPSERT) {
            if (String.isBlank(externalIdField)) throw new IllegalArgumentException('Missing External ID for upsert.');
            Schema.SObjectType objType = ((SObject)chunk[0]).getSObjectType();
            Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
            if (!fieldsMap.containsKey(externalIdField)) {
                throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
            }
            Schema.SObjectField extIdField = fieldsMap.get(externalIdField);
            Database.UpsertResult[] upsertResults = Database.upsert(chunk, extIdField, false);
            for (Integer i = 0; i < chunk.size(); i++) {
                SObject rec = chunk[i];
                Database.UpsertResult ur = upsertResults[i];
                results.add(ur.isSuccess() ? new DmlResult(rec, ur) : new DmlResult(rec, ur.getErrors()));
            }
        }

        return results;
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
            Integer toIndex = (i + chunkSize < input.size()) ? i + chunkSize : input.size();
            List<SObject> chunk = new List<SObject>();
            for (Integer j = i; j < toIndex; j++) {
                chunk.add(input[j]);
            }
            parts.add(chunk);
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
            .withMaxRetry(maxRetry)
            // .withMaxRetry(retryLeft)
            .setAttempt(attempt)
            .copyHooksAndCallbacks(this);
        cloned.retryAttemptsLeft = retryLeft;
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
    public interface Hook { void run(List<SObject> records, DmlUtilityContext ctx); }
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

