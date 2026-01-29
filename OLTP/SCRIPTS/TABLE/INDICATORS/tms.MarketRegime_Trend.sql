
-- Таблица 2: Тренд
IF OBJECT_ID('tms.MarketRegime_Trend') IS NOT NULL 
    DROP TABLE tms.MarketRegime_Trend;
GO

CREATE TABLE tms.MarketRegime_Trend (
    BarID bigint PRIMARY KEY FOREIGN KEY REFERENCES tms.bars(ID),
    TickerJID int NOT NULL,
    BarTime datetime NOT NULL,
    TimeFrameID int NOT NULL,
    ADX_14 decimal(8,4) NULL,
    Plus_DI_14 decimal(8,4) NULL,
    Minus_DI_14 decimal(8,4) NULL,
    CreatedDate datetime2 DEFAULT SYSDATETIME(),
    INDEX IX_Trend_Ticker_Time (TickerJID, TimeFrameID, BarTime)
);
GO
