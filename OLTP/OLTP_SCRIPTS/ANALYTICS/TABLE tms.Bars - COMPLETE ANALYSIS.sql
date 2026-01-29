USE [cTrader]
GO

PRINT '=== TABLE tms.Bars - COMPLETE ANALYSIS ===';
PRINT '';

-- 1. —“–” “”–¿ “¿¡À»÷€
PRINT '1. TABLE COLUMNS:';
SELECT 
    c.column_id AS ID,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS DataType,
    c.max_length AS MaxLength,
    c.precision AS Precision,
    c.scale AS Scale,
    CASE WHEN c.is_nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END AS Nullable,
    CASE WHEN c.is_identity = 1 THEN 'YES' ELSE '' END AS IsIdentity
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('tms.Bars')
ORDER BY c.column_id;
GO

-- 2. œ≈–¬»◊Õ€…  Àﬁ◊
PRINT '';
PRINT '2. PRIMARY KEY:';
SELECT 
    i.name AS PK_Name,
    'Primary Key' AS Type
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('tms.Bars')
    AND i.is_primary_key = 1;
GO

-- 3. ”Õ» ¿À‹Õ€≈ Œ√–¿Õ»◊≈Õ»ﬂ
PRINT '';
PRINT '3. UNIQUE CONSTRAINTS:';
SELECT 
    k.name AS ConstraintName,
    'Unique Constraint' AS Type
FROM sys.key_constraints k
WHERE k.parent_object_id = OBJECT_ID('tms.Bars')
    AND k.type = 'UQ';
GO

-- 4. »Õƒ≈ —€ (œ–Œ—“Œ… ¬¿–»¿Õ“)
PRINT '';
PRINT '4. INDEXES (SIMPLE VIEW):';
SELECT 
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPK
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('tms.Bars')
    AND i.name IS NOT NULL
ORDER BY i.is_primary_key DESC, i.is_unique DESC, i.name;
GO

-- 5. —“¿“»—“» »
PRINT '';
PRINT '5. STATISTICS:';
SELECT 
    s.name AS StatName,
    CASE WHEN s.auto_created = 1 THEN 'Auto' ELSE 'User' END AS CreatedBy,
    s.has_filter AS HasFilter
FROM sys.stats s
WHERE s.object_id = OBJECT_ID('tms.Bars')
ORDER BY s.auto_created, s.name;
GO

-- 6. ¬Õ≈ÿÕ»≈  Àﬁ◊»
PRINT '';
PRINT '6. FOREIGN KEYS:';
SELECT 
    fk.name AS FK_Name,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencesTable
FROM sys.foreign_keys fk
WHERE fk.parent_object_id = OBJECT_ID('tms.Bars');
GO

-- 7. CHECK CONSTRAINTS
PRINT '';
PRINT '7. CHECK CONSTRAINTS:';
SELECT 
    cc.name AS CheckName,
    cc.definition AS Definition
FROM sys.check_constraints cc
WHERE cc.parent_object_id = OBJECT_ID('tms.Bars');
GO

-- 8. DEFAULT CONSTRAINTS
PRINT '';
PRINT '8. DEFAULT CONSTRAINTS:';
SELECT 
    dc.name AS DefaultName,
    col.name AS ColumnName
FROM sys.default_constraints dc
INNER JOIN sys.columns col ON dc.parent_object_id = col.object_id AND dc.parent_column_id = col.column_id
WHERE dc.parent_object_id = OBJECT_ID('tms.Bars');
GO

-- 9. “–»√√≈–€
PRINT '';
PRINT '9. TRIGGERS:';
SELECT 
    tr.name AS TriggerName,
    tr.type_desc AS TriggerType
FROM sys.triggers tr
WHERE tr.parent_id = OBJECT_ID('tms.Bars');
GO

-- 10. –¿«Ã≈– “¿¡À»÷€
PRINT '';
PRINT '10. TABLE SIZE (ESTIMATE):';
SELECT 
    SUM(row_count) AS TotalRows,
    COUNT(*) AS PartitionCount
FROM sys.dm_db_partition_stats
WHERE object_id = OBJECT_ID('tms.Bars')
    AND index_id IN (0, 1);
GO