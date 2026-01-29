USE cTrader
GO

PRINT 'Creating primary index IX_Momentum_Primary...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Primary' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Primary ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Primary';
END

-- Создаем основной индекс
CREATE UNIQUE INDEX IX_Momentum_Primary 
    ON tms.Indicators_Momentum (TickerJID, TimeFrameID, BarTime DESC)
    INCLUDE (RSI_14, RSI_7, Momentum_Score, Overbought_Flag, Oversold_Flag);

PRINT 'Created IX_Momentum_Primary successfully!';
GO