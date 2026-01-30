use cTrader 
go

-- logging strategy sygnals


IF OBJECT_ID('logs.sp_LogStrategyExecution') IS NOT NULL
    DROP PROCEDURE logs.sp_LogStrategyExecution
GO

CREATE PROCEDURE logs.sp_LogStrategyExecution
    @configID INT,
    @signalType NVARCHAR(20) = NULL,  -- 'buy', 'sell', 'drop' (торговые сигналы)
    @eventTypeName NVARCHAR(50) = NULL, -- 'start', 'stop', 'error', 'termination', 'signal'
    @volume DECIMAL(18,6),
    @price DECIMAL(18,6) = NULL,
    @tradingSignalID INT = NULL,
    @trade_uuid UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        DECLARE @signalTypeID INT = NULL;
        DECLARE @eventTypeID INT = NULL;
        
        -- Если это торговый сигнал (buy/sell/drop)
        IF @signalType IS NOT NULL
        BEGIN
            SELECT @signalTypeID = ID 
            FROM [algo].[strategySignalType] 
            WHERE TypeName = @signalType;
            
            IF @signalTypeID IS NULL
                THROW 50000, 'Invalid signalType', 1;
                
            -- Для торговых сигналов используем eventType='signal'
            SELECT @eventTypeID = ID 
            FROM [algo].[strategyEventsType] 
            WHERE eventTypeName = 'signal';
        END
        
        -- Если это событие стратегии (не торговый сигнал)
        IF @eventTypeName IS NOT NULL AND @signalType IS NULL
        BEGIN
            SELECT @eventTypeID = ID 
            FROM [algo].[strategyEventsType] 
            WHERE eventTypeName = @eventTypeName;
            
            IF @eventTypeID IS NULL
                THROW 50000, 'Invalid eventTypeName', 1;
        END
        
        -- Вставляем запись
        INSERT INTO logs.strategyExecution 
        (
            configID,
            signalTypeID,
            EventTypeID,
            volume,
            price,
            trade_uuid
        )
        VALUES
        (
            @configID,
            @signalTypeID,
            @eventTypeID,
            @volume,
            @price,
            @trade_uuid
        );
        
        SELECT SCOPE_IDENTITY() AS executionID;
        
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() as error;
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





