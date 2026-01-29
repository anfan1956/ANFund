use cTrader
go


if OBJECT_ID ('fin.strategies_results') is not null drop view fin.strategies_results
go
create view fin.strategies_results as
select 
	ROW_NUMBER() over(partition by ps.strategy_id order by p.openTime ) as num
	, s.strategy_code
	, cs.Id
	, sm.Symbol, p.volume, p.margin, p.direction, p.openTime, p.closeTime, tr.netProfit
	, count(tl.ID) over(partition by cast(p.closeTime as date) ) as countDaily
	, count(tl.ID) over( ) as countTotal
	, sum(tr.netProfit)over (partition by  cast(p.closeTime as date), cs.ID) as stByStratDay
	, sum(tr.netProfit) over(partition by cast(p.closeTime as date) ) as stTotByDay
	, sum(tr.netProfit) over() as stTotal
from algo.strategies_positions sp
	join trd.position p on p.positionLabel= sp.trade_uuid
	join algo.tradeLog tl on tl.tradeUuid = sp.trade_uuid
	join algo.tradeResults tr on tr.tradeLogID = tl.ID
	join algo.ConfigurationSets cs on cs.Id=sp.strategy_configuration_id
	join algo.ParameterSets ps on ps.Id = cs.ParameterSetId
	join algo.strategies s on s.ID=ps.strategy_id
	join ref.SymbolMapping sm on sm.assetID = p.assetID
go

declare @date datetime  = cast(getdate() as date);

select * from fin.strategies_results p 
where p.openTime > @date
order by p.openTime desc

--select * from algo.parmeters_tf('MTF_RSI_EMA', null)

select * from algo.strategies_positions


