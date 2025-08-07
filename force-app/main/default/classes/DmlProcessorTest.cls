/**
 * Test class for DmlProcessor
 * 
 * This test class covers all scenarios for the DmlProcessor including:
 * - All DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * - Hook execution (before/after hooks for all operations)
 * - Validation scenarios
 * - Retry logic
 * - Error handling
 * - Lightweight mode
 * - Async processing
 * - Logging functionality
 * - Chunking functionality
 * - Callback mechanisms
 * - Edge cases and error conditions
 * 
 * @author DML Utility Team
 * @version 2.0
 */
@IsTest
public class DmlProcessorTest {
    
    // Test data setup
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        return accounts;
    }
    
    private static List<Contact> createTestContacts(Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(FirstName = 'Test', LastName = 'Contact ' + i));
        }
        return contacts;
    }
    
    // Test hook implementations
    public class TestBeforeInsertHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    if (String.isBlank(acc.Name)) {
                        throw new DmlProcessor.DmlException('Account name is required');
                    }
                }
            }
        }
    }
    
    public class TestBeforeUpdateHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Updated via hook';
                }
            }
        }
    }
    
    public class TestBeforeDeleteHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            // Log deletion attempt
            System.debug('About to delete ' + records.size() + ' records');
        }
    }
    
    public class TestBeforeUpsertHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    acc.Description = 'Upserted via hook';
                }
            }
        }
    }
    
    public class TestAfterInsertHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            System.debug('After insert hook executed for ' + records.size() + ' records');
        }
    }
    
    public class TestAfterUpdateHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            System.debug('After update hook executed for ' + records.size() + ' records');
        }
    }
    
    public class TestAfterDeleteHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            System.debug('After delete hook executed for ' + records.size() + ' records');
        }
    }
    
    public class TestAfterUpsertHook implements DmlHookManager.Hook {
        public void execute(List<SObject> records, DmlContext context) {
            System.debug('After upsert hook executed for ' + records.size() + ' records');
        }
    }
    
    public class TestHookErrorCallback implements DmlHookManager.HookErrorCallback {
        public void handleHookError(Exception ex, List<SObject> records, DmlContext context) {
            System.debug('Hook error callback executed: ' + ex.getMessage());
        }
    }
    
    public class TestOnFailureHook implements DmlProcessor.OnFailureHook {
        public void onFailure(List<SObject> failed, DmlContext context, Exception ex) {
            System.debug('On failure hook executed for ' + failed.size() + ' failed records');
        }
    }
    
    public class TestSuccessCallback implements DmlProcessor.ResultCallback {
        public void handle(SObject record, DmlContext context, Object resultOrError) {
            System.debug('Success callback executed for record: ' + record);
        }
    }
    
    public class TestFailureCallback implements DmlProcessor.ResultCallback {
        public void handle(SObject record, DmlContext context, Object resultOrError) {
            System.debug('Failure callback executed for record: ' + record);
        }
    }
    
    public class TestValidator implements DmlProcessor.Validator {
        public void validate(List<SObject> records) {
            for (SObject record : records) {
                if (record instanceof Account) {
                    Account acc = (Account) record;
                    if (String.isBlank(acc.Name)) {
                        throw new DmlProcessor.DmlException('Account name is required');
                    }
                }
            }
        }
    }
    
    // ===== BASIC DML OPERATION TESTS =====
    
    @IsTest
    static void testInsertOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
        System.assertEquals(0, processor.getFailedRecords().size());
    }
    
    @IsTest
    static void testUpdateOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Updated';
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPDATE);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE '%Updated'];
        System.assertEquals(3, updatedAccounts.size());
        System.assertEquals(0, processor.getFailedRecords().size());
    }
    
    @IsTest
    static void testDeleteOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_DELETE);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> remainingAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, remainingAccounts.size());
        System.assertEquals(0, processor.getFailedRecords().size());
    }
    
    @IsTest
    static void testUpsertOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPSERT)
            .setExternalId('External_Id__c');
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> upsertedAccounts = [SELECT Id, Name, External_Id__c FROM Account WHERE External_Id__c LIKE 'EXT-%'];
        System.assertEquals(3, upsertedAccounts.size());
        System.assertEquals(0, processor.getFailedRecords().size());
    }
    
    // ===== HOOK TESTS =====
    
    @IsTest
    static void testBeforeInsertHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addBeforeInsertHook(new TestBeforeInsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testBeforeUpdateHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Updated';
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPDATE)
            .addBeforeUpdateHook(new TestBeforeUpdateHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> updatedAccounts = [SELECT Id, Name, Description FROM Account WHERE Name LIKE '%Updated'];
        System.assertEquals(3, updatedAccounts.size());
        for (Account acc : updatedAccounts) {
            System.assertEquals('Updated via hook', acc.Description);
        }
    }
    
    @IsTest
    static void testBeforeDeleteHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_DELETE)
            .addBeforeDeleteHook(new TestBeforeDeleteHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> remainingAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, remainingAccounts.size());
    }
    
    @IsTest
    static void testBeforeUpsertHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPSERT)
            .setExternalId('External_Id__c')
            .addBeforeUpsertHook(new TestBeforeUpsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> upsertedAccounts = [SELECT Id, Name, Description FROM Account WHERE External_Id__c LIKE 'EXT-%'];
        System.assertEquals(3, upsertedAccounts.size());
        for (Account acc : upsertedAccounts) {
            System.assertEquals('Upserted via hook', acc.Description);
        }
    }
    
    @IsTest
    static void testAfterInsertHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addAfterInsertHook(new TestAfterInsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testAfterUpdateHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Updated';
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPDATE)
            .addAfterUpdateHook(new TestAfterUpdateHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE '%Updated'];
        System.assertEquals(3, updatedAccounts.size());
    }
    
    @IsTest
    static void testAfterDeleteHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_DELETE)
            .addAfterDeleteHook(new TestAfterDeleteHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> remainingAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, remainingAccounts.size());
    }
    
    @IsTest
    static void testAfterUpsertHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPSERT)
            .setExternalId('External_Id__c')
            .addAfterUpsertHook(new TestAfterUpsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> upsertedAccounts = [SELECT Id, Name FROM Account WHERE External_Id__c LIKE 'EXT-%'];
        System.assertEquals(3, upsertedAccounts.size());
    }
    
    @IsTest
    static void testHookErrorCallback() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addHookErrorCallback(new TestHookErrorCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testSuppressHookExceptions() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .suppressHookExceptions();
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testSuccessCallback() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addSuccessCallback(new TestSuccessCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testFailureCallback() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        // Create accounts with invalid data to trigger failures
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addFailureCallback(new TestFailureCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records');
    }
    
    @IsTest
    static void testOnFailureHook() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addOnFailureHook(new TestOnFailureHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records');
    }
    
    // ===== VALIDATION TESTS =====
    
    @IsTest
    static void testValidator() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addValidator(new TestValidator());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testValidationFailure() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .addValidator(new TestValidator());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records due to validation');
    }
    
    // ===== RETRY TESTS =====
    
    @IsTest
    static void testRetryLogic() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .withMaxRetry(3);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testRetryWithFailedRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .withMaxRetry(2);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records');
    }
    
    // ===== LIGHTWEIGHT MODE TESTS =====
    
    @IsTest
    static void testLightweightMode() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .enableLightweightMode();
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(10, insertedAccounts.size());
    }
    
    @IsTest
    static void testLightweightModeWithUpsertThrowsException() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        // Act & Assert
        Test.startTest();
        try {
            DmlProcessor processor = new DmlProcessor()
                .setRecords(accounts)
                .setOperation(DmlOperationExecutor.Operation.DO_UPSERT)
                .setExternalId('External_Id__c')
                .enableLightweightMode();
            processor.runNow();
            System.assert(false, 'Should have thrown exception for lightweight upsert');
        } catch (DmlProcessor.DmlException e) {
            System.assert(e.getMessage().contains('Lightweight mode does not support upsert operations'));
        }
        Test.stopTest();
    }
    
    // ===== ASYNC TESTS =====
    
    @IsTest
    static void testAsyncProcessing() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .runAsync();
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
    }
    
    @IsTest
    static void testAsyncWithRetry() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .runAsync()
            .withMaxRetry(2);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
    }
    
    // ===== CHUNKING TESTS =====
    
    @IsTest
    static void testChunking() {
        // Arrange
        List<Account> accounts = createTestAccounts(250); // More than default chunk size
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .setChunkSize(50);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(250, insertedAccounts.size());
    }
    
    @IsTest
    static void testChunkingWithHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(100);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .setChunkSize(25)
            .addBeforeInsertHook(new TestBeforeInsertHook())
            .addAfterInsertHook(new TestAfterInsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(100, insertedAccounts.size());
    }
    
    // ===== ERROR HANDLING TESTS =====
    
    @IsTest
    static void testUpsertWithoutExternalId() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act & Assert
        Test.startTest();
        try {
            DmlProcessor processor = new DmlProcessor()
                .setRecords(accounts)
                .setOperation(DmlOperationExecutor.Operation.DO_UPSERT);
            processor.runNow();
            System.assert(false, 'Should have thrown exception for missing external ID');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Missing External ID for upsert operation'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.runNow();
        Test.stopTest();
        
        // Assert - should not throw exception for empty records
        System.assert(true, 'Should handle empty records gracefully');
    }
    
    @IsTest
    static void testNullRecords() {
        // Act & Assert
        Test.startTest();
        try {
            DmlProcessor processor = new DmlProcessor()
                .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
            // Don't set records
            processor.runNow();
            System.assert(false, 'Should have thrown exception for null records');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('You must call setRecords() before execution'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testInvalidOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act & Assert
        Test.startTest();
        try {
            DmlProcessor processor = new DmlProcessor()
                .setRecords(accounts);
            // Don't set operation
            processor.runNow();
            System.assert(false, 'Should have thrown exception for missing operation');
        } catch (Exception e) {
            // Should throw some kind of exception
            System.assert(true, 'Exception thrown for missing operation');
        }
        Test.stopTest();
    }
    
    // ===== LOGGING TESTS =====
    
    @IsTest
    static void testLoggingEnabled() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .withLogging();
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testLoggingWithFailures() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .withLogging();
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records');
    }
    
    // ===== CLONE TESTS =====
    
    @IsTest
    static void testCloneWith() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPDATE)
            .withMaxRetry(3);
        
        DmlProcessor cloned = processor.cloneWith(accounts, 2, 1);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, cloned, 'Cloned processor should not be null');
        System.assertEquals(DmlOperationExecutor.Operation.DO_UPDATE, cloned.getOperation());
        System.assertEquals(3, cloned.getMaxRetry());
    }
    
    @IsTest
    static void testCloneWithAsync() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .runAsync();
        
        DmlProcessor cloned = processor.cloneWith(accounts, 2, 1);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, cloned, 'Cloned processor should not be null');
        System.assertEquals(true, cloned.getIsAsync());
    }
    
    @IsTest
    static void testCloneWithLightweight() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .enableLightweightMode();
        
        DmlProcessor cloned = processor.cloneWith(accounts, 2, 1);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, cloned, 'Cloned processor should not be null');
        System.assertEquals(true, cloned.getIsLightweight());
    }
    
    // ===== BULK TESTS =====
    
    @IsTest
    static void testBulkInsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(200, insertedAccounts.size());
    }
    
    @IsTest
    static void testBulkUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Bulk Updated';
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_UPDATE);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE '%Bulk Updated'];
        System.assertEquals(200, updatedAccounts.size());
    }
    
    @IsTest
    static void testBulkDelete() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        insert accounts;
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_DELETE);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> remainingAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, remainingAccounts.size());
    }
    
    // ===== MIXED SCENARIO TESTS =====
    
    @IsTest
    static void testComplexScenario() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .withMaxRetry(3)
            .addValidator(new TestValidator())
            .addSuccessCallback(new TestSuccessCallback())
            .addFailureCallback(new TestFailureCallback())
            .addOnFailureHook(new TestOnFailureHook())
            .withLogging()
            .setChunkSize(5);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(10, insertedAccounts.size());
        System.assertEquals(0, processor.getFailedRecords().size());
    }
    
    @IsTest
    static void testAsyncWithHooks() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .runAsync()
            .addValidator(new TestValidator())
            .addSuccessCallback(new TestSuccessCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
    }
    
    @IsTest
    static void testLightweightWithCallbacks() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .enableLightweightMode()
            .addSuccessCallback(new TestSuccessCallback())
            .addFailureCallback(new TestFailureCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(10, insertedAccounts.size());
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testSingleRecord() {
        // Arrange
        List<Account> accounts = new List<Account>{ new Account(Name = 'Single Test Account') };
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name = 'Single Test Account'];
        System.assertEquals(1, insertedAccounts.size());
    }
    
    @IsTest
    static void testMixedSObjectTypes() {
        // Arrange
        List<SObject> mixedRecords = new List<SObject>();
        mixedRecords.addAll(createTestAccounts(2));
        mixedRecords.addAll(createTestContacts(2));
        
        // Act & Assert
        Test.startTest();
        try {
            DmlProcessor processor = new DmlProcessor()
                .setRecords(mixedRecords)
                .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
            processor.runNow();
            System.assert(false, 'Should have thrown exception for mixed SObject types');
        } catch (Exception e) {
            // Should throw exception for mixed SObject types
            System.assert(true, 'Exception thrown for mixed SObject types');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFailedRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<SObject> failedRecords = processor.getFailedRecords();
        System.assert(failedRecords.size() > 0, 'Should have failed records');
        System.assertEquals(3, failedRecords.size(), 'All records should have failed');
    }
    
    @IsTest
    static void testExecuteDmlMethod() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT);
        processor.executeDml();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    @IsTest
    static void testExecuteDmlMethodLightweight() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .enableLightweightMode();
        processor.executeDml();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
    }
    
    // ===== GETTER TESTS =====
    
    @IsTest
    static void testGetters() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        
        // Act
        Test.startTest();
        DmlProcessor processor = new DmlProcessor()
            .setRecords(accounts)
            .setOperation(DmlOperationExecutor.Operation.DO_INSERT)
            .setExternalId('External_Id__c')
            .runAsync()
            .enableLightweightMode()
            .withMaxRetry(5);
        Test.stopTest();
        
        // Assert
        System.assertEquals(DmlOperationExecutor.Operation.DO_INSERT, processor.getOperation());
        System.assertEquals('External_Id__c', processor.getExternalIdField());
        System.assertEquals(true, processor.getIsAsync());
        System.assertEquals(true, processor.getIsLightweight());
        System.assertEquals(5, processor.getMaxRetry());
    }
} 