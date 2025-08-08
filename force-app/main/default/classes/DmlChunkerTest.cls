/**
 * Test class for DmlChunker
 * 
 * This test class covers all scenarios for the DmlChunker including:
 * - Chunking functionality with different sizes
 * - Record validation (homogeneous records)
 * - Edge cases (empty, null, single records)
 * - Optimal chunk size calculations
 * - Error handling for invalid scenarios
 * - Performance testing with large datasets
 * - Boundary conditions and edge cases
 * 
 * @author DML Utility Team
 * @version 1.0
 */
@IsTest
public class DmlChunkerTest {
    
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
     * Asserts that the expected number of chunks exist with the given size
     * @param chunks List of chunks to check
     * @param expectedChunkSize Expected size of each chunk
     * @param message Assertion message
     */
    private static void assertChunkSizes(List<List<SObject>> chunks, Integer expectedChunkSize, String message) {
        for (Integer i = 0; i < chunks.size(); i++) {
            List<SObject> chunk = chunks[i];
            if (i == chunks.size() - 1) {
                // Last chunk can be smaller than expected size
                System.assert(chunk.size() <= expectedChunkSize, 
                    message + ' - Chunk ' + i + ' should not exceed expected size. Actual: ' + chunk.size() + ', Expected: ' + expectedChunkSize);
            } else {
                System.assertEquals(expectedChunkSize, chunk.size(), 
                    message + ' - Chunk ' + i + ' should have expected size');
            }
        }
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
    
    @IsTest
    static void testParameterizedConstructorWithZero() {
        // Arrange
        Integer customChunkSize = 0;
        
        // Act & Assert
        try {
            DmlChunker chunker = new DmlChunker(customChunkSize);
            System.assert(false, 'Should have thrown exception for zero chunk size');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Chunk size must be greater than 0'), 'Should throw appropriate error message');
        }
    }
    
    @IsTest
    static void testParameterizedConstructorWithNegative() {
        // Arrange
        Integer customChunkSize = -10;
        
        // Act & Assert
        try {
            DmlChunker chunker = new DmlChunker(customChunkSize);
            System.assert(false, 'Should have thrown exception for negative chunk size');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Chunk size must be greater than 0'), 'Should throw appropriate error message');
        }
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
    static void testSetChunkSizeWithZero() {
        // Arrange
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert
        try {
            chunker.setChunkSize(0);
            System.assert(false, 'Should have thrown exception for zero chunk size');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Chunk size must be greater than 0'), 'Should throw appropriate error message');
        }
    }
    
    @IsTest
    static void testSetChunkSizeWithNegative() {
        // Arrange
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert
        try {
            chunker.setChunkSize(-5);
            System.assert(false, 'Should have thrown exception for negative chunk size');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Chunk size must be greater than 0'), 'Should throw appropriate error message');
        }
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
    static void testSplitWithSmallerThanChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(50);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create exactly one chunk');
        System.assertEquals(50, chunks[0].size(), 'Chunk should contain all records');
    }
    
    @IsTest
    static void testSplitWithLargerThanChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(250);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(3, chunks.size(), 'Should create 3 chunks (2 full + 1 partial)');
        System.assertEquals(100, chunks[0].size(), 'First chunk should have 100 records');
        System.assertEquals(100, chunks[1].size(), 'Second chunk should have 100 records');
        System.assertEquals(50, chunks[2].size(), 'Third chunk should have 50 records');
    }
    
    @IsTest
    static void testSplitWithExactMultiple() {
        // Arrange
        List<Account> accounts = createTestAccounts(200);
        DmlChunker chunker = new DmlChunker(50);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(4, chunks.size(), 'Should create 4 chunks');
        assertChunkSizes(chunks, 50, 'All chunks should have 50 records');
    }
    
    @IsTest
    static void testSplitWithSingleRecord() {
        // Arrange
        List<Account> accounts = createTestAccounts(1);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create exactly one chunk');
        System.assertEquals(1, chunks[0].size(), 'Chunk should contain the single record');
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
        DmlChunker chunker = new DmlChunker(100);
        
        // Act & Assert
        try {
            List<List<SObject>> chunks = chunker.split(null);
            System.assert(false, 'Should have thrown exception for null records');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Records cannot be null'), 'Should throw appropriate error message');
        }
    }
    
    @IsTest
    static void testSplitWithCustomChunkSize() {
        // Arrange
        List<Account> accounts = createTestAccounts(75);
        DmlChunker chunker = new DmlChunker(25);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(3, chunks.size(), 'Should create 3 chunks');
        System.assertEquals(25, chunks[0].size(), 'First chunk should have 25 records');
        System.assertEquals(25, chunks[1].size(), 'Second chunk should have 25 records');
        System.assertEquals(25, chunks[2].size(), 'Third chunk should have 25 records');
    }
    
    // ===== VALIDATION TESTS =====
    
    @IsTest
    static void testValidateHomogeneousRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - Should not throw exception
        try {
            chunker.validateHomogeneousRecords(accounts);
            System.assert(true, 'Should not throw exception for homogeneous records');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for homogeneous records: ' + e.getMessage());
        }
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithMixedTypes() {
        // Arrange
        List<SObject> mixedRecords = new List<SObject>();
        mixedRecords.addAll(createTestAccounts(2));
        mixedRecords.addAll(createTestContacts(2));
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert
        try {
            chunker.validateHomogeneousRecords(mixedRecords);
            System.assert(false, 'Should have thrown exception for mixed record types');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('All records must be of the same type'), 'Should throw appropriate error message');
        }
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithEmptyList() {
        // Arrange
        List<Account> accounts = new List<Account>();
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert - Should not throw exception
        try {
            chunker.validateHomogeneousRecords(accounts);
            System.assert(true, 'Should not throw exception for empty list');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for empty list: ' + e.getMessage());
        }
    }
    
    @IsTest
    static void testValidateHomogeneousRecordsWithNull() {
        // Arrange
        DmlChunker chunker = new DmlChunker();
        
        // Act & Assert
        try {
            chunker.validateHomogeneousRecords(null);
            System.assert(false, 'Should have thrown exception for null records');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Records cannot be null'), 'Should throw appropriate error message');
        }
    }
    
    // ===== PERFORMANCE TESTS =====
    
    @IsTest
    static void testSplitWithLargeDataset() {
        // Arrange
        List<Account> accounts = createTestAccounts(1000);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(10, chunks.size(), 'Should create 10 chunks for 1000 records with chunk size 100');
        assertChunkSizes(chunks, 100, 'All chunks should have 100 records except the last');
        System.assertEquals(100, chunks[9].size(), 'Last chunk should have 100 records');
    }
    
    @IsTest
    static void testSplitWithVeryLargeDataset() {
        // Arrange
        List<Account> accounts = createTestAccounts(10000);
        DmlChunker chunker = new DmlChunker(500);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(20, chunks.size(), 'Should create 20 chunks for 10000 records with chunk size 500');
        assertChunkSizes(chunks, 500, 'All chunks should have 500 records except the last');
        System.assertEquals(500, chunks[19].size(), 'Last chunk should have 500 records');
    }
    
    // ===== EDGE CASE TESTS =====
    
    @IsTest
    static void testSplitWithChunkSizeOne() {
        // Arrange
        List<Account> accounts = createTestAccounts(5);
        DmlChunker chunker = new DmlChunker(1);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(5, chunks.size(), 'Should create 5 chunks for 5 records with chunk size 1');
        for (Integer i = 0; i < chunks.size(); i++) {
            System.assertEquals(1, chunks[i].size(), 'Each chunk should have 1 record');
        }
    }
    
    @IsTest
    static void testSplitWithChunkSizeLargerThanRecords() {
        // Arrange
        List<Account> accounts = createTestAccounts(10);
        DmlChunker chunker = new DmlChunker(1000);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create 1 chunk when chunk size is larger than record count');
        System.assertEquals(10, chunks[0].size(), 'Chunk should contain all records');
    }
    
    @IsTest
    static void testSplitWithBoundaryConditions() {
        // Arrange
        List<Account> accounts = createTestAccounts(99);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create 1 chunk when records are just under chunk size');
        System.assertEquals(99, chunks[0].size(), 'Chunk should contain all records');
    }
    
    @IsTest
    static void testSplitWithBoundaryConditionsExact() {
        // Arrange
        List<Account> accounts = createTestAccounts(100);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(1, chunks.size(), 'Should create 1 chunk when records exactly match chunk size');
        System.assertEquals(100, chunks[0].size(), 'Chunk should contain all records');
    }
    
    @IsTest
    static void testSplitWithBoundaryConditionsOver() {
        // Arrange
        List<Account> accounts = createTestAccounts(101);
        DmlChunker chunker = new DmlChunker(100);
        
        // Act
        List<List<SObject>> chunks = chunker.split(accounts);
        
        // Assert
        System.assertEquals(2, chunks.size(), 'Should create 2 chunks when records exceed chunk size by 1');
        System.assertEquals(100, chunks[0].size(), 'First chunk should have 100 records');
        System.assertEquals(1, chunks[1].size(), 'Second chunk should have 1 record');
    }
}