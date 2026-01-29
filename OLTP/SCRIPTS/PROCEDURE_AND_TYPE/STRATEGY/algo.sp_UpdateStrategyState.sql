use cTrader
go

IF OBJECT_ID('algo.sp_UpdateStrategyState', 'P') IS NOT NULL
    DROP PROCEDURE algo.sp_UpdateStrategyState;
GO

CREATE PROCEDURE algo.sp_UpdateStrategyState
    @configID INT,
    @currentState VARCHAR(20)  -- 'start', 'heartbeat', 'stop', 'terminated'
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @currentState NOT IN ('start', 'heartbeat', 'stop', 'terminated')
        THROW 50000, 'Invalid state', 1;
    
    MERGE algo.strategyTracker AS target
    USING (
        SELECT @configID AS configID, 
               @currentState AS state, 
               GETUTCDATE() AS currentTime
    ) AS source
    ON target.configID = source.configID 
       AND target.timeClosed IS NULL    
    WHEN MATCHED THEN
        UPDATE SET 
            target.modified = CASE 
                WHEN source.state = 'heartbeat' THEN source.currentTime
                ELSE target.modified
            END,
            target.timeClosed = CASE 
                WHEN source.state IN ('stop', 'terminated') THEN source.currentTime
                ELSE target.timeClosed
            END
            
    WHEN NOT MATCHED AND source.state = 'start' THEN
        INSERT (configID, timeStarted, modified)
        VALUES (source.configID, source.currentTime, source.currentTime);
END;