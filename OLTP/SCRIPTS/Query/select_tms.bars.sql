

--SELECT * FROM ref.assetMasterTable mt where mt.ticker in ('XAUUSD', 'XAGUSD', 'NAS100');
select * from tms.bars  order by barTime desc, id desc;


--select * from ref.assetMasterTable;select * from ref.SymbolMapping

--SELECT ticker, id FROM ref.assetMasterTable mt where mt.ticker in ('XAUUSD', 'XAGUSD', 'NAS100');

--ref.sp_GetTickerJIDs 'XAUUSD, XAGUSD, NAS100, XPTUSD'