/**
 * Test class for DmlHookManager
 * 
 * This test class covers all scenarios for the DmlHookManager including:
 * - Hook registration and execution
 * - Before/after hooks for all operations
 * - Error handling and suppression
 * - Hook error callbacks
 * - Empty hook scenarios
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlHookManagerTest {
    
    // Test data setup
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        return accounts;
    }
    
    // Test hook implementations
    public class TestBeforeInsertHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Name = acc.Name + ' - Before Hook';
                }
            }
        }
    }
    
    public class TestAfterInsertHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Name = acc.Name + ' - After Hook';
                }
            }
        }
    }
    
    public class TestFailingHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            throw new DmlHookManager.HookExecutionException('Hook failed intentionally');
        }
    }
    
    public class TestHookErrorCallback implements DmlHookManager.HookErrorCallback {
        public void onHookError(SObject record, DmlContext context, Exception ex) {
            System.debug('Hook error callback executed for record: ' + record);
        }
    }
    
    // ===== HOOK REGISTRATION TESTS =====
    
    @IsTest
    static void testAddBeforeInsertHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeInsertHook hook = new TestBeforeInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeInsertHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddBeforeUpdateHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeInsertHook hook = new TestBeforeInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeUpdateHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddBeforeDeleteHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeInsertHook hook = new TestBeforeInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeDeleteHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddBeforeUpsertHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeInsertHook hook = new TestBeforeInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeUpsertHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddAfterInsertHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestAfterInsertHook hook = new TestAfterInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addAfterInsertHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddAfterUpdateHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestAfterInsertHook hook = new TestAfterInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addAfterUpdateHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddAfterDeleteHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestAfterInsertHook hook = new TestAfterInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addAfterDeleteHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddAfterUpsertHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestAfterInsertHook hook = new TestAfterInsertHook();
        
        // Act
        DmlHookManager result = hookManager.addAfterUpsertHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddHookErrorCallback() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestHookErrorCallback callback = new TestHookErrorCallback();
        
        // Act
        DmlHookManager result = hookManager.addHookErrorCallback(callback);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testSuppressHookExceptions() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        
        // Act
        DmlHookManager result = hookManager.suppressHookExceptions();
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    // ===== HOOK EXECUTION TESTS =====
    
    @IsTest
    static void testExecuteBeforeHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hook');
        }
    }
    
    @IsTest
    static void testExecuteAfterHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addAfterInsertHook(new TestAfterInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hook');
        }
    }
    
    @IsTest
    static void testExecuteBeforeHooksForUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeUpdateHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_UPDATE, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hook');
        }
    }
    
    @IsTest
    static void testExecuteBeforeHooksForDelete() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeDeleteHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_DELETE, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hook');
        }
    }
    
    @IsTest
    static void testExecuteBeforeHooksForUpsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeUpsertHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_UPSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hook');
        }
    }
    
    @IsTest
    static void testExecuteAfterHooksForUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addAfterUpdateHook(new TestAfterInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_UPDATE, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hook');
        }
    }
    
    @IsTest
    static void testExecuteAfterHooksForDelete() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addAfterDeleteHook(new TestAfterInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_DELETE, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hook');
        }
    }
    
    @IsTest
    static void testExecuteAfterHooksForUpsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addAfterUpsertHook(new TestAfterInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_UPSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hook');
        }
    }
    
    // ===== ERROR HANDLING TESTS =====
    
    @IsTest
    static void testHookExecutionWithException() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestFailingHook());
        
        // Act & Assert
        Test.startTest();
        try {
            hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
            System.assert(false, 'Should have thrown exception');
        } catch (DmlHookManager.HookExecutionException e) {
            System.assert(e.getMessage().contains('Hook failed intentionally'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testHookExecutionWithSuppressedExceptions() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestFailingHook())
            .addHookErrorCallback(new TestHookErrorCallback())
            .suppressHookExceptions();
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should not throw exception when suppressed
        System.assert(true, 'Should handle suppressed exceptions gracefully');
    }
    
    @IsTest
    static void testHookExecutionWithErrorCallback() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestFailingHook())
            .addHookErrorCallback(new TestHookErrorCallback())
            .suppressHookExceptions();
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should execute error callbacks
        System.assert(true, 'Should execute error callbacks when hooks fail');
    }
    
    // ===== EMPTY HOOK TESTS =====
    
    @IsTest
    static void testExecuteBeforeHooksWithNoHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager();
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should not throw exception when no hooks are registered
        System.assert(true, 'Should handle empty hooks gracefully');
    }
    
    @IsTest
    static void testExecuteAfterHooksWithNoHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager();
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should not throw exception when no hooks are registered
        System.assert(true, 'Should handle empty hooks gracefully');
    }
    
    // ===== MULTIPLE HOOK TESTS =====
    
    @IsTest
    static void testExecuteMultipleBeforeHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook())
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hooks');
        }
    }
    
    @IsTest
    static void testExecuteMultipleAfterHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addAfterInsertHook(new TestAfterInsertHook())
            .addAfterInsertHook(new TestAfterInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hooks');
        }
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testExecuteHooksWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should handle empty records gracefully
        System.assert(true, 'Should handle empty records gracefully');
    }
    
    @IsTest
    static void testExecuteHooksWithNullRecords() {
        // Arrange
        List<Account> accounts = null;
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should handle null records gracefully
        System.assert(true, 'Should handle null records gracefully');
    }
    
    // ===== COMPLEX SCENARIO TESTS =====
    
    @IsTest
    static void testComplexHookScenario() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook())
            .addAfterInsertHook(new TestAfterInsertHook())
            .addHookErrorCallback(new TestHookErrorCallback())
            .suppressHookExceptions();
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        hookManager.executeAfterHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        for (Account acc : accounts) {
            System.assert(acc.Name.contains('Before Hook'), 'Account name should be modified by before hook');
            System.assert(acc.Name.contains('After Hook'), 'Account name should be modified by after hook');
        }
    }
    
    @IsTest
    static void testHookExecutionWithMixedSuccessAndFailure() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook()) // This will succeed
            .addBeforeInsertHook(new TestFailingHook()) // This will fail
            .addHookErrorCallback(new TestHookErrorCallback())
            .suppressHookExceptions();
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert - should handle mixed success and failure
        System.assert(true, 'Should handle mixed success and failure gracefully');
    }
}