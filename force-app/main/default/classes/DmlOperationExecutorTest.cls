/**
 * Test class for DmlOperationExecutor
 * 
 * This test class covers all scenarios for the DmlOperationExecutor including:
 * - All DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * - Error handling and result processing
 * - External ID validation for upsert operations
 * - Empty record handling
 * - Invalid field scenarios
 * - Bulk operation scenarios
 * - Edge cases and error conditions
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlOperationExecutorTest {
    
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
     * Creates test accounts with external IDs for upsert operations
     * @param count Number of accounts to create
     * @return List of test accounts with external IDs
     */
    private static List<Account> createTestAccountsWithExternalIds(Integer count) {
        List<Account> accounts = createTestAccounts(count);
        for (Integer i = 0; i < accounts.size(); i++) {
            accounts[i].External_Id__c = 'EXT-' + String.valueOf(i).leftPad(3, '0');
        }
        return accounts;
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
    
    /**
     * Asserts that the expected number of contacts exist with the given name pattern
     * @param expectedCount Expected number of contacts
     * @param namePattern Name pattern to search for
     * @param message Assertion message
     */
    private static void assertContactCount(Integer expectedCount, String namePattern, String message) {
        Integer actualCount = [SELECT COUNT() FROM Contact WHERE LastName LIKE :namePattern];
        System.assertEquals(expectedCount, actualCount, message);
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
        System.assertEquals(false, result.hasFailures, 'Should not have failures for valid insert');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually inserted
        assertAccountCount(5, 'Test Account%', 'Should have inserted 5 accounts');
        
        // Verify account details
        List<Account> insertedAccounts = [SELECT Id, Name, Type, Industry FROM Account WHERE Name LIKE 'Test Account%'];
        for (Account acc : insertedAccounts) {
            System.assert(acc.Name.startsWith('Test Account'), 'Account name should start with "Test Account"');
            System.assertEquals('Customer', acc.Type, 'Account type should be Customer');
            System.assertEquals('Technology', acc.Industry, 'Account industry should be Technology');
        }
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
        System.assertEquals(true, result.hasFailures, 'Should have failures for invalid insert');
        System.assertEquals(3, result.failedRecords.size(), 'Should have 3 failed records');
        System.assertEquals(3, result.errorMessages.size(), 'Should have 3 error messages');
        
        // Verify no records were inserted
        assertAccountCount(0, 'Test Account%', 'Should not have inserted any accounts when validation fails');
        
        // Verify error messages contain expected content
        for (String errorMsg : result.errorMessages) {
            System.assert(errorMsg.contains('INSERT'), 'Error message should contain operation type');
        }
    }
    
    @IsTest
    static void testExecuteInsertWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures, 'Should not have failures for empty records');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
    }
    
    @IsTest
    static void testExecuteInsertWithNullRecords() {
        // Arrange
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(null, DmlOperationExecutor.Operation.DO_INSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures, 'Should not have failures for null records');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
    }
    
    // ===== UPDATE OPERATION TESTS =====
    
    @IsTest
    static void testExecuteUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Updated';
            acc.Type = 'Prospect';
            acc.Industry = 'Healthcare';
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPDATE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures, 'Should not have failures for valid update');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually updated
        List<Account> updatedAccounts = [SELECT Id, Name, Type, Industry FROM Account WHERE Name LIKE '%Updated'];
        System.assertEquals(3, updatedAccounts.size(), 'Should have updated 3 accounts');
        
        // Verify updated details
        for (Account acc : updatedAccounts) {
            System.assert(acc.Name.endsWith(' - Updated'), 'Account name should end with " - Updated"');
            System.assertEquals('Prospect', acc.Type, 'Account type should be updated to Prospect');
            System.assertEquals('Healthcare', acc.Industry, 'Account industry should be updated to Healthcare');
        }
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
        System.assertEquals(true, result.hasFailures, 'Should have failures for invalid update');
        System.assertEquals(3, result.failedRecords.size(), 'Should have 3 failed records');
        System.assertEquals(3, result.errorMessages.size(), 'Should have 3 error messages');
        
        // Verify original records still exist
        assertAccountCount(3, 'Test Account%', 'Should still have 3 accounts when update fails');
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
        System.assertEquals(false, result.hasFailures, 'Should not have failures for valid delete');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually deleted
        assertAccountCount(0, 'Test Account%', 'Should have deleted 3 accounts');
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
        System.assertEquals(true, result.hasFailures, 'Should have failures for delete with errors');
        System.assertEquals(3, result.failedRecords.size(), 'Should have 3 failed records');
        System.assertEquals(3, result.errorMessages.size(), 'Should have 3 error messages');
        
        // Verify original records still exist
        assertAccountCount(3, 'Test Account%', 'Should still have 3 accounts when delete fails');
    }
    
    // ===== UPSERT OPERATION TESTS =====
    
    @IsTest
    static void testExecuteUpsert() {
        // Arrange
        List<Account> accounts = createTestAccountsWithExternalIds(3);
        
        DmlOperationExecutor executor = new DmlOperationExecutor('External_Id__c');
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPSERT);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures, 'Should not have failures for valid upsert');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually upserted
        assertAccountCount(3, 'EXT-%', 'Should have upserted 3 accounts');
        
        // Verify upserted details
        List<Account> upsertedAccounts = [SELECT Id, Name, External_Id__c FROM Account WHERE External_Id__c LIKE 'EXT-%'];
        for (Account acc : upsertedAccounts) {
            System.assert(acc.External_Id__c.startsWith('EXT-'), 'External ID should start with "EXT-"');
        }
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
        List<Account> accounts = createTestAccountsWithExternalIds(3);
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
        System.assertEquals(true, result.hasFailures, 'Should have failures for invalid upsert');
        System.assertEquals(3, result.failedRecords.size(), 'Should have 3 failed records');
        System.assertEquals(3, result.errorMessages.size(), 'Should have 3 error messages');
        
        // Verify original records still exist
        assertAccountCount(3, 'EXT-%', 'Should still have 3 accounts when upsert fails');
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
        System.assertEquals(false, result.hasFailures, 'Should not have failures for bulk insert');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually inserted
        assertAccountCount(200, 'Test Account%', 'Should have inserted 200 accounts');
    }
    
    @IsTest
    static void testBulkUpdate() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        insert accounts;
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' - Bulk Updated';
            acc.Type = 'Prospect';
            acc.Industry = 'Healthcare';
        }
        
        DmlOperationExecutor executor = new DmlOperationExecutor(null);
        
        // Act
        Test.startTest();
        DmlOperationExecutor.DmlOperationResult result = executor.execute(accounts, DmlOperationExecutor.Operation.DO_UPDATE);
        Test.stopTest();
        
        // Assert
        System.assertEquals(false, result.hasFailures, 'Should not have failures for bulk update');
        System.assertEquals(0, result.failedRecords.size(), 'Should not have failed records');
        System.assertEquals(0, result.errorMessages.size(), 'Should not have error messages');
        
        // Verify records were actually updated
        List<Account> updatedAccounts = [SELECT Id, Name, Type, Industry FROM Account WHERE Name LIKE '%Bulk Updated'];
        System.assertEquals(200, updatedAccounts.size(), 'Should have updated 200 accounts');
        
        // Verify updated details
        for (Account acc : updatedAccounts) {
            System.assert(acc.Name.endsWith(' - Bulk Updated'), 'Account name should end with " - Bulk Updated"');
            System.assertEquals('Prospect', acc.Type, 'Account type should be updated to Prospect');
            System.assertEquals('Healthcare', acc.Industry, 'Account industry should be updated to Healthcare');
        }
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
        System.assertEquals(true, result.hasFailures, 'Should have failures for mixed success/failure');
        System.assertEquals(3, result.failedRecords.size(), 'Should have 3 failed records'); // 3 accounts with null names
        System.assertEquals(3, result.errorMessages.size(), 'Should have 3 error messages');
        
        // Verify some records were inserted
        assertAccountCount(2, 'Test Account%', 'Should have 2 accounts with valid names'); // 2 accounts with valid names
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
    
    // ===== UNSUPPORTED OPERATION TESTS =====
    
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
} 