USE cTrader
GO

PRINT 'Creating index IX_Momentum_Signals...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Signals' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Signals ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Signals';
END

-- Создаем индекс для генерации сигналов
CREATE INDEX IX_Momentum_Signals 
    ON tms.Indicators_Momentum (BarTime DESC, Momentum_Score DESC)
    INCLUDE (TickerJID, TimeFrameID, RSI_14);

PRINT 'Created IX_Momentum_Signals successfully!';
GO