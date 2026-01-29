
use cTrader
go


if OBJECT_ID('trd.positionState') is not null drop TABLE trd.positionState
if OBJECT_ID('trd.position') is not null drop TABLE trd.position
go

CREATE TABLE trd.position (
	ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
	accountID int NOT NULL,
	positionTicket [varchar](50) NOT NULL,
	assetID int NOT NULL,
	volume decimal(18, 2) NOT NULL,
	margin decimal(18, 2) NOT NULL,
	direction char(4) NOT NULL,
	openTime datetime NOT NULL,
	closeTime datetime NULL,
	openPrice numeric(18, 6) NOT NULL,
	positionLabel [uniqueidentifier] NULL
    , CONSTRAINT UQ_position_account_ticket UNIQUE (accountid, positionTicket)
)
go

ALTER TABLE [trd].[position]  WITH NOCHECK ADD FOREIGN KEY([accountID])
REFERENCES [trd].[account] ([ID])
GO

ALTER TABLE [trd].[position]  WITH NOCHECK ADD FOREIGN KEY([assetID])
REFERENCES [ref].[assetMasterTable] ([ID])
GO

ALTER TABLE [trd].[position]  WITH NOCHECK ADD CHECK  (([direction]='SELL' OR [direction]='BUY'))
GO

ALTER TABLE [trd].[position]  WITH NOCHECK ADD  CONSTRAINT [CK_position_direction] CHECK  (([direction]='SELL' OR [direction]='BUY'))
GO

ALTER TABLE [trd].[position] NOCHECK CONSTRAINT [CK_position_direction]
GO


CREATE TABLE [trd].[positionState](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[positionID] [int] NOT NULL,
	[timestamp] [datetime] NOT NULL,
	[currentPrice] [decimal](18, 6) NOT NULL,
	[commission] [decimal](18, 2) NULL,
	[swap] [decimal](18, 2) NULL,
	[stopLoss] [numeric](18, 6) NULL,
	[takeProfit] [numeric](18, 6) NULL,
	[netProfit] [money] NULL,
	[grossProfit] [money] NULL
) ON [PRIMARY]
GO

ALTER TABLE [trd].[positionState] ADD  DEFAULT (getdate()) FOR [timestamp]
GO

ALTER TABLE [trd].[positionState] ADD  DEFAULT ((0)) FOR [commission]
GO

ALTER TABLE [trd].[positionState] ADD  DEFAULT ((0)) FOR [swap]
GO

ALTER TABLE [trd].[positionState]  WITH CHECK ADD  CONSTRAINT [fk_position_positionState] FOREIGN KEY([positionID])
REFERENCES [trd].[position] ([ID])
GO

ALTER TABLE [trd].[positionState] CHECK CONSTRAINT [fk_position_positionState]
GO


