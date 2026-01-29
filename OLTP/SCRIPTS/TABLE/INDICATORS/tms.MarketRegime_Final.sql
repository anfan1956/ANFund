
-- Таблица 5: Режимы рынка (финальная)
IF OBJECT_ID('tms.MarketRegime_Final') IS NOT NULL 
    DROP TABLE tms.MarketRegime_Final;
GO

CREATE TABLE tms.MarketRegime_Final (
    BarID bigint PRIMARY KEY FOREIGN KEY REFERENCES tms.bars(ID),
    TickerJID int NOT NULL,
    BarTime datetime NOT NULL,
    TimeFrameID int NOT NULL,
    Primary_Regime tinyint NULL,
    Regime_Confidence decimal(8,4) NULL,
    Regime_Change_Flag bit NULL,
    Trend_Score decimal(8,4) NULL,
    Momentum_Score decimal(8,4) NULL,
    Volatility_Score decimal(8,4) NULL,
    Overall_Score decimal(8,4) NULL,
    CreatedDate datetime2 DEFAULT SYSDATETIME(),
    INDEX IX_Final_Ticker_Time (TickerJID, TimeFrameID, BarTime)
);
GO