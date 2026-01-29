USE cTrader
GO

/*******************************************************
D:\TradingSystems\OLTP\OLTP\Analytics\Checking_Nulls_in_EMA_MA.sql

************************************************************************/


--select  * from tms.bars b order by  b.barTime desc

--select top 20 * from tms.EMA order by BarTime desc;
--select top 20 * from tms.MA order by BarTime desc;

--declare @timeGap int = 25;
--exec tms.sp_RecalculateAllMomentumIndicators  @TimeGap = @timeGap;
--EXEC tms.sp_UpdateEMA @timeGap = 60;
select * from tms.indicatorsCount
select top 10 * from tms.logsJob_processIndicators order by 1 desc;
select max(e.amount) as amount
from fin.equity e
select * 
--update t set t.timeClosed =GETUTCDATE()
from algo.strategyTracker t
where t.timeClosed is null
order by  1 desc
