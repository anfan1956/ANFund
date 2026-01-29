IF OBJECT_ID('tms.CalculateMarketRegimeBatch') IS NOT NULL
    DROP FUNCTION tms.CalculateMarketRegimeBatch;
GO


CREATE FUNCTION tms.CalculateMarketRegimeBatch(
    @timeGap INT = NULL,
    @filterTimeframeID INT = NULL,
    @filterTickerJID INT = NULL
)
RETURNS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    ATR_14 decimal(18,8),
    ATR_Percent decimal(8,4),
    Historical_Volatility_20 decimal(8,4),
    ADX_14 decimal(8,4),
    Plus_DI_14 decimal(8,4),
    Minus_DI_14 decimal(8,4),
    Inside_Bar_Flag bit,
    Outside_Bar_Flag bit,
    Pin_Bar_Flag bit,
    Chandelier_Exit_Long decimal(18,8),
    Chandelier_Exit_Short decimal(18,8),
    Primary_Regime tinyint,
    Regime_Confidence decimal(8,4),
    Regime_Change_Flag bit,
    Trend_Score decimal(8,4),
    Momentum_Score decimal(8,4),
    Volatility_Score decimal(8,4),
    Overall_Score decimal(8,4)
)
AS EXTERNAL NAME [SQL_CLR_MarketRegime].[MarketRegimeCalculationsBatch].[CalculateAllRegimeComponentsBatch];
GO


DECLARE @start datetime = GETDATE();
EXEC tms.CalculateMarketRegimeBulk @timeGap = 60;
SELECT DATEDIFF(MILLISECOND, @start, GETDATE()) as timeElapsedMs;

SELECT  * FROM tms.MarketRegime_Final ORDER BY BarTime DESC;
SELECT 
    COUNT(*) as TotalBarsLastHour,
    COUNT(DISTINCT TickerJID) as TickersCount,
    COUNT(DISTINCT TimeFrameID) as TimeframesCount
FROM tms.bars 
WHERE BarTime > DATEADD(MINUTE, -60, GETUTCDATE());

SELECT COUNT(*) as TotalBars FROM tms.bars;

go
DECLARE @start datetime = GETDATE();
EXEC tms.CalculateMarketRegimeBulk @timeGap = NULL;
SELECT DATEDIFF(SECOND, @start, GETDATE()) as timeElapsedSeconds;

SELECT  count(*) FROM tms.MarketRegime_Final ORDER BY BarTime DESC;

-- Индексы на tms.bars
SELECT 
    i.name as IndexName,
    COL_NAME(ic.object_id, ic.column_id) as ColumnName,
    ic.index_column_id,
    ic.is_included_column
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE i.object_id = OBJECT_ID('tms.bars')
ORDER BY i.name, ic.key_ordinal;

-- Индексы на таблицах режима
SELECT 
    t.name as TableName,
    i.name as IndexName,
    i.type_desc as IndexType
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
WHERE t.schema_id = SCHEMA_ID('tms')
    AND t.name LIKE 'MarketRegime_%'
    AND i.index_id > 0
ORDER BY t.name, i.index_id;



EXEC tms.CalculateMarketRegimeBulk @timeGap = NULL;
SELECT 'Volatility' as TableName, COUNT(*) as RowsCount FROM tms.MarketRegime_Volatility
UNION ALL
SELECT 'Trend', COUNT(*) FROM tms.MarketRegime_Trend
UNION ALL  
SELECT 'Patterns', COUNT(*) FROM tms.MarketRegime_Patterns
UNION ALL
SELECT 'Stops', COUNT(*) FROM tms.MarketRegime_Stops
UNION ALL
SELECT 'Final', COUNT(*) FROM tms.MarketRegime_Final
UNION ALL
SELECT 'BARS', COUNT(*) FROM tms.bars;