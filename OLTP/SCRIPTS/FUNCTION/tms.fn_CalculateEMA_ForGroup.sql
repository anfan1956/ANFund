if OBJECT_ID ('tms.fn_CalculateEMA_ForGroup') is not null drop function tms.fn_CalculateEMA_ForGroup
go
CREATE FUNCTION tms.fn_CalculateEMA_ForGroup (
    @timeframeID INT,
    @tickerJID INT,
    @cutOffTime DATETIME, 
	@maxRcrs int
)
RETURNS TABLE
AS
RETURN
    WITH cte AS (
        SELECT 
            BarTime, 
            CloseValue, 
            ROW_NUMBER() OVER (ORDER BY BarTime) rn
        FROM tms.bars
        WHERE barTime > @cutOffTime
          AND timeframeID = @timeframeID
          AND TickerJID = @tickerJID
    ),
    ema AS (
        SELECT rn, BarTime, CloseValue, CAST(CloseValue AS DECIMAL(18,5)) ema
        FROM cte WHERE rn = 1
        UNION ALL
        SELECT c.rn, c.BarTime, c.CloseValue, 
               CAST((c.CloseValue * 0.2) + (e.ema * 0.8) AS DECIMAL(18,5))
        FROM cte c INNER JOIN ema e ON c.rn = e.rn + 1
		where c.rn<@maxRcrs
    )
    SELECT BarTime, CloseValue, ROUND(ema, 5) EMA9 FROM ema;
GO

-- »ÒÔÓÎ¸ÁÓ‚‡ÌËÂ
DECLARE @cutOffTime DATETIME = DATEADD(MINUTE, -7000, (SELECT MAX(bartime) FROM tms.bars));

SELECT 
    g.timeframeID,
    g.TickerJID,
    e.*
	, min(EMA9) over() as minim
	, max(EMA9) over() as maxim
FROM (
    SELECT DISTINCT timeframeID, TickerJID
    FROM tms.bars 
    WHERE 1=1
		and barTime > @cutOffTime
		and TickerJID =13
		and timeframeID = 5
) g
CROSS APPLY tms.fn_CalculateEMA_ForGroup(g.timeframeID, g.TickerJID, @cutOffTime, 20000) e
ORDER BY g.timeframeID, g.TickerJID, e.BarTime
OPTION (MAXRECURSION 0);  -- »À» «ƒ≈—‹


select count (distinct TickerJID)
from tms.bars