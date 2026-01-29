declare         
	@timeGap int = null -- 3
	, @RealTimeframe int = null --=1
	, @RealTicker int = null --56;
;
SELECT * 
--into #tempEma 
FROM dbo.CalculateAllEMASeriesBatch(
        @timeGap,
        @RealTimeframe,
        @RealTicker
    )
order by bartime;

--select count(*) from  #tempEma ;select count(*) from tms.bars;
--drop table #tempEma ;
;

--truncate table tms.EMA;
select * from tms.EMA

-- Инкрементальное обновление за последние 60 минут

-- Тест MA функции
SELECT  * 
into #tempMA
FROM dbo.CalculateAllMASeriesBatch(60, NULL, NULL)
ORDER BY TickerJID, TimeFrameID, BarTime;
select * from #tempMA;
drop table #tempMA

go

/*
-- Проверка скорости (должно быть ~5-8 секунд)
DECLARE @StartTime DATETIME = GETDATE();
EXEC tms.sp_UpdateMA -- @timeGap = 120;
exec.tms.sp_UpdateEMA
SELECT DATEDIFF(MILLISECOND, @StartTime, GETDATE()) as ExecutionTimeMs;
*/


--dbo.UpdateMomentumIndicators

--truncate table tms.Indicators_Momentum
select * from tms.indicatorsCount