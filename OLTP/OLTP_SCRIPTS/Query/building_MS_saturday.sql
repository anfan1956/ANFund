use cTrader
go

DECLARE @timeGap INT  = 120 --  = null;
DECLARE @timeFrameID INT = 1 ;
DECLARE @tickerJID INT;
DECLARE @cutOffTime  DATETIME  = DATEADD(MINUTE, -@TimeGap,  (SELECT max(bartime) FROM tms.bars));;


; WITH c (BarID, TimeFrameID, TickerJID, BarTime, rowNum
			, MA5, MA8, MA20, MA30, MA50, MA100, MA200, MA500
			, MA21_FIB, MA55_FIB, MA144_FIB, MA233_FIB
			, MA195_NYSE, MA390_NYSE
			) as (
	SELECT
		b.ID,
		b.timeframeID, 
		b.TickerJID,
		b.barTime,
		ROW_NUMBER() OVER (
				PARTITION BY b.TickerJID, b.timeFrameID
				ORDER BY b.barTime
				) as rowNum,														--для того, чтобы не update существующие
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 5 PRECEDING AND CURRENT ROW), 5) AS MA5,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 8 PRECEDING AND CURRENT ROW), 5) AS MA8,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 20 PRECEDING AND CURRENT ROW), 5) AS MA20,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 30 PRECEDING AND CURRENT ROW), 5) AS MA30,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 50 PRECEDING AND CURRENT ROW), 5) AS MA50,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 100 PRECEDING AND CURRENT ROW), 5) AS MA100,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 200 PRECEDING AND CURRENT ROW), 5) AS MA200,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 500 PRECEDING AND CURRENT ROW), 5) AS MA500,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 21 PRECEDING AND CURRENT ROW), 5) AS MA21_FIB,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 55 PRECEDING AND CURRENT ROW), 5) AS MA55_FIB,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 144 PRECEDING AND CURRENT ROW), 5) AS MA144_FIB,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 233 PRECEDING AND CURRENT ROW), 5) AS MA233_FIB,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 195 PRECEDING AND CURRENT ROW), 5) AS MA195_NYSE,
		ROUND( AVG(b.closeValue) OVER (
				partition by b.TickerJID, b.timeFrameID ORDER BY b.barTime
				ROWS BETWEEN 390 PRECEDING AND CURRENT ROW), 5) AS MA390_NYSE
	FROM tms.bars b
		join ref.SymbolMapping sm on sm.assetID = TickerJID
	WHERE 1=1 
		And (@timeGap is null	  or b.barTime > @cutOffTime)
		And (@tickerJID is null	  or b.TickerJID =@tickerJID)
		And (@timeFrameID is null or b.timeframeID = @timeFrameID)
)
, s (BarID, TimeFrameID, TickerJID, BarTime
			, MA5, MA8, MA20, MA30, MA50, MA100, MA200, MA500
			, MA21_FIB, MA55_FIB, MA144_FIB, MA233_FIB
			, MA195_NYSE, MA390_NYSE
		) as (
	select 
		BarID
		, TimeFrameID
		, TickerJID
		, BarTime
		, case when rowNum < 5 then null
			else MA5 end
		, case when rowNum < 8 then null
			else MA8 end
		, case when rowNum < 20 then null
			else MA20 end
		, case when rowNum < 30 then null
			else MA30 end
		, case when rowNum < 50 then null
			else MA50 end
		, case when rowNum < 100 then null
			else MA100 end
		, case when rowNum < 200 then null
			else MA200 end
		, case when rowNum < 500 then null
			else MA500 end
		, case when rowNum < 21 then null
			else MA21_FIB end
		, case when rowNum < 55 then null
			else MA55_FIB end
		, case when rowNum < 144 then null
			else MA144_FIB end
		, case when rowNum < 233 then null
			else MA233_FIB end
		, case when rowNum < 195 then null
			else MA195_NYSE end
		, case when rowNum < 390 then null
			else MA390_NYSE end
	from c
)
merge tms.ma as t using s
on t.TickerJID = s.tickerJID
	and t.TimeFrameID = s.TimeFrameID
	and t.BarTime = s.barTime
when matched then update set
	BarID		= s.BarID,
	MA5			= coalesce(s.MA5,  t.MA5),
	MA8			= coalesce(s.MA8,  t.MA8 ),
	MA20		= coalesce(s.MA20, t.MA20),
	MA30		= coalesce(s.MA30, t.MA30),
	MA50		= coalesce(s.MA50, t.MA50),
	MA100		= coalesce(s.MA100, t.MA100),
	MA200		= coalesce(s.MA200, t.MA200),
	MA500		= coalesce(s.MA500, t.MA500),
	MA21_FIB	= coalesce(s.MA21_FIB, t.MA21_FIB),
	MA55_FIB	= coalesce(s.MA55_FIB, t.MA55_FIB),
	MA144_FIB	= coalesce(s.MA144_FIB, t.MA144_FIB),
	MA233_FIB	= coalesce(s.MA233_FIB, t.MA233_FIB),
	MA195_NYSE	= coalesce(s.MA195_NYSE, t.MA195_NYSE),
	MA390_NYSE	= coalesce(s.MA390_NYSE, t.MA390_NYSE)
when not matched then 
	insert (BarID, TickerJID, BarTime, TimeFrameID
			, MA5, MA8, MA20, MA30, MA50, MA100, MA200, MA500
			, MA21_FIB, MA55_FIB, MA144_FIB, MA233_FIB
			, MA195_NYSE, MA390_NYSE
				)
	values (BarID, TickerJID, BarTime, TimeFrameID
			, MA5, MA8, MA20, MA30, MA50, MA100, MA200, MA500
			, MA21_FIB, MA55_FIB, MA144_FIB, MA233_FIB
			, MA195_NYSE, MA390_NYSE
				)
;

--
select count (*) from tms.ma where ma.TickerJID = 17; 
--truncate table tms.ma
--select top 5 * from tms.bars order by ID
select * from tms.MA order by  BarTime;
--select ID, BarID, MA5, MA8 from tms.MA order by  BarTime;
