use cTrader
go
--select * from ref.SymbolMapping

--select * from tms.Indicators_Momentum
-- Most useful single query for daily use
DECLARE @TableName NVARCHAR(128) = 'bars'  -- 'Indicators_Momentum';
DECLARE @SchemaName NVARCHAR(128) = 'tms';

SELECT 
    col.column_id AS ColumnOrder,
    col.name AS ColumnName,
    typ.name AS DataType,
    CASE 
        WHEN typ.name IN ('varchar', 'char', 'nvarchar', 'nchar') THEN
            CASE WHEN col.max_length = -1 THEN 'MAX' ELSE CAST(col.max_length AS VARCHAR) END
        WHEN typ.name IN ('decimal', 'numeric') THEN
            CAST(col.precision AS VARCHAR) + ',' + CAST(col.scale AS VARCHAR)
        ELSE ''
    END AS SizePrecision,
    CASE WHEN col.is_nullable = 1 THEN 'Yes' ELSE 'No' END AS Nullable,
    CASE 
        WHEN pk.column_id IS NOT NULL THEN 'PK'
        WHEN fk.parent_column_id IS NOT NULL THEN 'FK'
        ELSE ''
    END AS KeyType,
    ISNULL(def.definition, '') AS DefaultValue
FROM 
    sys.tables tab
INNER JOIN 
    sys.columns col ON tab.object_id = col.object_id
INNER JOIN 
    sys.types typ ON col.user_type_id = typ.user_type_id
LEFT JOIN 
    sys.default_constraints def ON col.default_object_id = def.object_id
LEFT JOIN 
    sys.extended_properties ep ON col.object_id = ep.major_id 
        AND col.column_id = ep.minor_id 
        AND ep.class = 1 
        AND ep.name = 'MS_Description'
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM sys.index_columns ic
    INNER JOIN sys.indexes idx ON ic.object_id = idx.object_id AND ic.index_id = idx.index_id
    WHERE idx.is_primary_key = 1
) pk ON col.object_id = pk.object_id AND col.column_id = pk.column_id
LEFT JOIN 
    sys.foreign_key_columns fk ON col.object_id = fk.parent_object_id 
        AND col.column_id = fk.parent_column_id
WHERE 
    tab.name = @TableName
    AND SCHEMA_NAME(tab.schema_id) = @SchemaName
ORDER BY 
    col.column_id;

--select * from tms.Indicators_Momentum