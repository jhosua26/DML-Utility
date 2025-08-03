/**
 * Test class for DmlOperationExecutor
 * 
 * This test class covers all scenarios for the DmlOperationExecutor including:
 * - All DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * - Error handling and result processing
 * - External ID validation for upsert operations
 * - Empty record handling
 * - Invalid field scenarios
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlOperationExecutorTest {
    
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
    
    // ===== INSERT OPERATION TESTS =====
    
    @IsTest
    static void testExecuteInsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually inserted
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(5, insertedAccounts.size());
    }
    
    @IsTest
    static void testExecuteInsertWithValidationErrors() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(3, result.failedRecords.size());
        System.assertEquals(3, result.errorMessages.size());
        
        // Verify no records were inserted
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, insertedAccounts.size());
    }
    
    // ===== UPDATE OPERATION TESTS =====
    
    @IsTest
    static void testExecuteUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Updated';
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPDATE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually updated
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE '%Updated'];
        System.assertEquals(3, updatedAccounts.size());
    }
    
    @IsTest
    static void testExecuteUpdateWithValidationErrors() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = null; // This will cause validation failure
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPDATE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(3, result.failedRecords.size());
        System.assertEquals(3, result.errorMessages.size());
    }
    
    // ===== DELETE OPERATION TESTS =====
    
    @IsTest
    static void testExecuteDelete() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_DELETE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually deleted
        List<Account> remainingAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(0, remainingAccounts.size());
    }
    
    @IsTest
    static void testExecuteDeleteWithErrors() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        // Delete the accounts first to cause errors on second delete
        delete accounts;
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_DELETE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(3, result.failedRecords.size());
        System.assertEquals(3, result.errorMessages.size());
    }
    
    // ===== UPSERT OPERATION TESTS =====
    
    @IsTest
    static void testExecuteUpsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor('External_Id__c');
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually upserted
        List<Account> upsertedAccounts = [SELECT Id, Name, External_Id__c FROM Account WHERE External_Id__c LIKE 'EXT-%'];
        System.assertEquals(3, upsertedAccounts.size());
    }
    
    @IsTest
    static void testExecuteUpsertWithoutExternalId() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act & Assert
        Test.startTest();
        try {
            DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPSERT);
            System.assert(false, 'Should have thrown exception for missing external ID');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Missing External ID for upsert operation'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testExecuteUpsertWithInvalidExternalId() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlOperationExecutor executor = new DmlOperationExecutor('InvalidField__c');
        
        // Act & Assert
        Test.startTest();
        try {
            DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPSERT);
            System.assert(false, 'Should have thrown exception for invalid external ID field');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Invalid External ID field'));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testExecuteUpsertWithValidationErrors() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
            acc.Name = null; // This will cause validation failure
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor('External_Id__c');
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(3, result.failedRecords.size());
        System.assertEquals(3, result.errorMessages.size());
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testExecuteWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
    }
    
    @IsTest
    static void testExecuteWithNullRecords() {
        // Arrange
        List<Account> accounts = null;
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
    }
    
    @IsTest
    static void testExecuteUnsupportedOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act & Assert
        Test.startTest();
        try {
            // Use a non-existent operation
            DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, null);
            System.assert(false, 'Should have thrown exception for unsupported operation');
        } catch (UnsupportedOperationException e) {
            System.assert(e.getMessage().contains('Unsupported DML operation'));
        }
        Test.stopTest();
    }
    
    // ===== RESULT PROCESSING TESTS =====
    
    @IsTest
    static void testDmlOperationResult() {
        // Arrange
        List<SObject> failedRecords = createTestAccounts(2);
        List<String> errorMessages = new List<String>{
            'Error 1: Validation failed',
            'Error 2: Field required'
        };
        
        // Act
        DmlOperationExecutor.DmlOperationResult result = new DmlOperationExecutor.DmlOperationResult(failedRecords, errorMessages);
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(2, result.failedRecords.size());
        System.assertEquals(2, result.errorMessages.size());
        System.assertEquals('Error 1: Validation failed\nError 2: Field required', result.getErrorSummary());
    }
    
    @IsTest
    static void testDmlOperationResultWithNoFailures() {
        // Arrange
        List<SObject> failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        // Act
        DmlOperationExecutor.DmlOperationResult result = new DmlOperationExecutor.DmlOperationResult(failedRecords, errorMessages);
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        System.assertEquals('', result.getErrorSummary());
    }
    
    // ===== BULK OPERATION TESTS =====
    
    @IsTest
    static void testBulkInsert() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually inserted
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
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPDATE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures);
        System.assertEquals(0, result.failedRecords.size());
        System.assertEquals(0, result.errorMessages.size());
        
        // Verify records were actually updated
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE '%Bulk Updated'];
        System.assertEquals(200, updatedAccounts.size());
    }
    
    // ===== MIXED SUCCESS/FAILURE TESTS =====
    
    @IsTest
    static void testMixedSuccessAndFailure() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        // Make some accounts valid and some invalid
        for (Integer i = 0; i < accounts.size(); i++) {
            if (Math.mod(i, 2) == 0) {
                accounts[i].Name = null; // Invalid - will fail
            }
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.hasFailures);
        System.assertEquals(3, result.failedRecords.size()); // 3 accounts with null names
        System.assertEquals(3, result.errorMessages.size());
        
        // Verify some records were inserted
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(2, insertedAccounts.size()); // 2 accounts with valid names
    }
} 