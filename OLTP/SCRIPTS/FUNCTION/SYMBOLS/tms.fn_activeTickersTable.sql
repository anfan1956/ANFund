use cTrader
go

IF OBJECT_ID('tms.fn_activeTickersTable') IS NOT NULL 
    DROP FUNCTION tms.fn_activeTickersTable;
GO

CREATE FUNCTION tms.fn_activeTickersTable (@all BIT = 1)
RETURNS TABLE 
AS 
RETURN
    SELECT 
        c.clCode AS classCode,
        m.ticker,
        m.ID AS tickerID,
        m.name,
        lot_size AS lotSize,
        t.isActive
    FROM ref.assetMasterTable m
    JOIN ref.assetClasses c ON c.ID = m.assetClassID
    OUTER APPLY (
        SELECT TOP 1 * 
        FROM tms.activeTickers a
        WHERE a.tickerJID = m.ID
          AND a.isActive = 1
        ORDER BY a.modified DESC
    ) AS t
    WHERE @all = 1 
       OR t.isActive IS NOT NULL;
GO

select * from tms.fn_activeTickersTable (0)

select tms.fn_activeTickers(2)
