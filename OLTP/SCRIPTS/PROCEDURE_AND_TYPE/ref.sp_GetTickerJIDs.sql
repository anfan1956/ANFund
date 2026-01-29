CREATE OR ALTER PROCEDURE ref.sp_GetTickerJIDs
    @symbolsCSV NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        mp.Symbol AS SymbolName,
        mt.id AS TickerJID
    FROM ref.assetMasterTable mt
		join ref.SymbolMapping mp on mp.assetID = mt.ID
    WHERE mp.Symbol IN (
        SELECT LTRIM(RTRIM(value)) 
        FROM STRING_SPLIT(@symbolsCSV, ',')
        WHERE LTRIM(RTRIM(value)) <> ''
    )
    ORDER BY mt.ticker;
END
GO