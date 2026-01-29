USE cTrader
GO

if OBJECT_ID('tms.fn_activeTickers') is not null drop function tms.fn_activeTickers
go
		
create function tms.fn_activeTickers (@brokerID int =2)
returns nvarchar(max) as 
begin
	declare @symbolString nvarchar(max);
	with s as (
		select distinct  sm.Symbol, t.brokerID
		from tms.activeTickers t
		join ref.SymbolMapping sm on sm.assetID=t.tickerJID
			cross apply 
			(
				select top 1 * 
				from tms.activeTickers a
					where 1=1
						and	t.tickerJID = a.tickerJID
						and t.isActive = 1
				order by modified desc
			) as a
		) 
		select @symbolString = STRING_AGG(s.Symbol, ', ')
		from s;

		return @symbolString
	end
go
select tms.fn_activeTickers( default);

		