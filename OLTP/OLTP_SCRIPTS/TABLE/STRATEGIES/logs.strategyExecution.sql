-- Drop tables in correct order (child first, then parent)
IF OBJECT_ID('logs.strategyExecution') IS NOT NULL
    DROP TABLE logs.strategyExecution
GO
-- Create strategyExecution table
CREATE TABLE logs.strategyExecution
(
    -- Primary key
    ID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_log_strategyExecution PRIMARY KEY CLUSTERED,
    
    -- Strategy command
    configID INT NOT NULL CONSTRAINT FK_log_strategyExecution_configID REFERENCES [algo].[ConfigurationSets](Id),
    signalTypeID INT NOT NULL CONSTRAINT FK_log_strategyExecution_signalTypeID REFERENCES [algo].[strategySignalType](ID),
    volume DECIMAL(18,6) NOT NULL CONSTRAINT CHK_log_strategyExecution_volume CHECK (volume > 0),
    price DECIMAL(18,6) NULL,
    
    -- When command was issued
    signalTimeUTC DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    -- Reference to execution 
	-- NEED TO CREATE OR USE PROCEDURE TO WRITE BACK, MAYBY sp_GetActiveSignal
    tradingSignalID INT NULL DEFAULT (NULL) CONSTRAINT FK_log_strategyExecution_tradingSignalID REFERENCES [algo].[tradingSignals](signalID),
    trade_uuid UNIQUEIDENTIFIER NULL
)
GO

-- Create index
CREATE NONCLUSTERED INDEX IX_log_strategyExecution_configID_signalTime 
ON logs.strategyExecution (configID, signalTimeUTC DESC)
GO

