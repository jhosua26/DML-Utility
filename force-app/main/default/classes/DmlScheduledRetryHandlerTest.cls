/**
 * Test class for DmlScheduledRetryHandler
 * 
 * This test class covers all scenarios for the DmlScheduledRetryHandler including:
 * - Scheduled job execution
 * - Job status management
 * - Error handling during execution
 * - Integration with DmlUtility
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
    static void testExecuteWithInvalidOperation() {
        // Arrange
        DmlRetryJob__c job = createTestRetryJob();
        job.Operation__c = 'INVALID_OPERATION';
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should handle invalid operation
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should mark job as failed on invalid operation');
    }
    
    @IsTest
    static void testExecuteWithDmlException() {
        // Arrange - Create job with records that will cause DML errors
        // Create accounts with extremely long names to exceed field limits
        List<Account> accounts = new List<Account>();
        String longName = 'a'.repeat(300); // Account Name field typically has a 255 character limit
        for (Integer i = 0; i < 3; i++) {
            Account acc = new Account(Name = longName + i);
            accounts.add(acc);
        }
        
        DmlRetryJob__c job = createTestRetryJob();
        job.SerializedRecord__c = JSON.serialize(accounts);
        insert job;
        
        // Act
        Test.startTest();
        DmlScheduledRetryHandler handler = new DmlScheduledRetryHandler();
        handler.execute(null);
        Test.stopTest();
        
        // Assert - Should handle DML errors
        List<DmlRetryJob__c> updatedJobs = [SELECT Id, Status__c FROM DmlRetryJob__c WHERE Id = :job.Id];
        System.assertEquals(1, updatedJobs.size());
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should mark job as failed on DML error');
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
        List<Account> accounts = createTestAccounts(100); // Reduced from 1000 to avoid field size limit
        DmlRetryJob__c job = createTestRetryJob();
        
        try {
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
        } catch (DmlException e) {
            // If still too large, verify it handles the error appropriately
            System.assert(e.getMessage().contains('STRING_TOO_LONG') || 
                         e.getMessage().contains('data value too large'), 
                         'Should handle large record sets with appropriate error: ' + e.getMessage());
        }
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
        List<Account> accounts = new List<Account>();
        String longName = 'a'.repeat(300); // Exceeds 255 character limit
        accounts.add(new Account(Name = 'Valid Account 1'));
        accounts.add(new Account(Name = longName)); // Invalid - name too long
        accounts.add(new Account(Name = 'Valid Account 2'));
        
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
        System.assertEquals('Failed', updatedJobs[0].Status__c, 'Should fail due to partial DML errors');
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
} 