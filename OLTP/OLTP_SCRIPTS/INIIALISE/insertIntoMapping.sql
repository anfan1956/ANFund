use cTrader
go

select  * from ref.assetMasterTable where ID in (52, 53)  order by 1 desc;
select  * from ref.SymbolMapping order by 1 desc;

;
with s (assetID, brokerID, platformID, Symbol, unit, lot_size, pip_size) as (
	select 
		mt.ID
	, 2 as  brokerID
	, 1 platformid
	, mt.ticker
	, mt.unit
	, mt.lot_size
	, mt.pip_size
	from ref.assetMasterTable mt 
--		left join ref.symbolMapping t on mt.ID= t.assetID
--		outer apply (select top 1 * from ref.SymbolMapping sm where sm.ID = 52) as ca
	where mt.ID in (52, 53)

)
--insert ref.SymbolMapping(assetID, brokerID, platformID, Symbol, unit, lot_size, pip_size)
select assetID, brokerID, platformID, Symbol, unit, lot_size, pip_size from s;

/*
*/
