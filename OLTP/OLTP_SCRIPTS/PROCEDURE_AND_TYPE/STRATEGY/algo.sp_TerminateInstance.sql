IF OBJECT_ID('algo.sp_TerminateInstance') IS NOT NULL DROP PROC algo.sp_TerminateInstance;
GO

CREATE PROC algo.sp_TerminateInstance @GUID UNIQUEIDENTIFIER
AS
SET NOCOUNT ON;

DECLARE @terminate bit = 0;
DECLARE @configID int;

BEGIN TRY
    BEGIN TRANSACTION

    -- Get configID for logging
    SELECT @configID = configID 
    FROM algo.strategyTracker 
    WHERE configInstanceGUID = @GUID 
      AND timeClosed IS NULL;

    -- Check if termination requested in queue
    IF EXISTS (
        SELECT 1 
        FROM algo.strategy_termination_queue 
        WHERE configInstanceGUID = @GUID 
          AND terminate = 1 
          AND terminated_at IS NULL
    )
    BEGIN
        SET @terminate = 1;
        
        -- Update termination queue
        UPDATE algo.strategy_termination_queue 
        SET terminated_at = GETUTCDATE()
        WHERE configInstanceGUID = @GUID 
          AND terminate = 1 
          AND terminated_at IS NULL;
        
        -- Update strategy tracker
        UPDATE algo.strategyTracker 
        SET timeClosed = GETUTCDATE()
        WHERE configInstanceGUID = @GUID 
          AND timeClosed IS NULL;
        
        -- Log termination event with volume = NULL
        IF @configID IS NOT NULL
        BEGIN
            EXEC logs.sp_LogStrategyExecution 
                @configID = @configID,
                @eventTypeName = 'termination',
                @volume = NULL,
                @price = NULL,
                @trade_uuid = @GUID;
        END
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    SET @terminate = 0;
    ROLLBACK TRANSACTION;
END CATCH

-- Return result
SELECT @terminate AS should_terminate;
GO

-- Test query
EXEC algo.sp_TerminateInstance 'F1A1E705-41A1-4E12-A2A6-2570205D2E3B';
-- Test query
