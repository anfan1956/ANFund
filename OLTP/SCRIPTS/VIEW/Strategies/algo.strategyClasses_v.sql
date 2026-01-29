use cTrader
go

if OBJECT_ID('algo.strategyClasses_v') is not null drop view algo.strategyClasses_v
go

CREATE VIEW algo.strategyClasses_v AS
SELECT 
    sc.ID,
    sc.class_name										as className,
    sc.class_code										as code,
    sc.category											as category,
	hasStrategies										= isnull(s.hasit, 0),
	hasConfigs											= isnull(cf.hasit, 0),
    sc.[description]									as outline,
    sc.typical_instruments								as intsruments,
    sc.typical_timeframes								as timeFrames,
    sc.required_data_frequency							as dataFriquency,
    sc.required_history_days							as historyDays,
    sc.typical_position_hold_time						as hold_time,
    sc.requires_realtime_data							as [req:realTimeData],
    sc.requires_news_feed								as [req:newsFeed],
    sc.requires_multiple_instruments					as [req:multipleInsruments],
    sc.requires_options_data							as [req:optionsData],		
    sc.requires_fundamental_data						as [req:fundamentalData],	
    sc.implementation_complexity						as implementation_complexity,
    sc.backtesting_complexity							as backtesting_complexity,
    sc.maintenance_complexity							as maintenance_complexity,
    sc.risk_level										as riskLevel,
    sc.capital_requirements							as [req:capital],
    sc.drawdown_characteristics						as drawdown,
    sc.feasible_with_current_setup						as feasibleNow,
    sc.recommended_for_start							as forStart,
    sc.created_date									as created,
    sc.modified_date									as modifiec
FROM algo.strategy_classes sc
	OUTER APPLY (
		SELECT sum(1) hasit
			FROM algo.strategies 
		WHERE strategy_class_id = sc.id
	)  as s
	OUTER APPLY (
		SELECT sum(1) hasit
			FROM algo.ConfigurationSets conf
				left join algo.ParameterSets ps on ps.Id = conf.ParameterSetId
				left join algo.strategies st on st.ID = ps.strategy_id


		WHERE st.strategy_class_id = sc.id
	)  as cf


go
select * from algo.strategyClasses_v
