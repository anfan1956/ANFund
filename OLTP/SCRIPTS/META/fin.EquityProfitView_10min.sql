USE cTrader
GO

IF OBJECT_ID('fin.EquityProfitView_10min', 'V') IS NOT NULL
    DROP VIEW fin.EquityProfitView_10min
GO

CREATE VIEW fin.EquityProfitView_10min
AS
WITH EquityLatest AS (
    -- Get the latest equity record in each 10-minute interval
    SELECT 
        e.accountID,
        DATEADD(MINUTE, 10, DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, e.equityDate) / 10) * 10, 0)) AS IntervalEnd,
        e.amount AS Equity,
        e.marginUsed,
        e.marginFree,
        e.marginLevel,
        ROW_NUMBER() OVER (
            PARTITION BY e.accountID, DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, e.equityDate) / 10) * 10, 0)
            ORDER BY e.equityDate DESC
        ) AS rn
    FROM fin.equity e
),
LatestProfits AS (
    -- Get all profit records with their interval
    SELECT 
        p.accountID,
        DATEADD(MINUTE, 10, DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, ps.timestamp) / 10) * 10, 0)) AS IntervalEnd,
        ps.timestamp,
        ps.netProfit,
        ps.grossProfit,
        ps.positionID
    FROM trd.position p
    INNER JOIN trd.positionState ps ON p.ID = ps.positionID
),
LatestProfitSums AS (
    -- For each interval, get the latest timestamp and sum all profits at that timestamp
    SELECT 
        lp.accountID,
        lp.IntervalEnd,
        MAX(lp.timestamp) AS LatestTimestamp,
        SUM(lp.netProfit) AS TotalNetProfit,
        SUM(lp.grossProfit) AS TotalGrossProfit,
        COUNT(DISTINCT lp.positionID) AS ActivePositions
    FROM LatestProfits lp
    INNER JOIN (
        -- Get the latest timestamp for each account and interval
        SELECT 
            accountID,
            IntervalEnd,
            MAX(timestamp) AS MaxTimestamp
        FROM LatestProfits
        GROUP BY accountID, IntervalEnd
    ) latest ON lp.accountID = latest.accountID 
              AND lp.IntervalEnd = latest.IntervalEnd 
              AND lp.timestamp = latest.MaxTimestamp
    GROUP BY lp.accountID, lp.IntervalEnd
)
SELECT 
    a.AccountNumber,
    br.BrokerName,
    -- Show only IntervalEnd with format "dd.MM HH:mm"
    FORMAT(e.IntervalEnd, 'dd.MM HH:mm') AS IntervalEnd,
    e.Equity,
    e.MarginUsed,
    e.MarginFree,
    e.MarginLevel,
    -- Get the latest total profit sums with ISNULL
    ISNULL(ps.TotalNetProfit, 0) AS TotalNetProfit,
    ISNULL(ps.TotalGrossProfit, 0) AS TotalGrossProfit,
    ISNULL(ps.ActivePositions, 0) AS ActivePositions
FROM EquityLatest e
INNER JOIN trd.account a ON e.accountID = a.ID
INNER JOIN trd.brokers br ON a.brokerID = br.ID
LEFT JOIN LatestProfitSums ps ON e.accountID = ps.accountID AND e.IntervalEnd = ps.IntervalEnd
WHERE e.rn = 1  -- Only get the latest equity record in each interval
and e.IntervalEnd >= '2025-12-30 15:00'
GO

-- Test the view
SELECT *
FROM fin.EquityProfitView_10min 
--where IntervalEnd > '2025-12-30 15:00'
ORDER BY IntervalEnd desc
GO