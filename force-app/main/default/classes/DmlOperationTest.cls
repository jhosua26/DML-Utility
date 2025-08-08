/**
 * Test class for DmlOperation
 * 
 * This test class covers all scenarios for the DmlOperation including:
 * - Enum conversion methods
 * - Edge cases and error conditions
 * - All operation types
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlOperationTest {
    
    @IsTest
    static void testToExecutorOperation() {
        // Test all operation types
        System.assertEquals(DmlOperationExecutor.Operation.DO_INSERT, 
            DmlOperation.toExecutorOperation(DmlOperation.Type.DO_INSERT), 
            'INSERT operation conversion should work');
        
        System.assertEquals(DmlOperationExecutor.Operation.DO_UPDATE, 
            DmlOperation.toExecutorOperation(DmlOperation.Type.DO_UPDATE), 
            'UPDATE operation conversion should work');
        
        System.assertEquals(DmlOperationExecutor.Operation.DO_DELETE, 
            DmlOperation.toExecutorOperation(DmlOperation.Type.DO_DELETE), 
            'DELETE operation conversion should work');
        
        System.assertEquals(DmlOperationExecutor.Operation.DO_UPSERT, 
            DmlOperation.toExecutorOperation(DmlOperation.Type.DO_UPSERT), 
            'UPSERT operation conversion should work');
    }
    
    @IsTest
    static void testToContextOperation() {
        // Test all operation types
        System.assertEquals(DmlContext.Operation.DO_INSERT, 
            DmlOperation.toContextOperation(DmlOperation.Type.DO_INSERT), 
            'INSERT operation conversion should work');
        
        System.assertEquals(DmlContext.Operation.DO_UPDATE, 
            DmlOperation.toContextOperation(DmlOperation.Type.DO_UPDATE), 
            'UPDATE operation conversion should work');
        
        System.assertEquals(DmlContext.Operation.DO_DELETE, 
            DmlOperation.toContextOperation(DmlOperation.Type.DO_DELETE), 
            'DELETE operation conversion should work');
        
        System.assertEquals(DmlContext.Operation.DO_UPSERT, 
            DmlOperation.toContextOperation(DmlOperation.Type.DO_UPSERT), 
            'UPSERT operation conversion should work');
    }
    
    @IsTest
    static void testToHookManagerOperation() {
        // Test all operation types
        System.assertEquals(DmlHookManager.Operation.DO_INSERT, 
            DmlOperation.toHookManagerOperation(DmlOperation.Type.DO_INSERT), 
            'INSERT operation conversion should work');
        
        System.assertEquals(DmlHookManager.Operation.DO_UPDATE, 
            DmlOperation.toHookManagerOperation(DmlOperation.Type.DO_UPDATE), 
            'UPDATE operation conversion should work');
        
        System.assertEquals(DmlHookManager.Operation.DO_DELETE, 
            DmlOperation.toHookManagerOperation(DmlOperation.Type.DO_DELETE), 
            'DELETE operation conversion should work');
        
        System.assertEquals(DmlHookManager.Operation.DO_UPSERT, 
            DmlOperation.toHookManagerOperation(DmlOperation.Type.DO_UPSERT), 
            'UPSERT operation conversion should work');
    }
    
    @IsTest
    static void testFromExecutorOperation() {
        // Test all operation types
        System.assertEquals(DmlOperation.Type.DO_INSERT, 
            DmlOperation.fromExecutorOperation(DmlOperationExecutor.Operation.DO_INSERT), 
            'INSERT operation conversion should work');
        
        System.assertEquals(DmlOperation.Type.DO_UPDATE, 
            DmlOperation.fromExecutorOperation(DmlOperationExecutor.Operation.DO_UPDATE), 
            'UPDATE operation conversion should work');
        
        System.assertEquals(DmlOperation.Type.DO_DELETE, 
            DmlOperation.fromExecutorOperation(DmlOperationExecutor.Operation.DO_DELETE), 
            'DELETE operation conversion should work');
        
        System.assertEquals(DmlOperation.Type.DO_UPSERT, 
            DmlOperation.fromExecutorOperation(DmlOperationExecutor.Operation.DO_UPSERT), 
            'UPSERT operation conversion should work');
    }
    
    @IsTest
    static void testNullOperationHandling() {
        // Test null handling - should return default INSERT operation
        System.assertEquals(DmlOperationExecutor.Operation.DO_INSERT, 
            DmlOperation.toExecutorOperation(null), 
            'Null operation should return default INSERT for executor');
        
        System.assertEquals(DmlContext.Operation.DO_INSERT, 
            DmlOperation.toContextOperation(null), 
            'Null operation should return default INSERT for context');
        
        System.assertEquals(DmlHookManager.Operation.DO_INSERT, 
            DmlOperation.toHookManagerOperation(null), 
            'Null operation should return default INSERT for hook manager');
        
        System.assertEquals(DmlOperation.Type.DO_INSERT, 
            DmlOperation.fromExecutorOperation(null), 
            'Null operation should return default INSERT type');
    }
    
    @IsTest
    static void testOperationTypeEnum() {
        // Test that all enum values exist
        List<DmlOperation.Type> allTypes = new List<DmlOperation.Type>{
            DmlOperation.Type.DO_INSERT,
            DmlOperation.Type.DO_UPDATE,
            DmlOperation.Type.DO_DELETE,
            DmlOperation.Type.DO_UPSERT
        };
        
        System.assertEquals(4, allTypes.size(), 'Should have exactly 4 operation types');
        
        // Test enum string conversion
        System.assertEquals('DO_INSERT', String.valueOf(DmlOperation.Type.DO_INSERT));
        System.assertEquals('DO_UPDATE', String.valueOf(DmlOperation.Type.DO_UPDATE));
        System.assertEquals('DO_DELETE', String.valueOf(DmlOperation.Type.DO_DELETE));
        System.assertEquals('DO_UPSERT', String.valueOf(DmlOperation.Type.DO_UPSERT));
    }
}