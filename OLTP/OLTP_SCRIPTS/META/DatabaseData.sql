-- ОДИН запрос: Вся информация о базе MarketData
USE MarketData;
SELECT 
    'База данных' as [Объект],
    DB_NAME() as [Имя],
    DATABASEPROPERTYEX(DB_NAME(), 'Recovery') as [МодельВосстановления],
    DATABASEPROPERTYEX(DB_NAME(), 'Status') as [Статус]
UNION ALL
SELECT 
    'Таблица: ' + TABLE_NAME,
    'Строк: ' + FORMAT(SUM(p.rows), 'N0'),
    'Размер: ' + FORMAT(SUM(a.total_pages) * 8 / 1024.0, 'N2') + ' MB',
    ''
FROM INFORMATION_SCHEMA.TABLES t
JOIN sys.partitions p ON OBJECT_NAME(p.object_id) = t.TABLE_NAME
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.TABLE_SCHEMA = 'dbo'
GROUP BY t.TABLE_NAME
UNION ALL
SELECT 
    'Диск: ' + LEFT(physical_name, 1),
    'Путь: ' + physical_name,
    'Размер: ' + CAST(size/128.0 as varchar) + ' MB',
    ''
FROM sys.master_files 
WHERE database_id = DB_ID('MarketData')
ORDER BY [Объект];