-- Более производительный вариант с CROSS APPLY
UPDATE b
SET 
    MA5 = ma.MA5,
    MA20 = ma.MA20,
    MA30 = ma.MA30,
    MA50 = ma.MA50,
    MA100 = ma.MA100,
    MA200 = ma.MA200,
    MA500 = ma.MA500
FROM tms.bars b
CROSS APPLY (
    SELECT 
        AVG(CASE WHEN rn <= 5 THEN closeValue END) AS MA5,
        AVG(CASE WHEN rn <= 20 THEN closeValue END) AS MA20,
        AVG(CASE WHEN rn <= 30 THEN closeValue END) AS MA30,
        AVG(CASE WHEN rn <= 50 THEN closeValue END) AS MA50,
        AVG(CASE WHEN rn <= 100 THEN closeValue END) AS MA100,
        AVG(CASE WHEN rn <= 200 THEN closeValue END) AS MA200,
        AVG(CASE WHEN rn <= 500 THEN closeValue END) AS MA500
    FROM (
        SELECT 
            closeValue,
            ROW_NUMBER() OVER (ORDER BY barTime DESC) AS rn
        FROM tms.bars b2
        WHERE b2.TickerJID = b.TickerJID
          AND b2.timeframeID = b.timeframeID
          AND b2.sourceID = b.sourceID
          AND b2.barTime <= b.barTime
    ) AS ranked_bars
) AS ma
WHERE b.MA5 IS NULL 
   OR b.MA20 IS NULL
   OR b.MA30 IS NULL
   OR b.MA50 IS NULL
   OR b.MA100 IS NULL
   OR b.MA200 IS NULL
   OR b.MA500 IS NULL;
GO