use cTrader
go


if OBJECT_ID ('trd.positions_v') is not null drop view trd.positions_v
go
create view trd.positions_v as
select 
	p.id
	, positionTicket
	, am.ticker
	, p.direction
	, p.openPrice
	, ps.currentPrice
	, p.openTime
	, p.volume
	, p.margin
	, ps.stopLoss
	, ps.takeProfit
	, ps.grossProfit
	, ps.netProfit
	, sum(ps.netProfit) over() as total_P_L
	, p.positionLabel
from trd.position p 
	join ref.assetMasterTable am on am.ID = p.assetID
	cross apply (select top 1 *
		from trd.positionState s
			where p.ID = s.positionID
		order by s.ID desc
		) as ps
where closeTime is null
go

select * from trd.position

select * from trd.positions_v;
--select * from trd.positionState ps
select count (*)	from trd.positionState s

