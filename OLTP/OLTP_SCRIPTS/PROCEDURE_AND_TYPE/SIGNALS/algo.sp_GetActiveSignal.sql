USE cTrader
GO

if OBJECT_ID('algo.sp_GetActiveSignal') is not null drop proc algo.sp_GetActiveSignal
go

CREATE PROCEDURE algo.sp_GetActiveSignal
AS
BEGIN
SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Declare a table variable to store the signals being processed
        DECLARE @ProcessingSignals TABLE (
            SignalID INT
        );
        
        -- Select the PENDING signals and insert their IDs into the table variable
        INSERT INTO @ProcessingSignals (SignalID)
        SELECT 
            s.signalID
        FROM algo.tradingSignals s
        WHERE s.status = 'PENDING'
          AND (s.expiry IS NULL OR s.expiry > GETUTCDATE())
        ORDER BY s.timeCreated ASC;
        
        -- Return the dataset to the robot
        SELECT 
            s.signalID,
            sm.Symbol,
            s.volume,
            sst.TypeName as direction,
            s.orderPrice,
            s.stopLoss,
            s.takeProfit,
            s.positionLabel,
            sp.strategy_configuration_id
        FROM algo.tradingSignals s
            INNER JOIN ref.assetMasterTable a ON s.assetID = a.ID
            INNER JOIN ref.SymbolMapping sm ON sm.assetID = a.id
            INNER JOIN algo.strategySignalType sst ON s.signalTypeID = sst.ID
            LEFT JOIN algo.strategies_positions sp ON s.positionLabel = sp.trade_uuid
        WHERE 1=1
            and s.signalID IN (SELECT SignalID FROM @ProcessingSignals)
            and sm.brokerID = 2 
            and sm.platformID = 1
        ORDER BY s.timeCreated ASC;

        -- Update the status of the signals to "PROCESSING"
        UPDATE ts
        SET ts.status = 'PROCESSING'
        FROM algo.tradingSignals ts
            INNER JOIN @ProcessingSignals ps ON ts.signalID = ps.SignalID
        WHERE ts.signalTypeID IN (
            SELECT ID FROM algo.strategySignalType WHERE UPPER(TypeName) IN ('BUY', 'SELL')
        );

        -- Commit the transaction
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Rollback the transaction in case of an error
        ROLLBACK TRANSACTION;

        -- Return the error message
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH;
END;
GO