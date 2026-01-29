use cTrader
go

if OBJECT_ID ('trd.lastBars_v')	 is not null drop view trd.lastBars_v
go
create view trd.lastBars_v as
	with s as (
	select top 100 
	  b.barTime
	, b.openValue
	, b.highValue
	, lowValue
	, closeValue
    FROM tms.bars b
    WHERE b.timeframeID = 1 AND b.TickerJID = 56
    ORDER BY b.barTime desc
	)
	select 
	* from s 
go	
	
select * from trd.lastBars_v s
order by s.barTime

