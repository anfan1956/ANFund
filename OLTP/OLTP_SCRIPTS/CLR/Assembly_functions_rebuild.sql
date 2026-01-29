USE [cTrader];
GO


/*
		D:\TradingSystems\OLTP\OLTP\CLR\Assembly_functions_rebuild.sql

*/

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

CREATE FUNCTION dbo.CalculateAllMASeriesBatch(
    @timeGap INT,
    @filterTimeframeID INT,
    @filterTickerJID INT
)
RETURNS TABLE (
    BarID BIGINT,
    TickerJID INT,
    TimeFrameID INT,
    BarTime DATETIME,
    MA5 DECIMAL(18,8),
    MA8 DECIMAL(18,8),
    MA20 DECIMAL(18,8),
    MA30 DECIMAL(18,8),
    MA50 DECIMAL(18,8),
    MA100 DECIMAL(18,8),
    MA200 DECIMAL(18,8),
    MA500 DECIMAL(18,8),
    MA21_FIB DECIMAL(18,8),
    MA55_FIB DECIMAL(18,8),
    MA144_FIB DECIMAL(18,8),
    MA233_FIB DECIMAL(18,8),
    MA195_NYSE DECIMAL(18,8),
    MA390_NYSE DECIMAL(18,8)
)
AS EXTERNAL NAME SQL_CLR_EMA.[MACalculationsBatch].CalculateAllMASeriesBatch;
GO


-- 4. Создать функцию с правильными типами
CREATE FUNCTION dbo.CalculateAllEMASeriesBatch(
    @timeGap INT,
    @filterTimeframeID INT,
    @filterTickerJID INT
)
RETURNS TABLE (
    BarID BIGINT,
    TickerJID INT,
    TimeFrameID INT,
    BarTime DATETIME,
    EMA_5_SHORT DECIMAL(18,8),
    EMA_9_MACD_SIGNAL DECIMAL(18,8),
    EMA_12_MACD_FAST DECIMAL(18,8),
    EMA_20_SHORT DECIMAL(18,8),
    EMA_26_MACD_SLOW DECIMAL(18,8),
    EMA_50_MEDIUM DECIMAL(18,8),
    EMA_100_LONG DECIMAL(18,8),
    EMA_200_LONG DECIMAL(18,8),
    EMA_21_FIBO DECIMAL(18,8),
    EMA_55_FIBO DECIMAL(18,8),
    EMA_144_FIBO DECIMAL(18,8),
    EMA_233_FIBO DECIMAL(18,8),
    EMA_8_SHORT DECIMAL(18,8)
)
AS EXTERNAL NAME SQL_CLR_EMA.[EMACalculationsBatch].CalculateAllEMASeriesBatch;
GO


-- 3. Создать функцию с BarID
CREATE FUNCTION dbo.CalculateAllMomentumBatch(
    @timeGap INT,
    @filterTimeframeID INT,
    @filterTickerJID INT
)
RETURNS TABLE (
    BarID BIGINT,
    TickerJID INT,
    TimeFrameID INT,
    BarTime DATETIME,
    RSI_14 DECIMAL(8,4),
    RSI_7 DECIMAL(8,4),
    RSI_21 DECIMAL(8,4),
    RSI_ZScore DECIMAL(8,4),
    RSI_Percentile DECIMAL(8,4),
    RSI_Slope_5 DECIMAL(8,4),
    Stoch_K_14 DECIMAL(8,4),
    Stoch_D_14 DECIMAL(8,4),
    Stoch_Slope DECIMAL(8,4),
    ROC_14 DECIMAL(12,6),
    ROC_7 DECIMAL(12,6),
    Momentum_Score DECIMAL(8,4),
    Overbought_Flag BIT,
    Oversold_Flag BIT
)
AS EXTERNAL NAME SQL_CLR_EMA.[MomentumAllInOneCalculationsBatch].CalculateAllMomentumBatch;
GO