USE cTrader
GO

PRINT 'Creating index IX_Momentum_Time...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Time' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Time ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Time';
END

-- Создаем индекс для временных запросов
CREATE INDEX IX_Momentum_Time 
    ON tms.Indicators_Momentum (BarTime DESC)
    INCLUDE (TickerJID, TimeFrameID, RSI_14, Momentum_Score);

PRINT 'Created IX_Momentum_Time successfully!';
GO