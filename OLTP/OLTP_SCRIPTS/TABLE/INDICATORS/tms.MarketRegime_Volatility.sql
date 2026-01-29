-- Таблица 1: Волатильность
IF OBJECT_ID('tms.MarketRegime_Volatility') IS NOT NULL 
    DROP TABLE tms.MarketRegime_Volatility;
GO

CREATE TABLE tms.MarketRegime_Volatility (
    BarID bigint PRIMARY KEY FOREIGN KEY REFERENCES tms.bars(ID),
    TickerJID int NOT NULL,
    BarTime datetime NOT NULL,
    TimeFrameID int NOT NULL,
    ATR_14 decimal(18,8) NULL,
    ATR_Percent decimal(8,4) NULL,
    Historical_Volatility_20 decimal(8,4) NULL,
    CreatedDate datetime2 DEFAULT SYSDATETIME(),
    INDEX IX_Volatility_Ticker_Time (TickerJID, TimeFrameID, BarTime)
);
GO
