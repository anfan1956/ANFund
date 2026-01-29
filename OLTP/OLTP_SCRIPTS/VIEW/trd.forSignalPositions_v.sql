use cTrader
go

if OBJECT_ID ('trd.forSignalPositions_v') is not null drop view trd.forSignalPositions_v
go
create view trd.forSignalPositions_v as
--select 
--	p.id
--	, positionTicket
--	, am.ticker
--	, p.direction
--	, p.openPrice
--	, ps.currentPrice
--	, p.openTime
--	, p.volume
--	, p.margin
--	, ps.stopLoss
--	, ps.takeProfit
--	, ps.grossProfit
--	, ps.netProfit
--	, sum(ps.netProfit) over() as total_P_L
--	, p.positionLabel
--from trd.position p 
--	join ref.assetMasterTable am on am.ID = p.assetID
--	cross apply (select top 1 *
--		from trd.positionState s
--			where p.ID = s.positionID
--		order by s.ID desc
--		) as ps
--where closeTime is null
select
	 ID  =		v.id 
	, orderUUID		= v.positionLabel
	, tradeType		= 'POSITION'
	, ticker		= v.ticker
	, direction		= v.direction
	, entryPrice	= v.openPrice
	, createdTime	= openTime
	, volume		= v.volume
	, margin		= v.margin
from trd.positions_v v

go

--select * from trd.position
select * from trd.trades_v
select * from trd.forSignalPositions_v;
--select * from trd.positionState ps
