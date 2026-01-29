USE cTrader
GO

PRINT 'Creating index IX_Momentum_Batch...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Batch' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Batch ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Batch';
END

-- Создаем индекс для батч-обработки
CREATE INDEX IX_Momentum_Batch 
    ON tms.Indicators_Momentum (BatchID)
    INCLUDE (TickerJID, BarTime, TimeFrameID);

PRINT 'Created IX_Momentum_Batch successfully!';
GO