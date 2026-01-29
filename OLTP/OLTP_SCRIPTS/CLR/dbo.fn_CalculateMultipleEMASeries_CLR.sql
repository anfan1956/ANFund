-- Удали старую функцию если существует
IF OBJECT_ID('dbo.fn_CalculateMultipleEMASeries_CLR', 'FT') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateMultipleEMASeries_CLR;
GO

-- Создай новую функцию с правильным именем метода
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
