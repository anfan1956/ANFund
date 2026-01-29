
-- Создаем тестовую таблицу
/*
IF OBJECT_ID('tms.EMA_testing', 'U') IS NOT NULL
    DROP TABLE tms.EMA_testing;

CREATE TABLE tms.EMA_testing (
    ID BIGINT IDENTITY(1,1) PRIMARY KEY,
    BarID BIGINT NOT NULL,
    TickerJID INT NOT NULL,
    BarTime DATETIME NOT NULL,
    TimeFrameID INT NOT NULL,
    EMA_5_SHORT DECIMAL(18,8) NULL,
    EMA_9_MACD_SIGNAL DECIMAL(18,8) NULL,
    EMA_20_SHORT DECIMAL(18,8) NULL,
    EMA_50_MEDIUM DECIMAL(18,8) NULL,
    CreatedDate DATETIME DEFAULT GETDATE(),
    
    INDEX IX_EMA_Testing_Ticker_Time (TickerJID, TimeFrameID, BarTime),
    INDEX IX_EMA_Testing_BarTime (BarTime)
);
*/

-- Тест новой функции с несколькими EMA
SELECT TOP 10 *
FROM dbo.fn_CalculateMultipleEMASeries_CLR(56, 1, DATEADD(HOUR, -2, GETUTCDATE()))
ORDER BY BarTime;

-- Проверь правильность расчета EMA5
WITH Data AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY BarTime) as rn
    FROM dbo.fn_CalculateMultipleEMASeries_CLR(56, 1, DATEADD(HOUR, -1, GETUTCDATE()))
)
SELECT TOP 5
    BarTime,
    CloseValue,
    EMA_5_SHORT,
    EMA_9_MACD_SIGNAL,
    LAG(EMA_5_SHORT) OVER (ORDER BY BarTime) as Prev_EMA5,
    CASE 
        WHEN rn = 1 THEN 'First'
        WHEN ABS(EMA_5_SHORT - ((CloseValue * (2.0/6)) + (LAG(EMA_5_SHORT) OVER (ORDER BY BarTime) * (1 - 2.0/6)))) < 0.001 
        THEN 'OK' 
        ELSE 'ERROR' 
    END as EMA5_Validation
FROM Data
ORDER BY BarTime;

PRINT 'Table tms.EMA_testing created';