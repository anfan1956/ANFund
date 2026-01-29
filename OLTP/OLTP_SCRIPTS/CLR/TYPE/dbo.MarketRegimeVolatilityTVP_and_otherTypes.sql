IF TYPE_ID('dbo.MarketRegimeVolatilityTVP') IS NOT NULL
    DROP TYPE dbo.MarketRegimeVolatilityTVP;
GO

CREATE TYPE dbo.MarketRegimeVolatilityTVP AS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    ATR_14 decimal(18,8),
    ATR_Percent decimal(8,4),
    Historical_Volatility_20 decimal(8,4)
);
GO

IF TYPE_ID('dbo.MarketRegimeTrendTVP') IS NOT NULL
    DROP TYPE dbo.MarketRegimeTrendTVP;
GO

CREATE TYPE dbo.MarketRegimeTrendTVP AS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    ADX_14 decimal(8,4),
    Plus_DI_14 decimal(8,4),
    Minus_DI_14 decimal(8,4)
);
GO

IF TYPE_ID('dbo.MarketRegimePatternsTVP') IS NOT NULL
    DROP TYPE dbo.MarketRegimePatternsTVP;
GO

CREATE TYPE dbo.MarketRegimePatternsTVP AS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    Inside_Bar_Flag bit,
    Outside_Bar_Flag bit,
    Pin_Bar_Flag bit
);
GO

IF TYPE_ID('dbo.MarketRegimeStopsTVP') IS NOT NULL
    DROP TYPE dbo.MarketRegimeStopsTVP;
GO

CREATE TYPE dbo.MarketRegimeStopsTVP AS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    Chandelier_Exit_Long decimal(18,8),
    Chandelier_Exit_Short decimal(18,8)
);
GO

IF TYPE_ID('dbo.MarketRegimeFinalTVP') IS NOT NULL
    DROP TYPE dbo.MarketRegimeFinalTVP;
GO

CREATE TYPE dbo.MarketRegimeFinalTVP AS TABLE (
    BarID bigint,
    TickerJID int,
    TimeFrameID int,
    BarTime datetime,
    Primary_Regime tinyint,
    Regime_Confidence decimal(8,4),
    Regime_Change_Flag bit,
    Trend_Score decimal(8,4),
    Momentum_Score decimal(8,4),
    Volatility_Score decimal(8,4),
    Overall_Score decimal(8,4)
);
GO