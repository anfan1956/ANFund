SELECT 
    TABLE_SCHEMA AS [Schema],
    TABLE_NAME AS [Table],
    'TABLE' AS [Type],
    COLUMN_NAME AS [Column],
    DATA_TYPE AS [DataType],
    CASE 
        WHEN COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1 THEN 'PK'
        WHEN EXISTS (
            SELECT 1 
            FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            WHERE kcu.TABLE_SCHEMA = c.TABLE_SCHEMA 
              AND kcu.TABLE_NAME = c.TABLE_NAME 
              AND kcu.COLUMN_NAME = c.COLUMN_NAME
        ) THEN 'FK'
        ELSE ''
    END AS [KeyType],
    IS_NULLABLE AS [Nullable]
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE TABLE_SCHEMA IN ('dbo', 'algo', 'tms', 'trd')
  AND TABLE_NAME IN (
    'strategy_classes',
    'strategies',
    'strategy_configurations',
    'ParameterSets',
    'ConfigurationSets',
    'bars',
    'EMA',
    'Indicators_Momentum',
    'trades_v',
    'timeframes'
  )
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;

SELECT 
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS [ParentSchema],
    OBJECT_NAME(fk.parent_object_id) AS [ParentTable],
    cpa.name AS [ParentColumn],
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS [ReferencedSchema],
    OBJECT_NAME(fk.referenced_object_id) AS [ReferencedTable],
    cref.name AS [ReferencedColumn],
    fk.name AS [ForeignKeyName]
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.columns cpa ON fkc.parent_object_id = cpa.object_id AND fkc.parent_column_id = cpa.column_id
INNER JOIN sys.columns cref ON fkc.referenced_object_id = cref.object_id AND fkc.referenced_column_id = cref.column_id
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) IN ('dbo', 'algo', 'tms', 'trd')
   OR OBJECT_SCHEMA_NAME(fk.referenced_object_id) IN ('dbo', 'algo', 'tms', 'trd')
ORDER BY [ParentSchema], [ParentTable], [ForeignKeyName];