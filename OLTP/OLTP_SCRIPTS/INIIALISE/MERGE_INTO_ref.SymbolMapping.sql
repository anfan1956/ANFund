use cTrader
go

select * from  ref.assetMasterTable where ID between 28 and 33
select * from ref.SymbolMapping order by 1 desc

MERGE INTO ref.SymbolMapping AS target
USING (
    SELECT 
        ID AS assetID,
        2 AS brokerID,
        1 AS platformID,
        ticker + '.US' AS Symbol,    -- Append '.US' for Pepperstone cTrader
        unit,
        lot_size,
        pip_size,
        GETDATE() AS modified
    FROM ref.assetMasterTable
    WHERE ID IN (28, 29, 33)          -- AAPL, GOOGL, NVDA
) AS source
ON (target.assetID = source.assetID 
    AND target.brokerID = source.brokerID 
    AND target.platformID = source.platformID)
WHEN MATCHED THEN
    UPDATE SET
        target.Symbol = source.Symbol,
        target.unit = source.unit,
        target.lot_size = source.lot_size,
        target.pip_size = source.pip_size,
        target.modified = source.modified
WHEN NOT MATCHED BY TARGET THEN
    INSERT (assetID, brokerID, platformID, Symbol, unit, lot_size, pip_size, modified)
    VALUES (source.assetID, source.brokerID, source.platformID, source.Symbol, 
            source.unit, source.lot_size, source.pip_size, source.modified);