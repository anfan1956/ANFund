-- Таблица 4: Стоп-лосс уровни
IF OBJECT_ID('tms.MarketRegime_Stops') IS NOT NULL 
    DROP TABLE tms.MarketRegime_Stops;
GO

CREATE TABLE tms.MarketRegime_Stops (
    BarID bigint PRIMARY KEY FOREIGN KEY REFERENCES tms.bars(ID),
    TickerJID int NOT NULL,
    BarTime datetime NOT NULL,
    TimeFrameID int NOT NULL,
    Chandelier_Exit_Long decimal(18,8) NULL,
    Chandelier_Exit_Short decimal(18,8) NULL,
    CreatedDate datetime2 DEFAULT SYSDATETIME(),
    INDEX IX_Stops_Ticker_Time (TickerJID, TimeFrameID, BarTime)
);
GO
