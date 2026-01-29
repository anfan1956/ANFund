if OBJECT_ID('tms.activeTickers_v') is not null drop view tms.activeTickers_v
go

create view tms.activeTickers_v as

select 
	c.clCode as classCode
	, m.ticker
	, m.ID as tickerID
	, m.name 
	, lot_size AS lotSize
	, t.isActive
from ref.assetMasterTable m
	join ref.assetClasses c on c.ID=m.assetClassID
	cross apply	(
				select top 1 * 
				from tms.activeTickers a
					where 1=1
						and	a.tickerJID = m.ID
						and a.isActive = 1
				order by modified desc
			) as t
go

select * from tms.activeTickers_v m

