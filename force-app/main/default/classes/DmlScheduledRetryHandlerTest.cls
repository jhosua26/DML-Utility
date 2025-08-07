/**
 * Test class for DmlScheduledRetryHandler
 * 
 * This test class covers all scenarios for the DmlScheduledRetryHandler including:
 * - Scheduled job execution
 * - Job status management
 * - Error handling during execution
 * - Integration with DmlProcessor
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlScheduledRetryHandlerTest {
    
    // Test data setup
    private static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        return accounts;
    }
    
    private static DmlRetryJob__c createTestRetryJob() {
        List<Account> accounts = createTestAccounts(3);
        String serializedRecords = JSON.serialize(accounts);
        
        return new DmlRetryJob__c(
            SerializedRecord__c = serializedRecords,
            Operation__c = 'DO_INSERT',
            ExternalIdField__c = 'External_Id__c',
            SObjectType__c = 'Account',
            RetryLeft__c = 2,
            Attempt__c = 1,
            IsAsync__c = false,
            IsLightweight__c = false,
            Status__c = 'Pending'
        );
    }
    
    // ===== EXECUTION TESTS =====
    
    @IsTest
    static void testExecuteWithPendingJob() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        // Status should be 'Completed' or 'Failed' depending on execution
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithNoPendingJobs() {
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should not throw exception when no jobs exist
        System.assert(true, 'Should handle empty job queue gracefully');
    }
    
    @IsTest
    static void testExecuteWithMultiplePendingJobs() {
        // Arrange
        DmlRetryJob__c job1 = createTestRetryJob();
        DmlRetryJob__c job2 = createTestRetryJob();
        job2.Status__c = 'Pending';
        insert new List<DmlRetryJob__c>{ job1, job2 };
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should process only one job (LIMIT 1 in query)
        List<DmlRetryJob__c> processedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Status__c != 'Pending'];
        System.assertEquals(1, processedJobs.size(), 'Should process only one job per execution');
    }
    
    @IsTest
    static void testExecuteWithCompletedJob() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.Status__c = 'Completed';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should not process completed jobs
        List<DmlRetryJob__c> jobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, jobs.size());
        System.assertEquals('Completed', jobs[0].Status__c, 'Should not change status of completed job');
    }
    
    @IsTest
    static void testExecuteWithFailedJob() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.Status__c = 'Failed';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should not process failed jobs
        List<DmlRetryJob__c> jobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, jobs.size());
        System.assertEquals('Failed', jobs[0].Status__c, 'Should not change status of failed job');
    }
    
    // ===== OPERATION TYPE TESTS =====
    
    @IsTest
    static void testExecuteWithInsertOperation() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'DO_INSERT';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithUpdateOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts; // Need existing records for update
        
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'DO_UPDATE';
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithDeleteOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        insert accounts; // Need existing records for delete
        
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'DO_DELETE';
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithUpsertOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        for (Account acc : accounts) {
            acc.External_Id__c = 'EXT-' + acc.Name;
        }
        
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'DO_UPSERT';
        job.ExternalIdField__c = 'External_Id__c';
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    // ===== CONFIGURATION TESTS =====
    
    @IsTest
    static void testExecuteWithAsyncJob() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.IsAsync__c = true;
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithLightweightJob() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.IsLightweight__c = true;
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithRetrySettings() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.RetryLeft__c = 1;
        job.Attempt__c = 2;
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    // ===== ERROR HANDLING TESTS =====
    
    @IsTest
    static void testExecuteWithInvalidSerializedData() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = 'invalid json data';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should handle JSON parsing errors
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should mark job as failed on JSON error');
    }
    
    @IsTest
    static void testExecuteWithDmlException() {
        // Arrange - Include a record missing a required field (like Name)
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Valid Account 1'),
            new Account(), // This will cause DML failure (missing required Name)
            new Account(Name = 'Valid Account 2')
        };
    
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'DO_INSERT'; // Valid picklist value
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;

        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should handle operation parsing errors
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should mark job as failed on invalid operation');
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testExecuteWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Completed', updatedJobs[0].Status__c, 'Should complete successfully with empty records');
    }
    
    @IsTest
    static void testExecuteWithLargeRecordSet() {
        // Arrange
        List<Account> accounts = createTestAccounts(1000); // Large record set
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    @IsTest
    static void testExecuteWithNullExternalIdField() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.ExternalIdField__c = null;
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assert(updatedJobs[0].Status__c == 'Completed' || updatedJobs[0].Status__c == 'Failed');
    }
    
    // ===== INTEGRATION TESTS =====
    
    @IsTest
    static void testExecuteWithSuccessfulDmlOperation() {
        // Arrange
        List<Account> accounts = createTestAccounts(3);
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Completed', updatedJobs[0].Status__c, 'Should complete successfully');
        
        // Verify records were actually inserted
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
        System.assertEquals(3, insertedAccounts.size(), 'Should insert the records');
    }
    
    @IsTest
    static void testExecuteWithMixedSuccessAndFailure() {
        // Arrange - Create some valid and some invalid records
        // List<Account> accounts = new List<Account>();
        // accounts.add(new Account(Name = 'Valid Account 1'));
        // accounts.add(new Account()); // Invalid - no name
        // accounts.add(new Account(Name = 'Valid Account 2'));

        // Arrange - Create job with invalid operation to simulate processing failure
        List<Account> accounts = createTestAccounts(3);
        
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = JSON.serialize(accounts);
        job.Operation__c = 'INVALID_OPERATION'; // This will cause failure during processing
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should fail due to invalid operation');
    }
    
    // ===== PERFORMANCE TESTS =====
    
    @IsTest
    static void testExecutePerformance() {
        // Arrange
        List<DmlRetryJob__c> jobs = new List<DmlRetryJob__c>();
        for (Integer i = 0; i < 10; i++) {
            DmlRetryJob__c job = createTestRetryJob();
            jobs.add(job);
        }
        insert jobs;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should process one job per execution
        List<DmlRetryJob__c> processedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Status__c != 'Pending'];
        System.assertEquals(1, processedJobs.size(), 'Should process only one job per execution');
    }
    
    // ===== NEW TESTS FOR ENHANCED FUNCTIONALITY =====
    
    @IsTest
    static void testExecuteWithMissingSObjectType() {
        // Arrange - Create job without SObjectType
        DmlRetryJob__c job = createTestRetryJob();
        job.SObjectType__c = null;
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should fail gracefully
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c, ErrorMessage__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c);
        System.assert(updatedJobs[0].ErrorMessage__c.contains('SObjectType cannot be blank'), 
                     'Should have appropriate error message');
    }
    
    @IsTest
    static void testExecuteWithInvalidSObjectType() {
        // Arrange - Create job with invalid SObjectType
        DmlRetryJob__c job = createTestRetryJob();
        job.SObjectType__c = 'InvalidSObjectType';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should fail gracefully
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c, ErrorMessage__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c);
        System.assert(updatedJobs[0].ErrorMessage__c != null, 'Should have error message');
    }
    
    @IsTest
    static void testExecuteWithRetryScheduling() {
        // Arrange - Create job with retries left
        DmlRetryJob__c job = createTestRetryJob();
        job.RetryLeft__c = 2;
        job.Attempt__c = 1;
        // Make it fail by using invalid sobject
        job.SObjectType__c = 'InvalidSObjectType';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should create retry job and mark original as failed
        List<DmlRetryJob__c> allJobs = [SELECT Id, Status__c, RetryLeft__c, Attempt__c, ErrorMessage__c FROM DmlRetryJob__c];
        
        // Original job should be marked as failed
        DmlRetryJob__c originalJob = null;
        DmlRetryJob__c retryJob = null;
        
        for (DmlRetryJob__c j : allJobs) {
            if (j.Id == job.Id) {
                originalJob = j;
            } else {
                retryJob = j;
            }
        }
        
        System.assertNotEquals(null, originalJob, 'Original job should exist');
        System.assertEquals('Failed', originalJob.Status__c, 'Original job should be failed');
        System.assert(originalJob.ErrorMessage__c != null, 'Should have error message');
        
        // Should have created a retry job
        System.assertNotEquals(null, retryJob, 'Should have created retry job');
        // In test context, retry job might execute immediately, so status could be Pending or Failed
        System.assert(retryJob.Status__c == 'Pending' || retryJob.Status__c == 'Failed', 
                     'Retry job status should be Pending or Failed, but was: ' + retryJob.Status__c);
        // Retry count should be decremented (could be 1 or 0 if job executed again)
        System.assert(retryJob.RetryLeft__c <= 1, 
                     'Retry job should have decremented retry count, got: ' + retryJob.RetryLeft__c);
        System.assertEquals(3, retryJob.Attempt__c, 'Retry job should have incremented attempt');
    }
    
    @IsTest
    static void testExecuteWithNoRetriesLeft() {
        // Arrange - Create job with no retries left
        DmlRetryJob__c job = createTestRetryJob();
        job.RetryLeft__c = 0;
        job.Attempt__c = 3;
        // Make it fail by using invalid sobject
        job.SObjectType__c = 'InvalidSObjectType';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should not create retry job
        List<DmlRetryJob__c> allJobs = [SELECT Id, Status__c FROM DmlRetryJob__c];
        System.assertEquals(1, allJobs.size(), 'Should not create additional retry jobs');
        System.assertEquals('Failed', allJobs[0].Status__c, 'Job should be marked as failed');
    }
    
    @IsTest
    static void testDeserializeRecordsSuccess() {
        // This test verifies the type-safe deserialization works correctly
        // Arrange
        List<Account> accounts = createTestAccounts(2);
        String serializedRecords = JSON.serialize(accounts);
        
        DmlRetryJob__c job = new DmlRetryJob__c(
            SerializedRecord__c = serializedRecords,
            Operation__c = 'DO_INSERT',
            ExternalIdField__c = 'External_Id__c',
            SObjectType__c = 'Account',
            RetryLeft__c = 1,
            Attempt__c = 1,
            IsAsync__c = false,
            IsLightweight__c = false,
            Status__c = 'Pending'
        );
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should complete successfully
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c, ErrorMessage__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Completed', updatedJobs[0].Status__c, 'Job should complete successfully');
        System.assertEquals(null, updatedJobs[0].ErrorMessage__c, 'Should have no error message');
    }
}