-- Параметры
DECLARE @timeGap INT = 600;
DECLARE @tfID INT = 1;
DECLARE @tckID INT = 56;
DECLARE @alpha FLOAT = 2.0 / (9 + 1);
DECLARE @cutOffTime DATETIME = DATEADD(MINUTE, -@TimeGap, (SELECT MAX(bartime) FROM tms.bars));

WITH NumberedBars AS (
    SELECT 
        BarTime,
        CloseValue,
        ROW_NUMBER() OVER (ORDER BY BarTime) AS rn
    FROM tms.bars
    WHERE TickerJID = @tckID 
      AND timeframeID = @tfID
      AND barTime > @cutOffTime
)
SELECT 
    n.BarTime,
    n.CloseValue,
    ROUND(
        @alpha * SUM(
            prev.CloseValue * POWER(1 - @alpha, n.rn - prev.rn)
        ),
        5
    ) AS EMA9
FROM NumberedBars n
OUTER APPLY (
    SELECT * FROM NumberedBars prev WHERE prev.rn <= n.rn
) prev
GROUP BY n.BarTime, n.CloseValue, n.rn
ORDER BY n.BarTime;