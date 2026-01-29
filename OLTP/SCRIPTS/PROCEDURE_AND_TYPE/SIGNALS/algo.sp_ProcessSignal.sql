use cTrader
go


if OBJECT_ID('algo.sp_ProcessSignal') is not null drop proc algo.sp_ProcessSignal
go

CREATE PROCEDURE algo.sp_ProcessSignal
    @uuid uniqueidentifier,
	@status nvarchar(20), 
	@executionType NVARCHAR(20),	--(order, position)
    @executionID NVARCHAR(50) -- (for order or for position)
AS
BEGIN
    UPDATE s set	
		s.status = @status, 
		s.executionType  = case when @status = 'ACCEPTED' then  @executionType end, 
		s.executionID  = case when @status = 'ACCEPTED' then  @executionID end, 
		s.executionTime = GETDATE()
	FROM algo.tradingSignals s
    WHERE s.positionLabel = @uuid;
END;
go
declare 
    @signalID INT				= 1,
	@status nvarchar(20)		= 'ACCEPTED', 
	@executionType NVARCHAR(20) = 'order',	--(order, position)
    @executionID NVARCHAR(50)	= 'OID309096229'-- in this case for 'order'	  	-- (for order or for position)
/*
exec algo.sp_ProcessSignal
		@signalID		= @signalID,
		@status			= @status, 
		@executionType	= @executionType,	
		@executionID	= @executionID; 
*/


--exec algo.sp_GetActiveSignal;
select * from algo.tradingSignals order by signalID desc;

