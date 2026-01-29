USE cTrader
GO

/*******************************************
D:\TradingSystems\OLTP\OLTP\VIEW\Strategies\algo.strategies_v.sql
*********************************************/

IF OBJECT_ID('algo.strategies_v') IS NOT NULL DROP VIEW algo.strategies_v
GO

CREATE VIEW algo.strategies_v AS
SELECT 
    s.ID,
    s.strategy_name,
    s.strategy_code,
    s.strategy_class_id,
    sc.class_name,
    sc.class_code,
    sc.category,
    -- Check if strategy has any configurations
    hasConfigs = ISNULL(cf.config_count, 0),
    s.logic_description,
    s.created_by,
    s.created_date,
    s.modified_date,
    -- Additional class information
    sc.typical_instruments,
    sc.typical_timeframes,
    sc.risk_level,
    sc.implementation_complexity
FROM algo.strategies s
INNER JOIN algo.strategy_classes sc ON s.strategy_class_id = sc.ID
OUTER APPLY (
    SELECT COUNT(*) as config_count
    FROM algo.ConfigurationSets conf
		join algo.ParameterSets ps on ps.Id = conf.ParameterSetId
    WHERE ps.strategy_id = s.ID
) as cf
GO

select * from algo.strategies_v

