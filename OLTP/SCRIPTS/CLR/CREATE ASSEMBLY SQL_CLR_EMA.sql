USE [cTrader];
GO

-- 1. Удаляем функции
IF OBJECT_ID('dbo.fn_CalculateMultipleEMASeries_CLR') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateMultipleEMASeries_CLR;

IF OBJECT_ID('dbo.CalculateAllEMASeriesBatch') IS NOT NULL
    DROP FUNCTION dbo.CalculateAllEMASeriesBatch;
GO

-- 2. Удаляем сборку
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'SQL_CLR_EMA')
    DROP ASSEMBLY SQL_CLR_EMA;
GO

-- 3. Создаем сборку из исправленной DLL
CREATE ASSEMBLY SQL_CLR_EMA
FROM 'D:\TradingSystems\CLR\SQL_CLR_EMA\bin\Debug\SQL_CLR_EMA.dll'
WITH PERMISSION_SET = SAFE;
GO

-- 4. Создаем старую функцию
CREATE FUNCTION dbo.fn_CalculateMultipleEMASeries_CLR(
    @tickerJID INT,
    @timeframeID INT,
    @fromTime DATETIME
)
RETURNS TABLE (
    BarTime DATETIME,
    CloseValue FLOAT,
    EMA_5_SHORT FLOAT,
    EMA_9_MACD_SIGNAL FLOAT,
    EMA_20_SHORT FLOAT,
    EMA_50_MEDIUM FLOAT
)
AS EXTERNAL NAME SQL_CLR_EMA.[EMATableFunction].CalculateMultipleEMASeries;
GO

-- 5. Создаем новую функцию
CREATE FUNCTION dbo.CalculateAllEMASeriesBatch(
    @timeGap INT = NULL,
    @filterTimeframeID INT = NULL,
    @filterTickerJID INT = NULL,
    @useExistingEMA BIT = 0
)
RETURNS TABLE (
    TickerJID INT,
    timeframeID INT,
    BarTime DATETIME,
    CloseValue FLOAT,
    EMA_5_SHORT FLOAT,
    EMA_9_MACD_SIGNAL FLOAT,
    EMA_20_SHORT FLOAT,
    EMA_50_MEDIUM FLOAT
)
AS EXTERNAL NAME SQL_CLR_EMA.[EMACalculationsBatch].CalculateAllEMASeriesBatch;
GO

-- 6. Проверяем
SELECT TOP 1 BarTime FROM dbo.fn_CalculateMultipleEMASeries_CLR(1001, 5, DATEADD(HOUR, -1, GETDATE()));

SELECT TOP 1 TickerJID FROM dbo.CalculateAllEMASeriesBatch(10, NULL, NULL, 0);
GO