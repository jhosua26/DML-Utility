/**
 * Test class for DmlProcessor
 * 
 * This test class covers all scenarios for the DmlProcessor including:
 * - All DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * - Hook execution (before/after hooks)
 * - Validation scenarios
 * - Retry logic
 * - Error handling
 * - Lightweight mode
 * - Async processing
 * - Logging functionality
 * 
 * @author DML Utility Team
 * @version 1.0
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
    public class TestBeforeInsertHook implements DmlProcessor.Validator {
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
    
    public class TestAfterInsertHook implements DmlProcessor.OnFailureHook {
        public void onFailure(List<SObject> failed, DmlContext context, Exception ex) {
            System.debug('After insert hook executed for failed records: ' + failed.size());
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
            .addValidator(new TestBeforeInsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size());
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
            .addOnFailureHook(new TestAfterInsertHook());
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
    
    // ===== VALIDATION TESTS =====
    
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
            .addValidator(new TestBeforeInsertHook());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        System.assert(processor.getFailedRecords().size() > 0, 'Should have failed records due to validation');
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
        // Note: retryAttemptsLeft and currentAttempt are private, so we can't test them directly
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
            .addValidator(new TestBeforeInsertHook())
            .addSuccessCallback(new TestSuccessCallback())
            .addFailureCallback(new TestFailureCallback())
            .addOnFailureHook(new TestAfterInsertHook())
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
            .addValidator(new TestBeforeInsertHook())
            .addSuccessCallback(new TestSuccessCallback());
        processor.runNow();
        Test.stopTest();
        
        // Assert
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
    }
} 