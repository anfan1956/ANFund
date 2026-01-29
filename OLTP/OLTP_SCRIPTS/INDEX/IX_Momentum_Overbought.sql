USE cTrader
GO

PRINT 'Creating index IX_Momentum_Overbought...'

-- Проверяем существование таблицы
IF OBJECT_ID('tms.Indicators_Momentum') IS NULL
BEGIN
    RAISERROR('Table tms.Indicators_Momentum does not exist. Please create it first.', 16, 1);
    RETURN;
END

-- Проверяем версию SQL Server
DECLARE @SQLVersion NVARCHAR(128);
SELECT @SQLVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
DECLARE @MajorVersion INT = CAST(LEFT(@SQLVersion, CHARINDEX('.', @SQLVersion) - 1) AS INT);

PRINT 'SQL Server version: ' + @SQLVersion;
PRINT 'Major version: ' + CAST(@MajorVersion AS NVARCHAR(10));

-- Удаляем индекс если существует
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Momentum_Overbought' AND object_id = OBJECT_ID('tms.Indicators_Momentum'))
BEGIN
    DROP INDEX IX_Momentum_Overbought ON tms.Indicators_Momentum;
    PRINT 'Dropped existing index IX_Momentum_Overbought';
END

-- Создаем индекс в зависимости от версии SQL Server
IF @MajorVersion >= 10 -- SQL Server 2008+
BEGIN
    PRINT 'Using filtered index (SQL Server 2008+)';
    CREATE INDEX IX_Momentum_Overbought 
        ON tms.Indicators_Momentum (BarTime DESC, TickerJID, TimeFrameID)
        WHERE (RSI_14 > 70);
END
ELSE
BEGIN
    PRINT 'Using standard index (older SQL Server)';
    CREATE INDEX IX_Momentum_Overbought 
        ON tms.Indicators_Momentum (BarTime DESC, TickerJID, TimeFrameID)
        INCLUDE (RSI_14);
END

PRINT 'Created IX_Momentum_Overbought successfully!';
GO