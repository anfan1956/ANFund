USE cTrader
GO

PRINT 'Creating index IX_Momentum_RSI...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_RSI' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_RSI ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_RSI';
END

-- Создаем индекс для поиска по RSI
CREATE INDEX IX_Momentum_RSI 
    ON tms.Indicators_Momentum (TickerJID, RSI_14)
    INCLUDE (BarTime, TimeFrameID, Momentum_Score);

PRINT 'Created IX_Momentum_RSI successfully!';
GO