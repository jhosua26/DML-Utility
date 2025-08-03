/**
 * Test class for DmlChunker
 * 
 * This test class covers all scenarios for the DmlChunker including:
 * - Chunking functionality with different sizes
 * - Record validation (homogeneous records)
 * - Edge cases (empty, null, single records)
 * - Optimal chunk size calculations
 * - Error handling for invalid scenarios
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlChunkerTest {
    
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
    
    // ===== CONSTRUCTOR TESTS =====
    
    @IsTest
    static void testDefaultConstructor() {
        // Act
        DmlChunker chunker = new DmlChunker();
        
        // Assert
        System.assertEquals(100, chunker.getChunkSize(), 'Default chunk size should be 100');
    }
    
    @IsTest
    static void testParameterizedConstructor() {
        // Arrange
        Integer customChunkSize = 50;
        
        // Act
        DmlChunker chunker = new DmlChunker(customChunkSize);
        
        // Assert
        System.assertEquals(customChunkSize, chunker.getChunkSize(), 'Chunk size should match constructor parameter');
    }
    
    // ===== CHUNK SIZE TESTS =====
    
    @IsTest
    static void testSetChunkSize() {
        // Arrange
        DmlChunker chunker = new DmlChunker();
        Integer newChunkSize = 75;
        
        // Act
        DmlChunker result = chunker.setChunkSize(newChunkSize);
        
        // Assert
        System.assertEquals(chunker, result, 'Should return self for chaining');
        System.assertEquals(newChunkSize, chunker.getChunkSize(), 'Chunk size should be updated');
    }
    
    @IsTest
    static void testGetChunkSize() {
        // Arrange
        Integer expectedSize = 25;
        DmlChunker chunker = new DmlChunker(expectedSize);
        
        // Act
        Integer actualSize = chunker.getChunkSize();
        
        // Assert
        System.assertEquals(expectedSize, actualSize, 'Should return correct chunk size');
    }
    
    // ===== SPLIT TESTS =====
    
    @IsTest
    static void testSplitWithExactChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(100);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create exactly one chunk');
        System.assertEquals(100, chunks[0].size(), 'Chunk should contain all records');
    }
    
    @IsTest
    static void testSplitWithMultipleChunks() {
        // Arrange
        List<Account> accounts = createTestAccounts(250);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(3, chunks.size(), 'Should create 3 chunks');
        System.assertEquals(100, chunks[0].size(), 'First chunk should have 100 records');
        System.assertEquals(100, chunks[1].size(), 'Second chunk should have 100 records');
        System.assertEquals(50, chunks[2].size(), 'Third chunk should have 50 records');
    }
    
    @IsTest
    static void testSplitWithSmallerChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        DmlChunker chunker = new DmlChunker(3);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(4, chunks.size(), 'Should create 4 chunks');
        System.assertEquals(3, chunks[0].size(), 'First chunk should have 3 records');
        System.assertEquals(3, chunks[1].size(), 'Second chunk should have 3 records');
        System.assertEquals(3, chunks[2].size(), 'Third chunk should have 3 records');
        System.assertEquals(1, chunks[3].size(), 'Fourth chunk should have 1 record');
    }
    
    @IsTest
    static void testSplitWithEmptyRecords() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(0, chunks.size(), 'Should return empty list for empty records');
    }
    
    @IsTest
    static void testSplitWithNullRecords() {
        // Arrange
        List<Account> accounts = null;
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(0, chunks.size(), 'Should return empty list for null records');
    }
    
    @IsTest
    static void testSplitWithSingleRecord() {
        // Arrange
        List<Account> accounts = createTestAccounts(1);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create one chunk');
        System.assertEquals(1, chunks[0].size(), 'Chunk should contain the single record');
    }
    
    @IsTest
    static void testSplitWithLargeDataset() {
        // Arrange
        List<Account> accounts = createTestAccounts(1000);
        DmlChunker chunker = new DmlChunker(50);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(20, chunks.size(), 'Should create 20 chunks');
        
        // Verify all chunks except the last have the correct size
        for (Integer i = 0; i < chunks.size() - 1; i++) {
            System.assertEquals(50, chunks[i].size(), 'Chunk ' + i + ' should have 50 records');
        }
        
        // Verify the last chunk has the remaining records
        System.assertEquals(0, chunks[chunks.size() - 1].size(), 'Last chunk should have 0 records (all processed)');
    }
    
    // ===== VALIDATION TESTS =====
    
    @IsTest
    static void testValidateHomogeneousRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - should not throw exception for homogeneous records
        chunker.validateHomogeneousRecords(accounts);
        System.assert(true, 'Should validate homogeneous records successfully');
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithEmptyList() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - should not throw exception for empty list
        chunker.validateHomogeneousRecords(accounts);
        System.assert(true, 'Should validate empty list successfully');
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithNullList() {
        // Arrange
        List<Account> accounts = null;
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - should not throw exception for null list
        chunker.validateHomogeneousRecords(accounts);
        System.assert(true, 'Should validate null list successfully');
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithSingleRecord() {
        // Arrange
        List<Account> accounts = createTestAccounts(1);
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - should not throw exception for single record
        chunker.validateHomogeneousRecords(accounts);
        System.assert(true, 'Should validate single record successfully');
    }
    
    @IsTest
    static void testValidateHeterogeneousRecords() {
        // Arrange
        List<SObject> mixedRecords = new List<SObject>();
        mixedRecords.add(new Account(Name = 'Test Account'));
        mixedRecords.add(new Contact(FirstName = 'Test', LastName = 'Contact'));
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - should throw exception for heterogeneous records
        try {
            chunker.validateHomogeneousRecords(mixedRecords);
            System.assert(false, 'Should have thrown exception for heterogeneous records');
        } catch (DmlChunker.DmlException e) {
            System.assert(e.getMessage().contains('All records must be of the same SObject type'));
        }
    }
    
    // ===== CHUNK COUNT TESTS =====
    
    @IsTest
    static void testGetChunkCount() {
        // Arrange
        DmlChunker chunker = new DmlChunker(100);
        
        // Act & Assert
        System.assertEquals(0, chunker.getChunkCount(0), 'Should return 0 for 0 records');
        System.assertEquals(1, chunker.getChunkCount(50), 'Should return 1 for 50 records');
        System.assertEquals(1, chunker.getChunkCount(100), 'Should return 1 for 100 records');
        System.assertEquals(2, chunker.getChunkCount(150), 'Should return 2 for 150 records');
        System.assertEquals(3, chunker.getChunkCount(250), 'Should return 3 for 250 records');
    }
    
    @IsTest
    static void testGetChunkCountWithSmallChunkSize() {
        // Arrange
        DmlChunker chunker = new DmlChunker(10);
        
        // Act & Assert
        System.assertEquals(0, chunker.getChunkCount(0), 'Should return 0 for 0 records');
        System.assertEquals(1, chunker.getChunkCount(5), 'Should return 1 for 5 records');
        System.assertEquals(1, chunker.getChunkCount(10), 'Should return 1 for 10 records');
        System.assertEquals(2, chunker.getChunkCount(15), 'Should return 2 for 15 records');
        System.assertEquals(5, chunker.getChunkCount(50), 'Should return 5 for 50 records');
    }
    
    // ===== OPTIMAL CHUNK SIZE TESTS =====
    
    @IsTest
    static void testGetOptimalChunkSize() {
        // Act
        Integer optimalSize = DmlChunker.getOptimalChunkSize();
        
        // Assert
        System.assertEquals(100, optimalSize, 'Optimal chunk size should be 100');
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testSplitWithZeroChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker(0);
        
        // Act & Assert - should handle zero chunk size gracefully
        List<List<SObject>> chunks = chunker.split(accounts);
        System.assertEquals(0, chunks.size(), 'Should return empty list for zero chunk size');
    }
    
    @IsTest
    static void testSplitWithNegativeChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker(-10);
        
        // Act & Assert - should handle negative chunk size gracefully
        List<List<SObject>> chunks = chunker.split(accounts);
        System.assertEquals(0, chunks.size(), 'Should return empty list for negative chunk size');
    }
    
    @IsTest
    static void testSplitWithChunkSizeLargerThanRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create one chunk');
        System.assertEquals(5, chunks[0].size(), 'Chunk should contain all records');
    }
    
    // ===== COMPLEX SCENARIO TESTS =====
    
    @IsTest
    static void testComplexChunkingScenario() {
        // Arrange
        List<Account> accounts = createTestAccounts(1234);
        DmlChunker chunker = new DmlChunker(123);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(11, chunks.size(), 'Should create 11 chunks');
        
        // Verify all chunks except the last have the correct size
        for (Integer i = 0; i < chunks.size() - 1; i++) {
            System.assertEquals(123, chunks[i].size(), 'Chunk ' + i + ' should have 123 records');
        }
        
        // Verify the last chunk has the remaining records
        System.assertEquals(1, chunks[chunks.size() - 1].size(), 'Last chunk should have 1 record');
    }
    
    @IsTest
    static void testChunkingWithDifferentSObjectTypes() {
        // Arrange
        List<Contact> contacts = createTestContacts(100);
        DmlChunker chunker = new DmlChunker(25);
        
        // Act
        List<List<SObject>> chunks = chunker.split(contacts);
        
        // Assert
        System.assertEquals(4, chunks.size(), 'Should create 4 chunks');
        
        for (Integer i = 0; i < chunks.size(); i++) {
            System.assertEquals(25, chunks[i].size(), 'Chunk ' + i + ' should have 25 records');
        }
    }
    
    @IsTest
    static void testChunkingWithExactMultiple() {
        // Arrange
        List<Account> accounts = createTestAccounts(300);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(3, chunks.size(), 'Should create 3 chunks');
        
        for (Integer i = 0; i < chunks.size(); i++) {
            System.assertEquals(100, chunks[i].size(), 'Chunk ' + i + ' should have 100 records');
        }
    }
    
    // ===== PERFORMANCE TESTS =====
    
    @IsTest
    static void testChunkingPerformance() {
        // Arrange
        List<Account> accounts = createTestAccounts(10000);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        Long startTime = System.currentTimeMillis();
        List<List<SObject>> chunks = chunker.split(accounts);
        Long endTime = System.currentTimeMillis();
        
        // Assert
        System.assertEquals(100, chunks.size(), 'Should create 100 chunks');
        System.assert(endTime - startTime < 1000, 'Chunking should complete within 1 second');
    }
    
    // ===== INTEGRATION TESTS =====
    
    @IsTest
    static void testChunkingWithValidation() {
        // Arrange
        List<Account> accounts = createTestAccounts(500);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        chunker.validateHomogeneousRecords(accounts);
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(5, chunks.size(), 'Should create 5 chunks');
        
        // Verify all chunks contain homogeneous records
        for (List<SObject> chunk : chunks) {
            if (!chunk.isEmpty()) {
                Schema.SObjectType expectedType = chunk[0].getSObjectType();
                for (SObject record : chunk) {
                    System.assertEquals(expectedType, record.getSObjectType(), 'All records in chunk should be same type');
                }
            }
        }
    }
} 