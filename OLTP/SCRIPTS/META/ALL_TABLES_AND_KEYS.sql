-- ¬—≈ “¿¡À»÷€, œ–≈ƒ—“¿¬À≈Õ»ﬂ » “¿¡À»◊Õ€≈ ‘”Õ ÷»» — DEFAULT
if OBJECT_ID ('meta._U_V_IF_TF_OBJECT_v') is not null drop view meta._U_V_IF_TF_OBJECT_v
go
create view meta._U_V_IF_TF_OBJECT_v as

	SELECT 
		SCHEMA_NAME(o.schema_id) AS [SCHEMA],
		CASE 
			WHEN o.type = 'U' THEN 'TABLE'
			WHEN o.type = 'V' THEN 'VIEW'
			WHEN o.type IN ('IF', 'TF') THEN 'TABLE-VALUED FUNCTION'
			ELSE o.type_desc
		END AS [OBJECT_TYPE],
		o.name AS [OBJECT_NAME],
		c.name AS [COLUMN_NAME],
		CASE WHEN pk.column_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS [PRIMARY_KEY],
		CASE WHEN fk.parent_column_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS [FOREIGN_KEY],
		CASE WHEN uk.column_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS [UNIQUE_KEY],
		ty.name + 
			CASE 
				WHEN ty.name IN ('varchar', 'nvarchar', 'char', 'nchar') AND c.max_length > 0 
					THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR) END + ')'
				WHEN ty.name IN ('decimal', 'numeric') 
					THEN '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
				ELSE ''
			END AS [DATA_TYPE],
		CASE WHEN c.is_nullable = 1 THEN 'YES' ELSE 'NO' END AS [NULLABLE],
		-- ƒŒ¡¿¬Àﬂ≈Ã  ŒÀŒÕ ” DEFAULT
		ISNULL(dc.definition, '') AS [DEFAULT_VALUE]
	FROM sys.objects o
	LEFT JOIN sys.columns c ON o.object_id = c.object_id
	LEFT JOIN sys.types ty ON c.user_type_id = ty.user_type_id
	-- ƒŒ¡¿¬Àﬂ≈Ã JOIN ƒÀﬂ DEFAULT CONSTRAINTS
	LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
	LEFT JOIN (
		SELECT ic.object_id, ic.column_id
		FROM sys.indexes i
		INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
		WHERE i.is_primary_key = 1
	) pk ON o.object_id = pk.object_id AND c.column_id = pk.column_id
	LEFT JOIN (
		SELECT fkc.parent_object_id, fkc.parent_column_id
		FROM sys.foreign_keys fk
		INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
	) fk ON o.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
	LEFT JOIN (
		SELECT ic.object_id, ic.column_id
		FROM sys.indexes i
		INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
		WHERE i.is_unique = 1 AND i.is_primary_key = 0 AND i.type IN (1, 2)
	) uk ON o.object_id = uk.object_id AND c.column_id = uk.column_id
	WHERE o.type IN ('U', 'V', 'IF', 'TF')  -- Tables, Views, Inline Table-valued Functions, Table-valued Functions
		--AND SCHEMA_NAME(o.schema_id) IN ('algo', 'tms', 'trd', 'ref')
go

/*

	ORDER BY 
		SCHEMA_NAME(o.schema_id),
		CASE o.type 
			WHEN 'U' THEN 1  -- Tables first
			WHEN 'V' THEN 2  -- Views second
			ELSE 3           -- Functions
		END,
		o.name,
		c.column_id;
*/
select * from meta._U_V_IF_TF_OBJECT_v