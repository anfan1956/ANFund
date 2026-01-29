USE cTrader
GO

PRINT 'Creating index IX_Momentum_Oversold...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Oversold' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Oversold ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Oversold';
END

-- Создаем фильтрованный индекс (у тебя SQL Server 2019)
CREATE INDEX IX_Momentum_Oversold 
    ON tms.Indicators_Momentum (BarTime DESC, TickerJID, TimeFrameID)
    WHERE (RSI_14 < 30);

PRINT 'Created IX_Momentum_Oversold successfully!';
GO