/**
 * DmlChunker - Handles chunking of large datasets for DML operations
 * 
 * This class is responsible for splitting large datasets into manageable chunks
 * to avoid governor limits and improve performance.
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlChunker {
    
    private Integer chunkSize;
    
    /**
     * Constructor with default chunk size of 100
     */
    public DmlChunker() {
        this.chunkSize = 100;
    }
    
    /**
     * Constructor with custom chunk size
     * @param chunkSize The size of each chunk
     */
    public DmlChunker(Integer chunkSize) {
        this.chunkSize = chunkSize;
    }
    
    /**
     * Sets the chunk size
     * @param chunkSize The size of each chunk
     * @return DmlChunker This instance for chaining
     */
    public DmlChunker setChunkSize(Integer chunkSize) {
        this.chunkSize = chunkSize;
        return this;
    }
    
    /**
     * Gets the current chunk size
     * @return Integer The chunk size
     */
    public Integer getChunkSize() {
        return chunkSize;
    }
    
    /**
     * Splits a list of records into chunks
     * @param records The records to split
     * @return List<List<SObject>> List of chunks
     */
    public List<List<SObject>> split(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<List<SObject>>();
        }
        
        // Handle invalid chunk sizes
        if (chunkSize <= 0) {
            return new List<List<SObject>>();
        }
        
        List<List<SObject>> chunks = new List<List<SObject>>();
        
        for (Integer i = 0; i < records.size(); i += chunkSize) {
            Integer toIndex = Math.min(i + chunkSize, records.size());
            List<SObject> chunk = new List<SObject>();
            
            for (Integer j = i; j < toIndex; j++) {
                chunk.add(records[j]);
            }
            
            chunks.add(chunk);
        }
        
        return chunks;
    }
    
    /**
     * Validates that all records in a list are of the same SObject type
     * @param records The records to validate
     * @throws DmlException If records are not homogeneous
     */
    public void validateHomogeneousRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        
        Schema.SObjectType expectedType = records[0].getSObjectType();
        
        for (SObject record : records) {
            if (record.getSObjectType() != expectedType) {
                throw new DmlException('All records must be of the same SObject type.');
            }
        }
    }
    
    /**
     * Gets the number of chunks that would be created for a given number of records
     * @param recordCount The number of records
     * @return Integer The number of chunks
     */
    public Integer getChunkCount(Integer recordCount) {
        if (recordCount == 0) return 0;
        return Math.ceil(recordCount / (Double)chunkSize).intValue();
    }
    
    /**
     * Gets the optimal chunk size based on governor limits
     * @return Integer The optimal chunk size
     */
    public static Integer getOptimalChunkSize() {
        // Consider DML governor limits (10,000 records per transaction)
        // and heap size limits
        return 100;
    }
    
    /**
     * Exception thrown for DML-related errors
     */
    public class DmlException extends Exception {}
}