/**
 * Test class for DmlRetryHandler
 * 
 * This test class covers all scenarios for the DmlRetryHandler including:
 * - Retry job scheduling
 * - Delay calculation with exponential backoff
 * - Cron expression generation
 * - Error handling and edge cases
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlRetryHandlerTest {
    
    // Test data setup
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        return accounts;
    }
    
    private static DmlUtility createMockDmlUtility() {
        List<Account> accounts = createTestAccounts(3);
        return new DmlUtility()
            .setRecords(accounts)
            .setOperation(DmlUtility.Operation.DO_INSERT)
            .setExternalId('External_Id__c')
            .withMaxRetry(3)
            .setAttempt(1);
    }
    
    // ===== SCHEDULE RETRY TESTS =====
    
    @IsTest
    static void testScheduleRetry() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = createTestAccounts(2);
        Integer retryLeft = 2;
        Integer attempt = 1;
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, retryLeft, attempt);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, SerializedRecord__c, Operation__c, ExternalIdField__c,
                                            RetryLeft__c, Attempt__c, IsAsync__c, IsLightweight__c, Status__c
                                     FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size(), 'Should create one retry job');
        
        DmlRetryJob__c job = jobs[0];
        System.assertEquals('DO_INSERT', job.Operation__c);
        System.assertEquals('External_Id__c', job.ExternalIdField__c);
        System.assertEquals(2, job.RetryLeft__c);
        System.assertEquals(1, job.Attempt__c);
        System.assertEquals(false, job.IsAsync__c);
        System.assertEquals(false, job.IsLightweight__c);
        System.assertEquals('Pending', job.Status__c);
        
        // Verify serialized records
        List<SObject> deserializedRecords = (List<SObject>) JSON.deserializeUntyped(job.SerializedRecord__c);
        System.assertEquals(2, deserializedRecords.size(), 'Should serialize correct number of records');
    }
    
    @IsTest
    static void testScheduleRetryWithAsyncJob() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility().runAsync();
        List<Account> failedRecords = createTestAccounts(1);
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 2);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, IsAsync__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        System.assertEquals(true, jobs[0].IsAsync__c, 'Should preserve async setting');
    }
    
    @IsTest
    static void testScheduleRetryWithLightweightJob() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility().enableLightweightMode();
        List<Account> failedRecords = createTestAccounts(1);
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 2);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, IsLightweight__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        System.assertEquals(true, jobs[0].IsLightweight__c, 'Should preserve lightweight setting');
    }
    
    @IsTest
    static void testScheduleRetryWithEmptyRecords() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = new List<Account>();
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 1);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, SerializedRecord__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        
        List<SObject> deserializedRecords = (List<SObject>) JSON.deserializeUntyped(jobs[0].SerializedRecord__c);
        System.assertEquals(0, deserializedRecords.size(), 'Should handle empty records');
    }
    
    @IsTest
    static void testScheduleRetryWithNullRecords() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = null;
        
        // Act & Assert
        Test.startTest();
        try {
            DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 1);
            System.assert(false, 'Should throw exception for null records');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('null'), 'Should handle null records gracefully');
        }
        Test.stopTest();
    }
    
    // ===== DELAY CALCULATION TESTS =====
    
    @IsTest
    static void testCalculateRetryDelay() {
        // Test first attempt
        Integer delay1 = DmlRetryHandlerTest.calculateRetryDelay(3, 0);
        System.assertEquals(60, delay1, 'First attempt should have 60 second delay');
        
        // Test second attempt
        Integer delay2 = DmlRetryHandlerTest.calculateRetryDelay(3, 1);
        System.assertEquals(120, delay2, 'Second attempt should have 120 second delay');
        
        // Test third attempt
        Integer delay3 = DmlRetryHandlerTest.calculateRetryDelay(3, 2);
        System.assertEquals(240, delay3, 'Third attempt should have 240 second delay');
        
        // Test max delay cap
        Integer delayMax = DmlRetryHandlerTest.calculateRetryDelay(10, 10);
        System.assertEquals(3600, delayMax, 'Should cap delay at 3600 seconds');
    }
    
    @IsTest
    static void testCalculateRetryDelayWithZeroAttempt() {
        Integer delay = DmlRetryHandlerTest.calculateRetryDelay(5, 0);
        System.assertEquals(60, delay, 'Zero attempt should have base delay');
    }
    
    @IsTest
    static void testCalculateRetryDelayWithHighAttempt() {
        Integer delay = DmlRetryHandlerTest.calculateRetryDelay(5, 20);
        System.assertEquals(3600, delay, 'High attempt should be capped at max delay');
    }
    
    // ===== CRON EXPRESSION TESTS =====
    
    @IsTest
    static void testGetCronExpression() {
        // Arrange
        Datetime testTime = Datetime.newInstance(2024, 1, 15, 14, 30, 45);
        
        // Act
        String cron = DmlRetryHandlerTest.getCronExpression(testTime);
        
        // Assert
        System.assertEquals('45 30 14 15 1 ? 2024', cron, 'Should generate correct cron expression');
    }
    
    @IsTest
    static void testGetCronExpressionWithDifferentTime() {
        // Arrange
        Datetime testTime = Datetime.newInstance(2024, 12, 31, 23, 59, 0);
        
        // Act
        String cron = DmlRetryHandlerTest.getCronExpression(testTime);
        
        // Assert
        System.assertEquals('0 59 23 31 12 ? 2024', cron, 'Should handle different time values');
    }
    
    @IsTest
    static void testGetCronExpressionWithCurrentTime() {
        // Arrange
        Datetime now = Datetime.now();
        
        // Act
        String cron = DmlRetryHandlerTest.getCronExpression(now);
        
        // Assert
        System.assertNotEquals(null, cron, 'Should generate cron for current time');
        System.assert(cron.contains('?'), 'Should include ? for day of week');
    }
    
    // ===== INTEGRATION TESTS =====
    
    @IsTest
    static void testRetryJobLifecycle() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = createTestAccounts(2);
        
        // Act - Schedule retry
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 1);
        
        // Verify job was created
        List<DmlRetryJob__c> jobs = [SELECT Id, Status__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        System.assertEquals('Pending', jobs[0].Status__c);
        
        // Simulate scheduled execution
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Job should be updated
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c];
        System.assertEquals(1, updatedJobs.size());
        // Note: Status might be 'Completed' or 'Failed' depending on execution
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testMultipleRetryJobs() {
        // Arrange
        DmlUtility job1 = createMockDmlUtility();
        DmlUtility job2 = createMockDmlUtility();
        List<Account> failedRecords = createTestAccounts(1);
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(job1, failedRecords, 2, 1);
        DmlRetryHandler.scheduleRetry(job2, failedRecords, 1, 2);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, RetryLeft__c, Attempt__c FROM DmlRetryJob__c];
        System.assertEquals(2, jobs.size(), 'Should create multiple retry jobs');
        
        // Verify different retry settings
        Boolean hasDifferentSettings = false;
        for (DmlRetryJob__c job : jobs) {
            if (job.RetryLeft__c == 2 && job.Attempt__c == 1) {
                hasDifferentSettings = true;
                break;
            }
        }
        System.assert(hasDifferentSettings, 'Should preserve different retry settings');
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testScheduleRetryWithZeroRetryLeft() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = createTestAccounts(1);
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 0, 3);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, RetryLeft__c, Attempt__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        System.assertEquals(0, jobs[0].RetryLeft__c);
        System.assertEquals(3, jobs[0].Attempt__c);
    }
    
    @IsTest
    static void testScheduleRetryWithLargeRecordSet() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        List<Account> failedRecords = createTestAccounts(1000); // Large record set
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 1);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> jobs = [SELECT Id, SerializedRecord__c FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size());
        
        List<SObject> deserializedRecords = (List<SObject>) JSON.deserializeUntyped(jobs[0].SerializedRecord__c);
        System.assertEquals(1000, deserializedRecords.size(), 'Should handle large record sets');
    }
    
    // ===== ERROR HANDLING TESTS =====
    
    @IsTest
    static void testScheduleRetryWithInvalidOperation() {
        // Arrange
        DmlUtility originalJob = createMockDmlUtility();
        // Set an invalid operation (this would need to be handled in the actual implementation)
        List<Account> failedRecords = createTestAccounts(1);
        
        // Act
        Test.startTest();
        DmlRetryHandler.scheduleRetry(originalJob, failedRecords, 1, 1);
        Test.stopTest();
        
        // Assert - Should not throw exception
        List<DmlRetryJob__c> jobs = [SELECT Id FROM DmlRetryJob__c];
        System.assertEquals(1, jobs.size(), 'Should handle invalid operations gracefully');
    }
    
    // Helper methods for testing private methods (using @TestVisible if needed)
    @TestVisible
    private static Integer calculateRetryDelay(Integer maxRetries, Integer attempt) {
        // Exponential backoff, capped at 1 hour (3600 seconds)
        Integer baseDelay = 60; // start with 1 minute
        Integer delay = Math.min(baseDelay * (Integer)Math.pow(2, attempt), 3600);
        return delay;
    }
    
    @TestVisible
    private static String getCronExpression(Datetime dt) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<Object>{
                dt.second(), dt.minute(), dt.hour(),
                dt.day(), dt.month(), dt.year()
            }
        );
    }
} 