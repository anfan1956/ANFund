use cTrader
go

if OBJECT_ID('tms.sp_tickerStateActivate') is not null drop proc tms.sp_tickerStateActivate
go

create proc tms.sp_tickerStateActivate @symbols nvarchar(max), @flag nvarchar(max), @brokerID int = 2
as
Begin
	SET NOCOUNT ON;
	WITH s AS
	(
		SELECT 
			value AS symbol,
			ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rn
		FROM STRING_SPLIT(@symbols, ',')
	),
	f AS
	(
		SELECT 
			CASE WHEN value = '0' THEN NULL ELSE value END AS flag,
			ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS rn
		FROM STRING_SPLIT(@flag, ',')
	)
INSERT INTO tms.activeTickers (tickerJID, isActive, brokerID)
SELECT ID, f.flag, @brokerID
FROM s
	JOIN f ON s.rn = f.rn
	join ref.assetMasterTable mt on mt.ticker =s.symbol
	;
SELECT   'SYMBOLS UPDATED: '  +  CAST( @@ROWCOUNT	AS nvarchar(6))
END
go

/*
DECLARE @symbols NVARCHAR(MAX) = 'XAUUSD,XAGUSD,SPX500,BTCUSD';
DECLARE @flag NVARCHAR(MAX) = '1,1,1,1';
exec tms.sp_tickerStateActivate @symbols = @symbols, @flag= @flag;
*/


SELECT * FROM TMS.activeTickers