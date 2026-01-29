use cTrader
go
/***********************************************
D:\TradingSystems\OLTP\OLTP\VIEW\Strategies\algo.strategies_v.sql
***********************************************/

-- View for dashboard
IF OBJECT_ID('algo.strategiesDashboard_v', 'V') IS NOT NULL
    DROP VIEW algo.strategiesDashboard_v;
GO

CREATE VIEW algo.strategiesDashboard_v AS
SELECT 
    st.configID,
    tv.ticker,
    st.timeStarted,
    st.modified AS lastHeartbeat,
    DATEDIFF(MINUTE, st.modified, GETUTCDATE()) AS minutesSinceHeartbeat,
    s.strategy_code,
    s.strategy_name,
    -- Add position info if exists
    tv.direction,
    tv.entryPrice,
    tv.volume,
    tv.createdTime AS positionOpened,
    DATEDIFF(MINUTE, tv.createdTime, GETUTCDATE()) AS minutesInPosition
FROM algo.strategyTracker st
join algo.ConfigurationSets cs on cs.Id= st.configID
join algo.ParameterSets ps on ps.Id=cs.ParameterSetId
JOIN algo.strategies s ON s.ID = ps.strategy_id
LEFT JOIN algo.strategies_positions sp ON sp.strategy_configuration_id = st.configID
LEFT JOIN trd.trades_v tv ON tv.orderUUID = sp.trade_uuid AND tv.tradeType = 'POSITION'
WHERE st.timeClosed IS NULL
  AND st.modified > DATEADD(MINUTE, -10, GETUTCDATE()); -- Only show active (heartbeat within 10 mins)
GO


select * from algo.strategiesDashboard_v