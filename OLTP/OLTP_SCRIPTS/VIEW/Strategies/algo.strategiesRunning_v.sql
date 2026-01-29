use cTrader
go

if OBJECT_ID('algo.strategiesRunning_v') is not null drop view algo.strategiesRunning_v
go
Create view algo.strategiesRunning_v as
	select 
		s.strategy_code					as [strategy code]
		, strategy_name					as [strategy]
		, sp.strategy_configuration_id	as configID
		, sm.Symbol						as ticker
		, sp.trade_uuid					as tradeID
		, p.direction					as direction
		, p.openTime					as [openTime]
		, p.openPrice					as [openPrice]
		, p.volume						as volume
		, p.margin						as margine
		, res.grossProfit				as Gross
		, res.netProfit					as Net
		, p.closeTime
	from algo.strategies_positions sp
	--	join trd.trades_v v on v.orderUUID = sp.trade_uuid
		join trd.position p on p.positionLabel = sp.trade_uuid
		join ref.SymbolMapping sm on sm.assetID = p.assetID --		
		join algo.ConfigurationSets cs on cs.Id = sp.strategy_configuration_id
		join algo.ParameterSets ps on ps.Id=cs.ParameterSetId
		join algo.strategies s on s.ID = ps.strategy_id
		OUTER APPLY (
			select top 1 grossProfit, ps.netProfit
			from trd.positionState ps
				where ps.positionID = p.ID
			order by ps.id desc
		) AS res
	where p.closeTime is null
go

select * from algo.strategiesRunning_v order by openTime desc


select top 10 * 
--update t set t.timeClosed = GETDATE()
from algo.strategyTracker t
--where timeClosed is null
order by ID desc;

select top 5 * 
--update  q set q.terminated_at = GETDATE()
from algo.strategy_termination_queue q
--where q.terminated_at is null
order by id desc


