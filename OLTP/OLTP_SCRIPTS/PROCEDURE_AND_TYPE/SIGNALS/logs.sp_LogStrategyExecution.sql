use cTrader 
go

-- logging strategy sygnals


IF OBJECT_ID('logs.sp_LogStrategyExecution') IS NOT NULL
    DROP PROCEDURE logs.sp_LogStrategyExecution
GO

CREATE PROCEDURE logs.sp_LogStrategyExecution
    @configID INT,
    @signalType NVARCHAR(20),  -- 'buy', 'sell', 'drop'
    @volume DECIMAL(18,6),
    @price DECIMAL(18,6) = NULL,
    @tradingSignalID INT = NULL,
    @trade_uuid UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Get signalTypeID from strategySignalType
        DECLARE @signalTypeID INT;
        
        SELECT @signalTypeID = ID 
        FROM [algo].[strategySignalType] 
        WHERE TypeName = @signalType;
        
        -- Insert into strategyExecution table
        INSERT INTO logs.strategyExecution 
        (
            configID,
            signalTypeID,
            volume,
            price,
            trade_uuid
        )
        VALUES
        (
            @configID,
            @signalTypeID,
            @volume,
            @price,
            @trade_uuid
        );
        
        -- Return the inserted ID
        SELECT SCOPE_IDENTITY() AS executionID;
        
    END TRY
    BEGIN CATCH
		SElECT ERROR_MESSAGE() as error;
        THROW;
    END CATCH
END
GO

/*
    EXEC logs.sp_LogStrategyExecution  
        @configID = 2,
        @signalType = 'buy',
        @volume = 50,
        @price = 112.185,
        @trade_uuid = 'E6F60640-E4A4-4D92-BDDA-45848567E05F'
*/



select top 5 * from logs.strategyExecution se
--where se.configID = 13
order by 1  desc