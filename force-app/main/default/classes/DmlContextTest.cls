/**
 * Test class for DmlContext
 * 
 * This test class covers all scenarios for the DmlContext including:
 * - Context initialization and state management
 * - Logging functionality
 * - Operation tracking
 * - Error handling and statistics
 * - Log object creation and management
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlContextTest {
    
    // Test data setup
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        return accounts;
    }
    
    // ===== CONSTRUCTOR TESTS =====
    
    @IsTest
    static void testDefaultConstructor() {
        // Act
        DmlContext context = new DmlContext();
        
        // Assert
        System.assertNotEquals(null, context, 'Context should not be null');
        System.assertEquals(null, context.getOperation());
        System.assertEquals(null, context.getExternalIdField());
        System.assertEquals(0, context.getTotalRetries());
        System.assertEquals(0, context.getRetryAttempt());
    }
    
    @IsTest
    static void testParameterizedConstructor() {
        // Arrange
        DmlContext.Operation operation = DmlContext.Operation.DO_INSERT;
        String externalIdField = 'External_Id__c';
        Integer totalRetries = 3;
        Integer retryAttempt = 1;
        
        // Act
        DmlContext context = new DmlContext(operation, externalIdField, totalRetries, retryAttempt);
        
        // Assert
        System.assertEquals(operation, context.getOperation());
        System.assertEquals(externalIdField, context.getExternalIdField());
        System.assertEquals(totalRetries, context.getTotalRetries());
        System.assertEquals(retryAttempt, context.getRetryAttempt());
    }
    
    // ===== LOGGING TESTS =====
    
    @IsTest
    static void testLogMethod() {
        // Arrange
        DmlContext context = new DmlContext();
        String message = 'Test log message';
        
        // Act
        context.log(message);
        
        // Assert
        String logDetails = context.getLogDetails();
        System.assert(logDetails.contains(message), 'Log details should contain the message');
        System.assert(logDetails.contains(DateTime.now().format().substring(0, 10)), 'Log details should contain timestamp');
    }
    
    @IsTest
    static void testMultipleLogMessages() {
        // Arrange
        DmlContext context = new DmlContext();
        String message1 = 'First log message';
        String message2 = 'Second log message';
        
        // Act
        context.log(message1);
        context.log(message2);
        
        // Assert
        String logDetails = context.getLogDetails();
        System.assert(logDetails.contains(message1), 'Log details should contain first message');
        System.assert(logDetails.contains(message2), 'Log details should contain second message');
    }
    
    // ===== OPERATION TYPE TESTS =====
    
    @IsTest
    static void testGetOperationType() {
        // Arrange
        DmlContext context = new DmlContext();
        context.setOperation(DmlContext.Operation.DO_INSERT);
        
        // Act
        String operationType = context.getOperationType();
        
        // Assert
        System.assertEquals('DO_INSERT', operationType);
    }
    
    @IsTest
    static void testGetOperationTypeForUpdate() {
        // Arrange
        DmlContext context = new DmlContext();
        context.setOperation(DmlContext.Operation.DO_UPDATE);
        
        // Act
        String operationType = context.getOperationType();
        
        // Assert
        System.assertEquals('DO_UPDATE', operationType);
    }
    
    @IsTest
    static void testGetOperationTypeForDelete() {
        // Arrange
        DmlContext context = new DmlContext();
        context.setOperation(DmlContext.Operation.DO_DELETE);
        
        // Act
        String operationType = context.getOperationType();
        
        // Assert
        System.assertEquals('DO_DELETE', operationType);
    }
    
    @IsTest
    static void testGetOperationTypeForUpsert() {
        // Arrange
        DmlContext context = new DmlContext();
        context.setOperation(DmlContext.Operation.DO_UPSERT);
        
        // Act
        String operationType = context.getOperationType();
        
        // Assert
        System.assertEquals('DO_UPSERT', operationType);
    }
    
    // ===== COUNTER TESTS =====
    
    @IsTest
    static void testIncrementSuppressedHookFailureCount() {
        // Arrange
        DmlContext context = new DmlContext();
        
        // Act
        context.incrementSuppressedHookFailureCount();
        context.incrementSuppressedHookFailureCount();
        
        // Assert
        System.assertEquals(2, context.getSuppressedHookFailureCount());
    }
    
    @IsTest
    static void testIncrementLightweightFailureCount() {
        // Arrange
        DmlContext context = new DmlContext();
        
        // Act
        context.incrementLightweightFailureCount();
        context.incrementLightweightFailureCount();
        context.incrementLightweightFailureCount();
        
        // Assert
        System.assertEquals(3, context.getLightweightFailureCount());
    }
    
    // ===== SETUP LOGGING CONTEXT TESTS =====
    
    @IsTest
    static void testSetupLoggingContext() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlContext context = new DmlContext();
        List<Account> failedRecords = new List<Account>();
        
        // Act
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, failedRecords);
        
        // Assert
        System.assertEquals(5, context.getRecordCount());
        System.assertEquals('Account', context.getSObjectType());
        System.assertEquals('DO_INSERT', context.getOperations());
        System.assertEquals(true, context.getSuccess());
        System.assertEquals(0, context.getFailedRecordCount());
        System.assertNotEquals(null, context.getExecutionTime());
    }
    
    @IsTest
    static void testSetupLoggingContextWithFailures() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        List<Account> failedRecords = createTestAccounts(2);
        DmlContext context = new DmlContext();
        
        // Act
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, failedRecords);
        
        // Assert
        System.assertEquals(5, context.getRecordCount());
        System.assertEquals('Account', context.getSObjectType());
        System.assertEquals('DO_INSERT', context.getOperations());
        System.assertEquals(false, context.getSuccess());
        System.assertEquals(2, context.getFailedRecordCount());
        System.assertNotEquals(null, context.getExecutionTime());
        System.assertNotEquals(null, context.getFirstErrorMessage());
    }
    
    // ===== LOG OBJECT TESTS =====
    
    @IsTest
    static void testSaveToLogObject() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, new List<Account>());
        
        // Act
        Test.startTest();
        Id logId = context.saveToLogObject();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, logId, 'Log ID should not be null');
        
        // Verify log object was created
        List<DmlUtilityLog__c> logs = [SELECT Id, Operation__c, SObjectType__c, RecordCount__c, Success__c 
                                       FROM DmlUtilityLog__c WHERE Id = :logId];
        System.assertEquals(1, logs.size(), 'Log object should be created');
        System.assertEquals('DO_INSERT', logs[0].Operation__c);
        System.assertEquals('Account', logs[0].SObjectType__c);
        System.assertEquals(3, logs[0].RecordCount__c);
        System.assertEquals(true, logs[0].Success__c);
    }
    
    @IsTest
    static void testSaveToLogObjectWithFailures() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        List<Account> failedRecords = createTestAccounts(1);
        DmlContext context = new DmlContext();
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, failedRecords);
        
        // Act
        Test.startTest();
        Id logId = context.saveToLogObject();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, logId, 'Log ID should not be null');
        
        // Verify log object was created with failure information
        List<DmlUtilityLog__c> logs = [SELECT Id, Operation__c, SObjectType__c, RecordCount__c, Success__c, FailedRecordCount__c 
                                       FROM DmlUtilityLog__c WHERE Id = :logId];
        System.assertEquals(1, logs.size(), 'Log object should be created');
        System.assertEquals('DO_INSERT', logs[0].Operation__c);
        System.assertEquals('Account', logs[0].SObjectType__c);
        System.assertEquals(3, logs[0].RecordCount__c);
        System.assertEquals(false, logs[0].Success__c);
        System.assertEquals(1, logs[0].FailedRecordCount__c);
    }
    
    // ===== LOG ENTRY TESTS =====
    
    @IsTest
    static void testAddLogEntry() {
        // Arrange
        DmlContext context = new DmlContext();
        Id parentLogId = context.saveToLogObject();
        Id recordId = Account.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        String sObjectType = 'Account';
        String errorMessage = 'Test error message';
        Boolean hookSuppressed = false;
        
        // Act
        Test.startTest();
        context.addLogEntry(parentLogId, recordId, sObjectType, errorMessage, hookSuppressed);
        Test.stopTest();
        
        // Assert
        List<DmlUtilityLogEntry__c> entries = [SELECT Id, DmlUtilityLog__c, RecordId__c, SObjectType__c, ErrorMessage__c, HookSuppressed__c 
                                               FROM DmlUtilityLogEntry__c WHERE DmlUtilityLog__c = :parentLogId];
        System.assertEquals(1, entries.size(), 'Log entry should be created');
        System.assertEquals(recordId, entries[0].RecordId__c);
        System.assertEquals(sObjectType, entries[0].SObjectType__c);
        System.assertEquals(errorMessage, entries[0].ErrorMessage__c);
        System.assertEquals(hookSuppressed, entries[0].HookSuppressed__c);
    }
    
    @IsTest
    static void testAddLogEntries() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlContext context = new DmlContext();
        Id parentLogId = context.saveToLogObject();
        String message = 'Bulk error message';
        Boolean hookSuppressed = true;
        
        // Act
        Test.startTest();
        context.addLogEntries(parentLogId, accounts, message, hookSuppressed);
        Test.stopTest();
        
        // Assert
        List<DmlUtilityLogEntry__c> entries = [SELECT Id, DmlUtilityLog__c, SObjectType__c, ErrorMessage__c, HookSuppressed__c 
                                               FROM DmlUtilityLogEntry__c WHERE DmlUtilityLog__c = :parentLogId];
        System.assertEquals(3, entries.size(), 'Should create log entries for all records');
        
        for (DmlUtilityLogEntry__c entry : entries) {
            System.assertEquals('Account', entry.SObjectType__c);
            System.assertEquals(message, entry.ErrorMessage__c);
            System.assertEquals(hookSuppressed, entry.HookSuppressed__c);
        }
    }
    
    // ===== GETTER/SETTER TESTS =====
    
    @IsTest
    static void testGetterSetterMethods() {
        // Arrange
        DmlContext context = new DmlContext();
        
        // Act & Assert
        context.setOperation(DmlContext.Operation.DO_UPDATE);
        System.assertEquals(DmlContext.Operation.DO_UPDATE, context.getOperation());
        
        context.setExternalIdField('Test_Field__c');
        System.assertEquals('Test_Field__c', context.getExternalIdField());
        
        context.setTotalRetries(5);
        System.assertEquals(5, context.getTotalRetries());
        
        context.setRetryAttempt(2);
        System.assertEquals(2, context.getRetryAttempt());
        
        context.setIsLightweight(true);
        System.assertEquals(true, context.getIsLightweight());
        
        context.setPartialRetry(true);
        System.assertEquals(true, context.getPartialRetry());
        
        context.setFailedRecordCount(10);
        System.assertEquals(10, context.getFailedRecordCount());
        
        context.setSuppressedHookFailureCount(3);
        System.assertEquals(3, context.getSuppressedHookFailureCount());
        
        context.setLightweightFailureCount(7);
        System.assertEquals(7, context.getLightweightFailureCount());
        
        context.setSObjectType('Contact');
        System.assertEquals('Contact', context.getSObjectType());
        
        context.setOperations('DO_DELETE');
        System.assertEquals('DO_DELETE', context.getOperations());
        
        context.setRecordCount(100);
        System.assertEquals(100, context.getRecordCount());
        
        context.setSuccess(false);
        System.assertEquals(false, context.getSuccess());
        
        context.setPartialRetryEnabled(false);
        System.assertEquals(false, context.getPartialRetryEnabled());
        
        DateTime now = DateTime.now();
        context.setExecutionTime(now);
        System.assertEquals(now, context.getExecutionTime());
        
        context.setFirstErrorMessage('Test error');
        System.assertEquals('Test error', context.getFirstErrorMessage());
        
        context.setLogDetails('Test log details');
        System.assertEquals('Test log details', context.getLogDetails());
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testEmptyRecordsSetupLoggingContext() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlContext context = new DmlContext();
        
        // Act
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, new List<Account>());
        
        // Assert
        System.assertEquals(0, context.getRecordCount());
        System.assertEquals(null, context.getSObjectType());
        System.assertEquals('DO_INSERT', context.getOperations());
        System.assertEquals(true, context.getSuccess());
    }
    
    @IsTest
    static void testNullRecordsSetupLoggingContext() {
        // Arrange
        List<Account> accounts = null;
        DmlContext context = new DmlContext();
        
        // Act
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, new List<Account>());
        
        // Assert
        System.assertEquals(0, context.getRecordCount());
        System.assertEquals(null, context.getSObjectType());
        System.assertEquals('DO_INSERT', context.getOperations());
        System.assertEquals(true, context.getSuccess());
    }
    
    // ===== COMPLEX SCENARIO TESTS =====
    
    @IsTest
    static void testComplexLoggingScenario() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        List<Account> failedRecords = createTestAccounts(3);
        DmlContext context = new DmlContext(DmlContext.Operation.DO_INSERT, 'External_Id__c', 3, 1);
        
        // Act
        context.log('Starting DML operation');
        context.incrementSuppressedHookFailureCount();
        context.incrementLightweightFailureCount();
        context.setupLoggingContext(accounts, DmlContext.Operation.DO_INSERT, failedRecords);
        context.log('DML operation completed');
        
        Test.startTest();
        Id logId = context.saveToLogObject();
        context.addLogEntries(logId, failedRecords, 'Validation failed', false);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, logId, 'Log ID should not be null');
        System.assertEquals(1, context.getSuppressedHookFailureCount());
        System.assertEquals(1, context.getLightweightFailureCount());
        System.assertEquals(10, context.getRecordCount());
        System.assertEquals(3, context.getFailedRecordCount());
        System.assertEquals(false, context.getSuccess());
        
        // Verify log entries were created
        List<DmlUtilityLogEntry__c> entries = [SELECT Id FROM DmlUtilityLogEntry__c WHERE DmlUtilityLog__c = :logId];
        System.assertEquals(3, entries.size(), 'Should create log entries for failed records');
    }
    
} 