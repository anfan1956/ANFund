USE [cTrader]
GO

if object_ID ('tms.Indicators_Momentum') is not null drop table tms.Indicators_Momentum
go

CREATE TABLE tms.Indicators_Momentum(
	[ID] [bigint]  NOT NULL constraint PK_Indicators_Momentum primary key clustered constraint fk_IndicatorsMomentuv_Bars foreign key references tms.bars(ID),
	[TickerJID] [int] NOT NULL,
	[BarTime] [datetime2](3) NOT NULL,
	[TimeFrameID] [int] NOT NULL,
	[SourceID] [int] NOT NULL,
	[RSI_14] [decimal](8, 4) NULL,
	[RSI_7] [decimal](8, 4) NULL,
	[RSI_21] [decimal](8, 4) NULL,
	[RSI_ZScore] [decimal](8, 4) NULL,
	[RSI_Percentile] [decimal](8, 4) NULL,
	[RSI_Slope_5] [decimal](8, 4) NULL,
	[Stoch_K_14] [decimal](8, 4) NULL,
	[Stoch_D_14] [decimal](8, 4) NULL,
	[Stoch_Slope] [decimal](8, 4) NULL,
	[ROC_14] [decimal](12, 6) NULL,
	[ROC_7] [decimal](12, 6) NULL,
	[Momentum_Score] [decimal](8, 4) NULL,
	[Overbought_Flag] [bit] NULL,
	[Oversold_Flag] [bit] NULL,
	[BatchID] [uniqueidentifier] NULL,
	[CalculationTimeMS] [int] NULL,
	[CreatedDate] [datetime2](3) NULL,
	[ModifiedDate] [datetime2](3) NULL,

 CONSTRAINT [UQ_Momentum_PerBar] UNIQUE NONCLUSTERED 
(
	[TickerJID] ASC,
	[BarTime] ASC,
	[TimeFrameID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [tms].[Indicators_Momentum] ADD  CONSTRAINT [DF_Indicators_Momentum_SourceID]  DEFAULT ((1)) FOR [SourceID]
GO

ALTER TABLE [tms].[Indicators_Momentum] ADD  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [FK_IndicatorsMomentum_Source] FOREIGN KEY([SourceID])
REFERENCES [tms].[sources] ([ID])
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [FK_IndicatorsMomentum_Source]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [FK_IndicatorsMomentum_Ticker] FOREIGN KEY([TickerJID])
REFERENCES [ref].[assetMasterTable] ([ID])
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [FK_IndicatorsMomentum_Ticker]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [FK_IndicatorsMomentum_TimeFrame] FOREIGN KEY([TimeFrameID])
REFERENCES [tms].[timeframes] ([ID])
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [FK_IndicatorsMomentum_TimeFrame]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [FK_IndicatorsMomentum_tmsBars] FOREIGN KEY([ID])
REFERENCES [tms].[bars] ([ID])
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [FK_IndicatorsMomentum_tmsBars]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [CHK_BarTime_NotFuture] CHECK  (([BarTime]<=sysdatetime()))
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [CHK_BarTime_NotFuture]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [CHK_Momentum_Score_Range] CHECK  (([Momentum_Score] IS NULL OR [Momentum_Score]>=(0) AND [Momentum_Score]<=(100)))
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [CHK_Momentum_Score_Range]
GO

ALTER TABLE [tms].[Indicators_Momentum]  WITH CHECK ADD  CONSTRAINT [CHK_RSI_Range] CHECK  (([RSI_14] IS NULL OR [RSI_14]>=(0) AND [RSI_14]<=(100)))
GO

ALTER TABLE [tms].[Indicators_Momentum] CHECK CONSTRAINT [CHK_RSI_Range]
GO


