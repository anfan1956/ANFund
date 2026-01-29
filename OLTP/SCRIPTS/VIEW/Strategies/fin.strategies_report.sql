use cTrader
go

IF OBJECT_ID('fin.strategies_report') IS NOT NULL DROP VIEW fin.strategies_report
go
CREATE VIEW fin.strategies_report AS
	SELECT 
		sp.strategy_configuration_id AS configID
		, s.strategy_code
		, sm.Symbol
		, p.direction
		, CAST( AVG(margin/p.volume)AS MONEY) margin
		, SUM(tr.netProfit) AS netProfit
		, COUNt(tr.ID) AS tradesCount
		, CAST (p.openTime as date ) as openDate
		, CAST (p.closeTime as date ) as closeDate
		, DATEPART(YYYY, p.closeTime) YearClose
		, UPPER(FORMAT(p.closeTime, 'MMM'))  MonthClose
	FROM algo.strategies_positions sp
		join trd.position p on p.positionLabel= sp.trade_uuid
		join algo.tradeLog tl on tl.tradeUuid = sp.trade_uuid
		join algo.tradeResults tr on tr.tradeLogID = tl.ID
		join algo.ConfigurationSets cs on cs.Id=sp.strategy_configuration_id
		join algo.ParameterSets ps on ps.Id = cs.ParameterSetId
		join algo.strategies s on s.ID=ps.strategy_id
		join ref.SymbolMapping sm on sm.assetID = p.assetID
	GROUP BY
	sp.strategy_configuration_id
	, s.strategy_code
	, sm.Symbol
	, p.direction
	, CAST (p.openTime as date ) 
	, CAST (p.closeTime as date )
	, DATEPART(YYYY, p.closeTime) 
	, DATEPART(MONTH, p.closeTime) 
	, UPPER(FORMAT(p.closeTime, 'MMM'))
GO

SELECT * from fin.strategies_report