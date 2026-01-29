/*
MarketRegimeBulkProcedure
*/

IF OBJECT_ID('tms.CalculateMarketRegimeBulk') IS NOT NULL
    DROP PROCEDURE tms.CalculateMarketRegimeBulk;
GO

IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SQL_CLR_MarketRegime')
    DROP ASSEMBLY [SQL_CLR_MarketRegime];
GO

CREATE ASSEMBLY [SQL_CLR_MarketRegime]
FROM 'D:\TradingSystems\CLR\SQL_CLR_MarketRegime\bin\Debug\SQL_CLR_MarketRegime.dll'
WITH PERMISSION_SET = UNSAFE;
GO

CREATE PROCEDURE tms.CalculateMarketRegimeBulk
    @timeGap INT = NULL,
    @filterTimeframeID INT = NULL,
    @filterTickerJID INT = NULL
AS EXTERNAL NAME [SQL_CLR_MarketRegime].[MarketRegimeBulkProcedure].[CalculateMarketRegimeBulk];
GO