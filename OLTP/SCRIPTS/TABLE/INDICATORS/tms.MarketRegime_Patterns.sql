
-- Таблица 3: Паттерны свечей
IF OBJECT_ID('tms.MarketRegime_Patterns') IS NOT NULL 
    DROP TABLE tms.MarketRegime_Patterns;
GO

CREATE TABLE tms.MarketRegime_Patterns (
    BarID bigint PRIMARY KEY FOREIGN KEY REFERENCES tms.bars(ID),
    TickerJID int NOT NULL,
    BarTime datetime NOT NULL,
    TimeFrameID int NOT NULL,
    Inside_Bar_Flag bit NULL,
    Outside_Bar_Flag bit NULL,
    Pin_Bar_Flag bit NULL,
    CreatedDate datetime2 DEFAULT SYSDATETIME(),
    INDEX IX_Patterns_Ticker_Time (TickerJID, TimeFrameID, BarTime)
);
GO

