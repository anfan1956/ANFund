use cTrader
go


if OBJECT_ID ('trd.trades_v') is not null drop view trd.trades_v
go
create view trd.trades_v as
select 
	ID								= p.id
	, orderUUID						= p.orderUUID
	, tradeType						= 'PENDING ORDER' 
	, ticker						= p.symbol
	, direction						= p.direction
	, entryPrice					= p.targetPrice
	, createdTime					= p.createdTime
	, volume						= p.volume
	, margin						= null
	, creationOrder				= ROW_NUMBER() over(order by p.createdTime)
from trd.pendingOrder p 
where closeTime is null

	union all

select 
	id											= p.id
	, orderUUID									= orderUUID		
	, tradeType									= tradeType		
	, ticker									= ticker		
	, direction									= direction		
	, entryPrice								= entryPrice	
	, createdTime								=  createdTime	
	, volume									=  volume		
	, margin									=  margin
	, creationOrder								= ROW_NUMBER() over(order by createdTime)	
from trd.forSignalPositions_v p
go



select * from trd.trades_v;
--select * from trd.positionState ps
--select * from trd.pendingOrder po 
--where 1=1
--	and po.orderStatus = 'pending' and po.orderUUID is not null
--	and po.closeTime is  null
