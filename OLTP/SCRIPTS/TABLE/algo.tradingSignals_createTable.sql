use cTrader
go
/*
if OBJECT_ID ('algo.tradingSignals') is not null drop table algo.tradingSignals
*/

if OBJECT_ID ('algo.tradingSignals') is not null
Begin
	CREATE TABLE algo.tradingSignals (
		signalID INT IDENTITY(1,1) PRIMARY KEY,
		assetID INT NOT NULL,
		volume DECIMAL(18,6) NOT NULL,
		direction NVARCHAR(10) NOT NULL CHECK (direction IN ('buy', 'sell')),
		orderPrice DECIMAL(18,6) NOT NULL,
		stopLoss DECIMAL(18,6) NULL,
		takeProfit DECIMAL(18,6) NULL,
		timeCreated DATETIME NOT NULL DEFAULT GETDATE(),
		expiry DATETIME NOT NULL DEFAULT DATEADD(HOUR, 1, GETDATE()), -- 60 минут
		status NVARCHAR(20) NOT NULL DEFAULT 'PENDING' 
			CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED')),
		orderID NVARCHAR(50) NULL,
    
		CONSTRAINT FK_signals_asset FOREIGN KEY (assetID) 
		REFERENCES ref.assetMasterTable(ID)
	);
end 

go

USE [cTrader]
GO

ALTER TABLE [algo].[tradingSignals] DROP CONSTRAINT [CK_tradingSignals_direction]
GO

ALTER TABLE [algo].[tradingSignals]  WITH CHECK ADD  CONSTRAINT [CK_tradingSignals_direction] CHECK  (([direction]='sell' OR [direction]='buy' OR [direction]='drop'))
GO

ALTER TABLE [algo].[tradingSignals] CHECK CONSTRAINT [CK_tradingSignals_direction]
GO

USE [cTrader]
GO

ALTER TABLE [algo].[tradingSignals]  WITH CHECK ADD  CONSTRAINT [CH_execType] CHECK  (([executionType]='position' OR [executionType]='order'))
GO

ALTER TABLE [algo].[tradingSignals] CHECK CONSTRAINT [CH_execType]
GO
-- Check if constraint exists and drop it
IF EXISTS (
    SELECT 1 
    FROM sys.check_constraints 
    WHERE name = 'CH_execType'
    AND OBJECT_NAME(parent_object_id) = 'tradingSignals'  -- Specify table
)
BEGIN
    ALTER TABLE algo.tradingSignals
    DROP CONSTRAINT CH_execType;
END
ELSE
	BEGIN
		-- Recreate the constraint with new definition
		ALTER TABLE algo.tradingSignals
		ADD CONSTRAINT CH_execType 
		CHECK ([executionType] in ('position', 'order','closePosition', 'cancelOrder'))
	END
