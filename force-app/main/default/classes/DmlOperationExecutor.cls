/**
 * DmlOperationExecutor - Handles core DML operations with proper error handling
 * 
 * This class is responsible for executing DML operations (INSERT, UPDATE, DELETE, UPSERT)
 * and processing the results with detailed error information.
 * 
 * @author DML Utility Team
 * @version 1.0
 */
public class DmlOperationExecutor {
    
    public enum Operation {
        DO_INSERT,
        DO_UPDATE,
        DO_UPSERT,
        DO_DELETE
    }
    
    private String externalIdField;
    
    /**
     * Constructor with external ID field for upsert operations
     * @param externalIdField The external ID field name for upsert operations
     */
    public DmlOperationExecutor(String externalIdField) {
        this.externalIdField = externalIdField;
    }
    
    /**
     * Executes DML operation on a list of records
     * @param records Records to process
     * @param operation Type of DML operation
     * @return DmlOperationResult Result of the operation
     */
    public DmlOperationResult execute(List<SObject> records, Operation operation) {
        if (records == null || records.isEmpty()) {
            return new DmlOperationResult(new List<SObject>(), new List<String>());
        }
        
        if (operation == DmlOperationExecutor.Operation.DO_INSERT) {
            return executeInsert(records);
        } else if (operation == DmlOperationExecutor.Operation.DO_UPDATE) {
            return executeUpdate(records);
        } else if (operation == DmlOperationExecutor.Operation.DO_DELETE) {
            return executeDelete(records);
        } else if (operation == DmlOperationExecutor.Operation.DO_UPSERT) {
            return executeUpsert(records);
        } else {
            throw new UnsupportedOperationException('Unsupported DML operation: ' + operation);
        }
    }
    
    /**
     * Executes INSERT operation
     * @param records Records to insert
     * @return DmlOperationResult Result of the operation
     */
    private DmlOperationResult executeInsert(List<SObject> records) {
        Database.SaveResult[] results = Database.insert(records, false);
        return processSaveResults(results, records, 'INSERT');
    }
    
    /**
     * Executes UPDATE operation
     * @param records Records to update
     * @return DmlOperationResult Result of the operation
     */
    private DmlOperationResult executeUpdate(List<SObject> records) {
        Database.SaveResult[] results = Database.update(records, false);
        return processSaveResults(results, records, 'UPDATE');
    }
    
    /**
     * Executes DELETE operation
     * @param records Records to delete
     * @return DmlOperationResult Result of the operation
     */
    private DmlOperationResult executeDelete(List<SObject> records) {
        Database.DeleteResult[] results = Database.delete(records, false);
        return processDeleteResults(results, records);
    }
    
    /**
     * Executes UPSERT operation
     * @param records Records to upsert
     * @return DmlOperationResult Result of the operation
     */
    private DmlOperationResult executeUpsert(List<SObject> records) {
        validateUpsertFields(records);
        Schema.SObjectField extIdField = getExternalIdField(records);
        Database.UpsertResult[] results = Database.upsert(records, extIdField, false);
        return processUpsertResults(results, records);
    }
    
    /**
     * Processes save results (INSERT/UPDATE) and extracts failed records
     * @param results Database save results
     * @param records Original records
     * @param operationType Type of operation for error messages
     * @return DmlOperationResult Result with failed records and error messages
     */
    private DmlOperationResult processSaveResults(Database.SaveResult[] results, List<SObject> records, String operationType) {
        List<SObject> failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} ({1}): {2}', 
                        new List<String>{ String.valueOf(i), operationType, err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        return new DmlOperationResult(failedRecords, errorMessages);
    }
    
    /**
     * Processes delete results and extracts failed records
     * @param results Database delete results
     * @param records Original records
     * @return DmlOperationResult Result with failed records and error messages
     */
    private DmlOperationResult processDeleteResults(Database.DeleteResult[] results, List<SObject> records) {
        List<SObject> failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} (DELETE): {1}', 
                        new List<String>{ String.valueOf(i), err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        return new DmlOperationResult(failedRecords, errorMessages);
    }
    
    /**
     * Processes upsert results and extracts failed records
     * @param results Database upsert results
     * @param records Original records
     * @return DmlOperationResult Result with failed records and error messages
     */
    private DmlOperationResult processUpsertResults(Database.UpsertResult[] results, List<SObject> records) {
        List<SObject> failedRecords = new List<SObject>();
        List<String> errorMessages = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failedRecords.add(records[i]);
                
                for (Database.Error err : results[i].getErrors()) {
                    String errorMsg = String.format('Record {0} (UPSERT): {1}', 
                        new List<String>{ String.valueOf(i), err.getMessage() });
                    errorMessages.add(errorMsg);
                }
            }
        }
        
        return new DmlOperationResult(failedRecords, errorMessages);
    }
    
    /**
     * Validates upsert fields before execution
     * @param records Records to validate
     */
    private void validateUpsertFields(List<SObject> records) {
        if (String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert operation.');
        }
        
        Schema.SObjectType objType = records[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        
        if (!fieldsMap.containsKey(externalIdField)) {
            throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
        }
    }
    
    /**
     * Gets the external ID field for upsert operations
     * @param records Records to get external ID field for
     * @return Schema.SObjectField The external ID field
     */
    private Schema.SObjectField getExternalIdField(List<SObject> records) {
        if (String.isBlank(externalIdField)) {
            throw new IllegalArgumentException('Missing External ID for upsert operation.');
        }
        
        Schema.SObjectType objType = records[0].getSObjectType();
        Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
        
        if (!fieldsMap.containsKey(externalIdField)) {
            throw new IllegalArgumentException('Invalid External ID field: ' + externalIdField);
        }
        
        return fieldsMap.get(externalIdField);
    }
    
    /**
     * Result class for DML operations
     */
    public class DmlOperationResult {
        public List<SObject> failedRecords;
        public List<String> errorMessages;
        public Boolean hasFailures;
        
        public DmlOperationResult(List<SObject> failedRecords, List<String> errorMessages) {
            this.failedRecords = failedRecords;
            this.errorMessages = errorMessages;
            this.hasFailures = !failedRecords.isEmpty();
        }
        
        public String getErrorSummary() {
            return String.join(errorMessages, '\n');
        }
    }
} 