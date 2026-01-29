-- Посчитаем среднее время
SELECT 
    AVG(DurationMs) as AvgDurationMA,
    MIN(DurationMs) as MinDurationMA,
    MAX(DurationMs) as MaxDurationMA
FROM tms.IndicatorCalculationLog
WHERE Status = 'SUCCESS'
  AND CalculationTime >= DATEADD(HOUR, -1, GETDATE());

-- Последние 5 выполнений Momentum
SELECT TOP 5
    CalculationTime,
    DurationMs,
    Status
FROM tms.IndicatorCalculationLog
ORDER BY CalculationTime DESC;

USE cTrader
GO

SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.name LIKE '%MA%' 
   OR t.name LIKE '%EMA%'
ORDER BY t.name, i.name;



USE cTrader
GO


--создать правильный индекс
USE cTrader
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_EMA_Primary_Lookup' AND object_id = OBJECT_ID('tms.EMA'))
    DROP INDEX IX_EMA_Primary_Lookup ON tms.EMA
GO

CREATE INDEX IX_EMA_Primary_Lookup 
    ON tms.EMA (TickerJID, TimeFrameID, BarTime DESC)
    INCLUDE (EMA_5_SHORT, EMA_20_SHORT, EMA_50_MEDIUM, EMA_100_LONG, EMA_200_LONG);
GO




--Проверяем колонки в МА
USE cTrader
GO

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'tms' 
  AND TABLE_NAME = 'MA'
ORDER BY ORDINAL_POSITION;


--и в EMA
USE cTrader
GO

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'tms' 
  AND TABLE_NAME = 'EMA'
ORDER BY ORDINAL_POSITION;


