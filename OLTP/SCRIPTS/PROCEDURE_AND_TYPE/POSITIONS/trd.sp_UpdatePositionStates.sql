-- FIXED PROCEDURE WITH POSITION ID MAPPING
IF OBJECT_ID('trd.sp_UpdatePositionStates') IS NOT NULL
    DROP PROCEDURE trd.sp_UpdatePositionStates
GO

CREATE PROCEDURE trd.sp_UpdatePositionStates
    @positionStates trd.PositionStateTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Используем CTE для маппинга positionTicket -> positionID
        WITH PositionMapping AS (
            SELECT 
                ps.positionID as cTraderPositionID,
                p.ID as dbPositionID,
                ps.timestamp,
                ps.currentPrice,
                ps.commission,
                ps.swap,
                ps.stopLoss,
                ps.takeProfit,
                ps.netProfit,
                ps.grossProfit
            FROM @positionStates ps
            INNER JOIN trd.position p ON ps.positionID = p.positionTicket
        )
        
        -- Обновляем существующие записи и добавляем новые
        MERGE trd.positionState AS target
        USING PositionMapping AS source
        ON target.positionID = source.dbPositionID 
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
            VALUES (source.dbPositionID, source.timestamp, source.currentPrice, 
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


