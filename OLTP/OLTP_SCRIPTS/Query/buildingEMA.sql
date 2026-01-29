SELECT TOP 5 
    b.ID, 
    100 + CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) AS closeValue
FROM tms.bars b 
WHERE timeframeID = 1 AND TickerJID = 56;


WITH BarsWithRandomClose AS (
    -- Step 1: Generate random close values for each bar
    SELECT TOP 5000 
        b.ID, 
        b.closeValue AS closeValue
--        100 + CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) AS closeValue
    FROM tms.bars b
    WHERE b.timeframeID = 1 AND b.TickerJID = 56
    ORDER BY b.ID
),
NumberedBars AS (
    -- Step 2: Add row numbers for ordering
    SELECT 
        ID,
        closeValue,
        ROW_NUMBER() OVER (ORDER BY ID) AS RowNum
    FROM BarsWithRandomClose
),
InitialEMA AS (
    -- Step 3: Calculate the SMA for the first 5 rows
    SELECT 
        ID,
        closeValue,
        CAST(NULL AS FLOAT) AS EMA_5, -- First 4 rows will remain NULL
        RowNum
    FROM NumberedBars
    WHERE RowNum < 5 -- First 4 rows

    UNION ALL

    SELECT 
        ID,
        closeValue,
        CAST(AVG(closeValue * 1.0) OVER (ORDER BY RowNum ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS FLOAT) AS EMA_5, -- SMA for the 5th row
        RowNum
    FROM NumberedBars
    WHERE RowNum = 5
),
RecursiveEMA AS (
    -- Step 4: Calculate EMA recursively
    SELECT 
        ID,
        closeValue,
        EMA_5,
        RowNum
    FROM InitialEMA

    UNION ALL

    SELECT 
        b.ID,
        b.closeValue,
        (b.closeValue * (2.0 / (5 + 1))) + 
        (r.EMA_5 * (1 - (2.0 / (5 + 1)))) AS EMA_5, -- EMA formula
        b.RowNum
    FROM NumberedBars b
    INNER JOIN RecursiveEMA r ON b.RowNum = r.RowNum + 1 -- Join with the previous row
    WHERE b.RowNum > 5 -- Start EMA calculation from the 6th row
)
SELECT 
    ID,
    closeValue,
    EMA_5
FROM RecursiveEMA
ORDER BY ID
OPTION (MAXRECURSION 0); -- Allow recursion for all rows
