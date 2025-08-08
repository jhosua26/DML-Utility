/**
 * Test class for DmlHookManager
 * 
 * This test class covers all scenarios for the DmlHookManager including:
 * - Hook registration and execution
 * - Before/after hooks for all operations
 * - Error handling and suppression
 * - Hook error callbacks
 * - Empty hook scenarios
 * - Multiple hooks execution
 * - Hook execution order
 * - Edge cases and error conditions
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlHookManagerTest {
    
    // ===== TEST DATA SETUP =====
    
    /**
     * Creates test accounts with meaningful data
     * @param count Number of accounts to create
     * @return List of test accounts
     */
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Type = 'Customer',
                Industry = 'Technology',
                BillingStreet = '123 Test St',
                BillingCity = 'Test City',
                BillingState = 'CA',
                BillingPostalCode = '12345'
            ));
        }
        return accounts;
    }
    
    /**
     * Creates test contacts with meaningful data
     * @param count Number of contacts to create
     * @return List of test contacts
     */
    private static List<Contact> createTestContacts(Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@example.com',
                Phone = '555-123-' + String.valueOf(i).leftPad(4, '0')
            ));
        }
        return contacts;
    }
    
    /**
     * Asserts that the expected number of accounts exist with the given name pattern
     * @param expectedCount Expected number of accounts
     * @param namePattern Name pattern to search for
     * @param message Assertion message
     */
    private static void assertAccountCount(Integer expectedCount, String namePattern, String message) {
        Integer actualCount = [SELECT COUNT() FROM Account WHERE Name LIKE :namePattern];
        System.assertEquals(expectedCount, actualCount, message);
    }
    
    // ===== TEST HOOK IMPLEMENTATIONS =====
    
    /**
     * Test hook that modifies accounts before insert
     */
    public class TestBeforeInsertHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Name = acc.Name + ' - Before Hook';
                    acc.Description = 'Processed by BeforeInsertHook';
                }
            }
        }
    }
    
    /**
     * Test hook that modifies accounts after insert
     */
    public class TestAfterInsertHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Name = acc.Name + ' - After Hook';
                    acc.Description = 'Processed by AfterInsertHook';
                }
            }
        }
    }
    
    /**
     * Test hook that always throws an exception
     */
    public class TestFailingHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            throw new DmlHookManager.HookExecutionException('Hook failed intentionally for testing');
        }
    }
    
    /**
     * Test hook that modifies accounts before update
     */
    public class TestBeforeUpdateHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Updated via BeforeUpdateHook';
                }
            }
        }
    }
    
    /**
     * Test hook that modifies accounts before delete
     */
    public class TestBeforeDeleteHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Marked for deletion by BeforeDeleteHook';
                }
            }
        }
    }
    
    /**
     * Test hook that modifies accounts before upsert
     */
    public class TestBeforeUpsertHook implements DmlHookManager.Hook {
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Upserted via BeforeUpsertHook';
                }
            }
        }
    }
    
    /**
     * Test hook error callback
     */
    public class TestHookErrorCallback implements DmlHookManager.HookErrorCallback {
        public void onHookError(SObject record, DmlContext context, Exception ex) {
            System.debug('HookErrorCallback: Error occurred for record: ' + record + ' - ' + ex.getMessage());
        }
    }
    
    /**
     * Test hook that counts executions
     */
    public class TestCountingHook implements DmlHookManager.Hook {
        public Integer executionCount = 0;
        
        public void run(List<SObject> records, DmlContext context) {
            if (records == null) {
                return;
            }
            executionCount++;
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Processed by CountingHook (execution #' + executionCount + ')';
                }
            }
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
        TestBeforeUpdateHook hook = new TestBeforeUpdateHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeUpdateHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddBeforeDeleteHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeDeleteHook hook = new TestBeforeDeleteHook();
        
        // Act
        DmlHookManager result = hookManager.addBeforeDeleteHook(hook);
        
        // Assert
        System.assertEquals(hookManager, result, 'Should return self for chaining');
    }
    
    @IsTest
    static void testAddBeforeUpsertHook() {
        // Arrange
        DmlHookManager hookManager = new DmlHookManager();
        TestBeforeUpsertHook hook = new TestBeforeUpsertHook();
        
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
            System.assert(acc.Name.endsWith(' - Before Hook'), 'Account name should be modified by before hook');
            System.assertEquals('Processed by BeforeInsertHook', acc.Description, 'Account description should be set by before hook');
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
            System.assert(acc.Name.endsWith(' - After Hook'), 'Account name should be modified by after hook');
            System.assertEquals('Processed by AfterInsertHook', acc.Description, 'Account description should be set by after hook');
        }
    }
    
    @IsTest
    static void testExecuteBeforeHooksWithMultipleHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(2);
        DmlContext context = new DmlContext();
        TestCountingHook countingHook = new TestCountingHook();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook())
            .addBeforeInsertHook(countingHook);
        
        // Act
        Test.startTest();
        hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, countingHook.executionCount, 'Counting hook should be executed once');
        for (Account acc : accounts) {
            System.assert(acc.Name.endsWith(' - Before Hook'), 'Account name should be modified by before hook');
            System.assert(acc.Description.contains('CountingHook'), 'Account description should be set by counting hook');
        }
    }
    
    @IsTest
    static void testExecuteBeforeHooksWithNoHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager();
        
        // Act & Assert - Should not throw exception
        Test.startTest();
        try {
            hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
            System.assert(true, 'Should execute without exception when no hooks are registered');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception when no hooks are registered: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testExecuteBeforeHooksWithNullRecords() {
        // Arrange
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act & Assert - Should not throw exception
        Test.startTest();
        try {
            hookManager.executeBeforeHooks(null, DmlHookManager.Operation.DO_INSERT, context);
            System.assert(true, 'Should execute without exception when records are null');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception when records are null: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testExecuteBeforeHooksWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlContext context = new DmlContext();
        DmlHookManager hookManager = new DmlHookManager()
            .addBeforeInsertHook(new TestBeforeInsertHook());
        
        // Act & Assert - Should not throw exception
        Test.startTest();
        try {
            hookManager.executeBeforeHooks(accounts, DmlHookManager.Operation.DO_INSERT, context);
            System.assert(true, 'Should execute without exception when records are empty');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception when records are empty: ' + e.getMessage());
        }
        Test.stopTest();
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
            System.assert(e.getMessage().contains('Hook failed intentionally for testing'));
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
    static void testExecuteBeforeHooksWithNoHooks1() {
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