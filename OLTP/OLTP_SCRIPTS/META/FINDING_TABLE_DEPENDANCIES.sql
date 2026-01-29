-- Find all objects referencing algo.tradingSignals
SELECT 
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS parent_schema,
    OBJECT_NAME(fk.parent_object_id) AS parent_table,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS parent_column,
    fk.name AS foreign_key_name
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc 
    ON fk.object_id = fkc.constraint_object_id
WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = 'algo' 
    AND OBJECT_NAME(fk.referenced_object_id) = 'tradingSignals'
ORDER BY parent_schema, parent_table
GO

-- Find references to algo.tradingSignals in stored procedures and functions
SELECT 
    OBJECT_SCHEMA_NAME(o.object_id) AS schema_name,
    OBJECT_NAME(o.object_id) AS object_name,
    o.type_desc AS object_type,
    'Procedure/Function' AS reference_type
FROM sys.sql_modules m
INNER JOIN sys.objects o ON m.object_id = o.object_id
WHERE m.definition LIKE '%algo.tradingSignals%'
    AND o.type IN ('P', 'FN', 'TF', 'IF', 'V')  -- Procedures, Functions, Table-valued Functions, Views
ORDER BY schema_name, object_name
GO