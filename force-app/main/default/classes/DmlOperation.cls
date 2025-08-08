/**
 * DmlOperation - Centralized enum for DML operations
 * 
 * This class provides a centralized definition of DML operations
 * to eliminate duplication across the framework.
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlOperation {
    
    public enum Type {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
    }
    
    /**
     * Converts DmlOperation.Type to DmlOperationExecutor.Operation
     * @param operationType The operation type to convert
     * @return DmlOperationExecutor.Operation The converted operation
     */
    public static DmlOperationExecutor.Operation toExecutorOperation(Type operationType) {
        if (operationType == Type.DO_INSERT) return DmlOperationExecutor.Operation.DO_INSERT;
        if (operationType == Type.DO_UPDATE) return DmlOperationExecutor.Operation.DO_UPDATE;
        if (operationType == Type.DO_DELETE) return DmlOperationExecutor.Operation.DO_DELETE;
        if (operationType == Type.DO_UPSERT) return DmlOperationExecutor.Operation.DO_UPSERT;
        return DmlOperationExecutor.Operation.DO_INSERT; // Default
    }
    
    /**
     * Converts DmlOperation.Type to DmlContext.Operation
     * @param operationType The operation type to convert
     * @return DmlContext.Operation The converted operation
     */
    public static DmlContext.Operation toContextOperation(Type operationType) {
        if (operationType == Type.DO_INSERT) return DmlContext.Operation.DO_INSERT;
        if (operationType == Type.DO_UPDATE) return DmlContext.Operation.DO_UPDATE;
        if (operationType == Type.DO_DELETE) return DmlContext.Operation.DO_DELETE;
        if (operationType == Type.DO_UPSERT) return DmlContext.Operation.DO_UPSERT;
        return DmlContext.Operation.DO_INSERT; // Default
    }
    
    /**
     * Converts DmlOperation.Type to DmlHookManager.Operation
     * @param operationType The operation type to convert
     * @return DmlHookManager.Operation The converted operation
     */
    public static DmlHookManager.Operation toHookManagerOperation(Type operationType) {
        if (operationType == Type.DO_INSERT) return DmlHookManager.Operation.DO_INSERT;
        if (operationType == Type.DO_UPDATE) return DmlHookManager.Operation.DO_UPDATE;
        if (operationType == Type.DO_DELETE) return DmlHookManager.Operation.DO_DELETE;
        if (operationType == Type.DO_UPSERT) return DmlHookManager.Operation.DO_UPSERT;
        return DmlHookManager.Operation.DO_INSERT; // Default
    }
    
    /**
     * Converts from DmlOperationExecutor.Operation to DmlOperation.Type
     * @param operation The operation to convert
     * @return Type The converted operation type
     */
    public static Type fromExecutorOperation(DmlOperationExecutor.Operation operation) {
        if (operation == DmlOperationExecutor.Operation.DO_INSERT) return Type.DO_INSERT;
        if (operation == DmlOperationExecutor.Operation.DO_UPDATE) return Type.DO_UPDATE;
        if (operation == DmlOperationExecutor.Operation.DO_DELETE) return Type.DO_DELETE;
        if (operation == DmlOperationExecutor.Operation.DO_UPSERT) return Type.DO_UPSERT;
        return Type.DO_INSERT; // Default
    }
}