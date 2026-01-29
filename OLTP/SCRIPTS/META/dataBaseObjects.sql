use cTrader
go



WITH TableInfo AS (
    SELECT 
        s.name AS SchemaName,
        t.name AS TableName,
        t.create_date AS CreatedDate,
        t.modify_date AS ModifiedDate,
        p.rows AS RowsCount
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.partitions p ON t.object_id = p.object_id 
        AND p.index_id IN (0, 1) -- Heap or clustered index
    GROUP BY s.name, t.name, t.create_date, t.modify_date, p.rows
),
ColumnInfo AS (
    SELECT 
        s.name AS SchemaName,
        t.name AS TableName,
        c.name AS ColumnName,
        ty.name AS DataType,
        c.max_length AS MaxLength,
        c.precision AS Precision,
        c.scale AS Scale,
        c.is_nullable AS IsNullable,
        c.is_identity AS IsIdentity,
        c.is_computed AS IsComputed,
        ISNULL((
            SELECT TOP 1 i.is_primary_key
            FROM sys.index_columns ic
            INNER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
            WHERE ic.object_id = c.object_id AND ic.column_id = c.column_id AND i.is_primary_key = 1
        ), 0) AS IsPrimaryKeyPart,
        COLUMNPROPERTY(c.object_id, c.name, 'IsRowGuidCol') AS IsRowGuidCol
    FROM sys.columns c
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
),
KeyInfo AS (
    SELECT 
        s.name AS SchemaName,
        t.name AS TableName,
        i.name AS KeyName,
        CASE 
            WHEN i.is_primary_key = 1 THEN 'PRIMARY KEY'
            WHEN i.is_unique_constraint = 1 THEN 'UNIQUE CONSTRAINT'
            ELSE 'INDEX'
        END AS KeyType,
        i.type_desc AS IndexType,
        STUFF((
            SELECT ', ' + c.name
            FROM sys.index_columns ic
            INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
            ORDER BY ic.key_ordinal
            FOR XML PATH('')
        ), 1, 2, '') AS KeyColumns,
        i.is_unique AS IsUnique,
        i.is_primary_key AS IsPrimaryKey,
        i.is_unique_constraint AS IsUniqueConstraint
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE i.type IN (1, 2) -- Clustered (1) or Nonclustered (2)
        AND i.is_hypothetical = 0
        AND i.type_desc <> 'HEAP'
        AND (i.is_primary_key = 1 OR i.is_unique_constraint = 1 OR i.is_unique = 1)
)
SELECT 
    ti.SchemaName,
    ti.TableName,
    ti.RowsCount,
    ti.CreatedDate,
    ti.ModifiedDate,
    ci.ColumnName,
    ci.DataType + 
        CASE 
            WHEN ci.DataType IN ('varchar', 'nvarchar', 'char', 'nchar', 'varbinary') 
                THEN '(' + CASE WHEN ci.MaxLength = -1 THEN 'MAX' ELSE CAST(ci.MaxLength AS VARCHAR(10)) END + ')'
            WHEN ci.DataType IN ('decimal', 'numeric') 
                THEN '(' + CAST(ci.Precision AS VARCHAR(10)) + ',' + CAST(ci.Scale AS VARCHAR(10)) + ')'
            ELSE ''
        END AS FullDataType,
    CASE WHEN ci.IsNullable = 1 THEN 'NULL' ELSE 'NOT NULL' END AS Nullability,
    CASE WHEN ci.IsIdentity = 1 THEN 'IDENTITY' ELSE '' END AS IdentityInfo,
    CASE WHEN ci.IsPrimaryKeyPart = 1 THEN 'PK' ELSE '' END AS PrimaryKeyIndicator,
    CASE WHEN ci.IsRowGuidCol = 1 THEN 'ROWGUID' ELSE '' END AS RowGuidIndicator,
    CASE WHEN ci.IsComputed = 1 THEN 'COMPUTED' ELSE '' END AS ComputedIndicator,
    ki.KeyName,
    ki.KeyType,
    ki.KeyColumns AS KeyColumnList
FROM TableInfo ti
LEFT JOIN ColumnInfo ci ON ti.SchemaName = ci.SchemaName AND ti.TableName = ci.TableName
LEFT JOIN KeyInfo ki ON ti.SchemaName = ki.SchemaName AND ti.TableName = ki.TableName
ORDER BY 
    ti.SchemaName, 
    ti.TableName, 
    ci.ColumnName,
    ki.KeyType DESC;
GO

