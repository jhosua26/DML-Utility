/**
 * DmlHookManager - Manages hooks for DML operations
 * 
 * This class is responsible for managing and executing before/after hooks
 * for DML operations with proper error handling and suppression.
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlHookManager {
    
    public enum Operation {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
    }
    
    private List<Hook> beforeInsertHooks = new List<Hook>();
    private List<Hook> beforeUpdateHooks = new List<Hook>();
    private List<Hook> beforeDeleteHooks = new List<Hook>();
    private List<Hook> beforeUpsertHooks = new List<Hook>();
    
    private List<Hook> afterInsertHooks = new List<Hook>();
    private List<Hook> afterUpdateHooks = new List<Hook>();
    private List<Hook> afterDeleteHooks = new List<Hook>();
    private List<Hook> afterUpsertHooks = new List<Hook>();
    
    private List<HookErrorCallback> hookErrorCallbacks = new List<HookErrorCallback>();
    private Boolean suppressHookErrors = false;
    
    /**
     * Adds a before insert hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addBeforeInsertHook(Hook hook) {
        beforeInsertHooks.add(hook);
        return this;
    }
    
    /**
     * Adds a before update hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addBeforeUpdateHook(Hook hook) {
        beforeUpdateHooks.add(hook);
        return this;
    }
    
    /**
     * Adds a before delete hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addBeforeDeleteHook(Hook hook) {
        beforeDeleteHooks.add(hook);
        return this;
    }
    
    /**
     * Adds a before upsert hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addBeforeUpsertHook(Hook hook) {
        beforeUpsertHooks.add(hook);
        return this;
    }
    
    /**
     * Adds an after insert hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addAfterInsertHook(Hook hook) {
        afterInsertHooks.add(hook);
        return this;
    }
    
    /**
     * Adds an after update hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addAfterUpdateHook(Hook hook) {
        afterUpdateHooks.add(hook);
        return this;
    }
    
    /**
     * Adds an after delete hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addAfterDeleteHook(Hook hook) {
        afterDeleteHooks.add(hook);
        return this;
    }
    
    /**
     * Adds an after upsert hook
     * @param hook The hook to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addAfterUpsertHook(Hook hook) {
        afterUpsertHooks.add(hook);
        return this;
    }
    
    /**
     * Adds a hook error callback
     * @param callback The callback to add
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager addHookErrorCallback(HookErrorCallback callback) {
        hookErrorCallbacks.add(callback);
        return this;
    }
    
    /**
     * Enables hook error suppression
     * @return DmlHookManager This instance for chaining
     */
    public DmlHookManager suppressHookExceptions() {
        this.suppressHookErrors = true;
        return this;
    }
    
    /**
     * Executes before hooks for the specified operation
     * @param records Records to process
     * @param operation The DML operation
     * @param context The execution context
     */
    public void executeBeforeHooks(List<SObject> records, Operation operation, DmlContext context) {
        List<Hook> hooks = getBeforeHooks(operation);
        executeHooks(hooks, records, context, true);
    }
    
    /**
     * Executes after hooks for the specified operation
     * @param records Records to process
     * @param operation The DML operation
     * @param context The execution context
     */
    public void executeAfterHooks(List<SObject> records, Operation operation, DmlContext context) {
        List<Hook> hooks = getAfterHooks(operation);
        executeHooks(hooks, records, context, false);
    }
    
    /**
     * Gets the appropriate before hooks for the operation
     * @param operation The DML operation
     * @return List<Hook> List of hooks to execute
     */
    private List<Hook> getBeforeHooks(Operation operation) {
        if (operation == DmlHookManager.Operation.DO_INSERT) return beforeInsertHooks;
        if (operation == DmlHookManager.Operation.DO_UPDATE) return beforeUpdateHooks;
        if (operation == DmlHookManager.Operation.DO_DELETE) return beforeDeleteHooks;
        if (operation == DmlHookManager.Operation.DO_UPSERT) return beforeUpsertHooks;
        return new List<Hook>();
    }
    
    /**
     * Gets the appropriate after hooks for the operation
     * @param operation The DML operation
     * @return List<Hook> List of hooks to execute
     */
    private List<Hook> getAfterHooks(Operation operation) {
        if (operation == DmlHookManager.Operation.DO_INSERT) return afterInsertHooks;
        if (operation == DmlHookManager.Operation.DO_UPDATE) return afterUpdateHooks;
        if (operation == DmlHookManager.Operation.DO_DELETE) return afterDeleteHooks;
        if (operation == DmlHookManager.Operation.DO_UPSERT) return afterUpsertHooks;
        return new List<Hook>();
    }
    
    /**
     * Executes a list of hooks with proper error handling
     * @param hooks List of hooks to execute
     * @param records Records to process
     * @param context The execution context
     * @param isBefore Whether these are before hooks
     */
    private void executeHooks(List<Hook> hooks, List<SObject> records, DmlContext context, Boolean isBefore) {
        for (Hook hook : hooks) {
            try {
                hook.run(records, context);
            } catch (Exception e) {
                handleHookError(hook, records, context, e, isBefore);
            }
        }
    }
    
    /**
     * Handles hook execution errors
     * @param hook The hook that failed
     * @param records The records being processed
     * @param context The execution context
     * @param e The exception that occurred
     * @param isBefore Whether this was a before hook
     */
    private void handleHookError(Hook hook, List<SObject> records, DmlContext context, Exception e, Boolean isBefore) {
        if (suppressHookErrors) {
            context.incrementSuppressedHookFailureCount();
            String errorMsg = String.format('Suppressed hook exception during {0} {1} hook: {2}', 
                new List<String>{ isBefore ? 'before' : 'after', context.getOperationType(), e.getMessage() });
            
            System.debug(LoggingLevel.WARN, errorMsg);
            context.log(errorMsg);
            
            // Notify error callbacks
            for (SObject record : records) {
                for (HookErrorCallback callback : hookErrorCallbacks) {
                    callback.onHookError(record, context, e);
                }
            }
        } else {
            throw new HookExecutionException('Hook failed: ' + e.getMessage(), e);
        }
    }
    
    /**
     * Hook interface for DML operations
     */
    public interface Hook {
        void run(List<SObject> records, DmlContext context);
    }
    
    /**
     * Hook error callback interface
     */
    public interface HookErrorCallback {
        void onHookError(SObject record, DmlContext context, Exception ex);
    }
    
    /**
     * Exception thrown when hook execution fails
     */
    public class HookExecutionException extends Exception {}
} 