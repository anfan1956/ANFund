use cTrader
go

if OBJECT_ID('tms.indicatorsCount') is not null drop view tms.indicatorsCount
go
create view tms.indicatorsCount as
select 
	count(*) as BARS_rowsCount 
	, em.EMA_rowsCount
	, ma.MA_rowsCount
	, momentum.Momentum_rowsCount
from tms.bars b
	cross apply (select count(*) as EMA_rowsCount from tms.EMA) as em
	cross apply (select count(*) as MA_rowsCount from tms.MA) as ma
	cross apply (select count(*) as Momentum_rowsCount from tms.Indicators_Momentum) as momentum
group by 
	em.EMA_rowsCount
	, ma.MA_rowsCount
	,  momentum.Momentum_rowsCount

go

select * from tms.indicatorsCount