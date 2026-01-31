declare @days int =0;

declare @date date  = dateadd(dd,  - @days ,   cast(getdate() as date));

select 

max(amount) amount

from fin.equity e  
	where e.equityDate >=@date

select top 5 * from logs.strategyExecution se order by 1 desc;

select * from algo.strategies_positions
select * from algo.strategyTracker