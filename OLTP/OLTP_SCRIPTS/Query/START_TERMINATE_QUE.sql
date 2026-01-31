--select top 5 * from algo.tradingSignals order by 1 desc;
--select top 5 * from trd.trades_v t order by 1 desc;
--select top 5 * from algo.strategies_positions order by ID desc ;
/*
select  * 
--	update q set terminated_at = GETDATE()
	from  algo.strategy_termination_queue q 
--where q.id = 55


*/
select top 5 * 
--update st set st.timeClosed = GETUTCDATE()
from algo.strategyTracker st
	where st.ID between 126 and  126
order by 1 desc


select top 5 * from algo.strategyTracker st order by 1 desc
select top 5 * from algo.strategy_termination_queue order by 1 desc
/*
ID	configID	timeStarted	timeClosed	configInstanceGUID
119	3	2026-01-30 23:49:19.217	NULL	F1A1E705-41A1-4E12-A2A6-2570205D2E3B
118	3	2026-01-30 22:48:02.083	2026-01-30 23:50:36.107	F2ABA576-E9E6-4279-A789-1EA946210932

id	config_id	terminate	requested_at	terminated_at	configInstanceGUID
56	3	1	2026-01-30 23:53:52.773	NULL	F1A1E705-41A1-4E12-A2A6-2570205D2E3B
55	3	1	2026-01-30 23:13:36.620	2026-01-31 02:55:19.617	F2ABA576-E9E6-4279-A789-1EA946210932

*/

