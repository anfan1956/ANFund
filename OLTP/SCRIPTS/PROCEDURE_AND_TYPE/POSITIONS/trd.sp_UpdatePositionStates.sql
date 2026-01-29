-- trd.sp_UpdatePositionStates.sql
IF OBJECT_ID('trd.sp_UpdatePositionStates') IS NOT NULL
    DROP PROCEDURE trd.sp_UpdatePositionStates
GO

CREATE PROCEDURE trd.sp_UpdatePositionStates
    @positionStates trd.PositionStateTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- ќбновл€ем существующие записи и добавл€ем новые
        MERGE trd.positionState AS target
        USING @positionStates AS source
        ON target.positionID = source.positionID 
           AND target.timestamp = source.timestamp
        
        WHEN MATCHED THEN
            UPDATE SET 
                currentPrice = source.currentPrice,
                commission = source.commission,
                swap = source.swap,
                stopLoss = source.stopLoss,
                takeProfit = source.takeProfit,
                netProfit = source.netProfit,
                grossProfit = source.grossProfit
        
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (positionID, timestamp, currentPrice, commission, swap, 
                    stopLoss, takeProfit, netProfit, grossProfit)
            VALUES (source.positionID, source.timestamp, source.currentPrice, 
                    source.commission, source.swap, source.stopLoss, 
                    source.takeProfit, source.netProfit, source.grossProfit);
        
        PRINT 'Position states updated successfully.';
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

