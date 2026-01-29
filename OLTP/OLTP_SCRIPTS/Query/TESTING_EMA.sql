USE cTrader
go

declare @start datetime = GEtdate();

/**************************************************************************************************************************/
-- testing the full recalc procedure
if OBJECT_ID('tempdb..#tempEMA') is not null drop table #tempEma

/*
set @start = GETDATE();
DECLARE         
	@timeGap int = null 
	, @RealTimeframe int = null 
	, @RealTicker int = null ;
;
-- temp table to check the full recalc the procedure manually, duration and errors
SELECT * into #tempEma 
FROM dbo.CalculateAllEMASeriesBatch(
        @timeGap,
        @RealTimeframe,
        @RealTicker
    )
order by bartime;
select DATEDIFF(MILLISECOND, @start, GETDATE());

-- Просто быстро посмотреть последние 
SELECT TOP 1 e.EMA_50_MEDIUM, e.EMA_20_SHORT, t.closeValue
FROM  #tempEma e -- tms.EMA e
	join tms.bars t on t.ID =e.BarID
WHERE e.TickerJID = 13 
  AND e.TimeFrameID = 5
ORDER BY e.BarTime DESC  -- просто беру последнюю доступную EMA


select max(EMA_20_SHORT) maxim, min(EMA_20_SHORT) minim, min(EMA_50_MEDIUM) minEMA50, count(*) rcount
	, t.TimeFrameID, tf.timeframeName
from #tempEma t
	join tms.timeframes tf on tf.ID = t.TimeFrameID
where t.TickerJID = 13 and  datepart(YYYY, t.BarTime) >2025
group by  t.TimeFrameID, tf.timeframeName, datepart(YYYY, t.BarTime);
--select count(*) from  #tempEma ;select count(*) from tms.bars;
--drop table #tempEma ;

*/

/******************************************************************************************************************/


--testing the actual tms.EMA table after full update

EXEC tms.sp_UpdateEMA  @timeGap = NULL;

select max(EMA_20_SHORT) maxim, min(EMA_20_SHORT) minim, min(EMA_50_MEDIUM) minEMA50, count(*) rcount
	, t.TimeFrameID, tf.timeframeName
from tms.EMA t
	join tms.timeframes tf on tf.ID = t.TimeFrameID
where t.TickerJID = 13 and  datepart(YYYY, t.BarTime) >2025
group by  t.TimeFrameID, tf.timeframeName, datepart(YYYY, t.BarTime);


/*
*/

-- Инкрементальное обновление за последние 60 минут

go

/*
-- Проверка скорости (должно быть ~5-8 секунд)
DECLARE @StartTime DATETIME = GETDATE();
EXEC tms.sp_UpdateMA -- @timeGap = 120;
exec.tms.sp_UpdateEMA
SELECT DATEDIFF(MILLISECOND, @StartTime, GETDATE()) as ExecutionTimeMs;

--dbo.UpdateMomentumIndicators

--truncate table tms.Indicators_Momentum
select * from tms.indicatorsCount

SELECT TOP 1 e.EMA_50_MEDIUM, e.EMA_20_SHORT
FROM  #tempEma e -- tms.EMA e
WHERE e.TickerJID = 13 
  AND e.TimeFrameID = 5
ORDER BY e.BarTime DESC  -- просто беру последнюю доступную EMA
*/

/*******************************************************************************************************/
/*
EXEC tms.sp_UpdateEMA @timeGap = NULL;

WITH LatestBars AS (
    SELECT 
        TimeFrameID,
        MAX(BarTime) AS LatestBarTime
    FROM tms.EMA 
    WHERE TickerJID = 13
    GROUP BY TimeFrameID
)
SELECT 
    e.TimeFrameID,
    tf.timeframeName,
    e.BarTime,
    e.EMA_20_SHORT,
    e.EMA_50_MEDIUM
FROM tms.EMA e
JOIN LatestBars lb ON e.TimeFrameID = lb.TimeFrameID 
                   AND e.BarTime = lb.LatestBarTime
JOIN tms.Timeframes tf ON e.TimeFrameID = tf.ID
WHERE e.TickerJID = 13
ORDER BY e.TimeFrameID;

*/

/*
-- Сколько записей в tms.EMA для XAUUSD на H1 с BarTime = '2026-01-20 15:00:00'?
SELECT 
    BarTime,
    EMA_50_MEDIUM,
    EMA_20_SHORT,
    CreatedDate
FROM tms.EMA 
WHERE TickerJID = 13 
  AND TimeFrameID = 5 
  AND BarTime = '2026-01-20 15:00:00'
ORDER BY CreatedDate DESC;

--EXEC tms.sp_UpdateEMA;
*/
select top 10 * from tms.logsJob_processIndicators order by 1 desc

-- Последние записи EMA для XAUUSD M15
SELECT TOP 5 
	e.BarID,
    e.BarTime,
    e.EMA_20_SHORT,
    e.EMA_50_MEDIUM,
    e.CreatedDate
	, b.timeframeID, b.closeValue, b.TickerJID
	, b.barTime as barTimeSRC
FROM tms.EMA e
	join tms.bars b on b.ID = e.BarID
WHERE e.TickerJID = 13 
  AND e.TimeFrameID = 3
ORDER BY e.BarTime DESC;


SELECT 
	f.BarID,
    f.BarTime,
    f.EMA_20_SHORT,
    f.EMA_50_MEDIUM,
	b.closeValue,
	e.EMA_20_SHORT, 
	e.EMA_50_MEDIUM
FROM dbo.CalculateAllEMASeriesBatch(NULL, 3, 13) f
	join tms.bars b on b.ID = f.barID
	join tms.EMA e on e.BarID = f.BarID
WHERE f.BarTime = '2026-01-20 17:00:00';

-- Тест функции для XAUUSD M15
SELECT TOP 5 
    BarID,
    BarTime,
    RSI_14,
    Oversold_Flag,
    Overbought_Flag
FROM dbo.CalculateAllMomentumBatch(NULL, 3, 13)  -- M15, XAUUSD
ORDER BY BarTime DESC;-- Тест функции для XAUUSD M15


SELECT TOP 5 
*
FROM dbo.CalculateAllMomentumBatch(NULL, 3, 13)  -- M15, XAUUSD
ORDER BY BarTime DESC;



