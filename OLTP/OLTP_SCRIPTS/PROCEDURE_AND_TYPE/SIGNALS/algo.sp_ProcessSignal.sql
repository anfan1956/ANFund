use cTrader
go


if OBJECT_ID('algo.sp_ProcessSignal') is not null drop proc algo.sp_ProcessSignal
go

CREATE PROCEDURE algo.sp_ProcessSignal
    @uuid uniqueidentifier,
    @status nvarchar(20), 
    @executionType NVARCHAR(20),    --(order, position)
    @executionID NVARCHAR(50) -- (for order or for position)
AS
BEGIN
    -- 1. Обновляем tradingSignals
    UPDATE s SET    
        s.status = @status, 
        s.executionType  = CASE WHEN @status = 'ACCEPTED' THEN @executionType END, 
        s.executionID  = CASE WHEN @status = 'ACCEPTED' THEN @executionID END, 
        s.executionTime = GETDATE()
    FROM algo.tradingSignals s
    WHERE s.positionLabel = @uuid;

    -- 2. Обновляем createdTime в strategies_positions для принятых сигналов
    IF @status = 'ACCEPTED'
    BEGIN
        UPDATE sp
        SET createdTime = GETUTCDATE()
        FROM algo.strategies_positions sp
        WHERE sp.trade_uuid = @uuid;
    END
END;
GO


/*
exec algo.sp_ProcessSignal
		@signalID		= @signalID,
		@status			= @status, 
		@executionType	= @executionType,	
		@executionID	= @executionID; 
*/


--exec algo.sp_GetActiveSignal;
select top 10 * from algo.tradingSignals order by signalID desc;

