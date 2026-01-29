USE cTrader
GO

PRINT 'Creating procedure sp_CalculateAndPopulateRSI...'

-- Удаляем процедуру если существует
IF OBJECT_ID('tms.sp_CalculateAndPopulateRSI', 'P') IS NOT NULL
    DROP PROCEDURE tms.sp_CalculateAndPopulateRSI
GO

-- Создаем процедуру для расчета RSI (без Volume)
CREATE PROCEDURE tms.sp_CalculateAndPopulateRSI
    @TickerJID INT,
    @TimeFrameID INT,
    @StartDate DATETIME2(3) = NULL,
    @EndDate DATETIME2(3) = NULL,
    @ForceRecalculation BIT = 0,
    @BatchID UNIQUEIDENTIFIER = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Если не указана начальная дата, берем последние 7 дней
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -7, GETUTCDATE());
    
    IF @EndDate IS NULL
        SET @EndDate = GETUTCDATE();
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME2(3) = SYSDATETIME();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @MinutesPerBar INT;
    
    PRINT '=========================================';
    PRINT 'Starting RSI calculation...';
    PRINT 'TickerJID: ' + CAST(@TickerJID AS VARCHAR(10));
    PRINT 'TimeFrameID: ' + CAST(@TimeFrameID AS VARCHAR(10));
    PRINT 'StartDate: ' + CONVERT(VARCHAR(30), @StartDate, 120);
    PRINT 'EndDate: ' + CONVERT(VARCHAR(30), @EndDate, 120);
    PRINT 'BatchID: ' + CAST(@BatchID AS VARCHAR(36));
    PRINT '=========================================';
    
    -- Получаем минут на бар для этого таймфрейма
    SELECT @MinutesPerBar = minutes 
    FROM tms.TimeFrames 
    WHERE ID = @TimeFrameID;
    
    IF @MinutesPerBar IS NULL
    BEGIN
        RAISERROR('Invalid TimeFrameID', 16, 1);
        RETURN;
    END
    
    -- Создаем временную таблицу для баров (без Volume)
    CREATE TABLE #BarsData (
        RowNum INT IDENTITY(1,1),
        BarTime DATETIME2(3),
        OpenValue DECIMAL(18,6),
        HighValue DECIMAL(18,6),
        LowValue DECIMAL(18,6),
        CloseValue DECIMAL(18,6)
    );
    
    -- Заполняем временную таблицу с сортировкой
    INSERT INTO #BarsData (BarTime, OpenValue, HighValue, LowValue, CloseValue)
    SELECT 
        b.BarTime,
        b.OpenValue,
        b.HighValue,
        b.LowValue,
        b.CloseValue
    FROM tms.Bars b
    WHERE b.TickerJID = @TickerJID
      AND b.TimeFrameID = @TimeFrameID
      AND b.BarTime BETWEEN @StartDate AND @EndDate
    ORDER BY b.BarTime;
    
    -- Рассчитываем изменения цены
    WITH PriceChanges AS (
        SELECT 
            RowNum,
            BarTime,
            CloseValue,
            CloseValue - LAG(CloseValue, 1) OVER (ORDER BY RowNum) AS PriceChange,
            CASE 
                WHEN (CloseValue - LAG(CloseValue, 1) OVER (ORDER BY RowNum)) > 0 
                THEN CloseValue - LAG(CloseValue, 1) OVER (ORDER BY RowNum)
                ELSE 0 
            END AS Gain,
            CASE 
                WHEN (CloseValue - LAG(CloseValue, 1) OVER (ORDER BY RowNum)) < 0 
                THEN ABS(CloseValue - LAG(CloseValue, 1) OVER (ORDER BY RowNum))
                ELSE 0 
            END AS Loss
        FROM #BarsData
    ),
    -- Рассчитываем средние gain/loss для RSI
    RSICalculation AS (
        SELECT 
            RowNum,
            BarTime,
            CloseValue,
            AVG(Gain) OVER (ORDER BY RowNum ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS AvgGain14,
            AVG(Loss) OVER (ORDER BY RowNum ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS AvgLoss14,
            AVG(Gain) OVER (ORDER BY RowNum ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS AvgGain7,
            AVG(Loss) OVER (ORDER BY RowNum ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS AvgLoss7,
            AVG(Gain) OVER (ORDER BY RowNum ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) AS AvgGain21,
            AVG(Loss) OVER (ORDER BY RowNum ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) AS AvgLoss21
        FROM PriceChanges
    ),
    -- Рассчитываем RSI значения
    FinalRSI AS (
        SELECT 
            BarTime,
            CloseValue,
            -- RSI_14
            CASE 
                WHEN AvgLoss14 = 0 THEN 100
                ELSE 100 - (100 / (1 + (AvgGain14 / NULLIF(AvgLoss14, 0))))
            END AS RSI_14,
            -- RSI_7
            CASE 
                WHEN AvgLoss7 = 0 THEN 100
                ELSE 100 - (100 / (1 + (AvgGain7 / NULLIF(AvgLoss7, 0))))
            END AS RSI_7,
            -- RSI_21
            CASE 
                WHEN AvgLoss21 = 0 THEN 100
                ELSE 100 - (100 / (1 + (AvgGain21 / NULLIF(AvgLoss21, 0))))
            END AS RSI_21
        FROM RSICalculation
        WHERE RowNum >= 21  -- Нужно минимум 21 бар для всех расчетов
    )
    -- Обновляем таблицу индикаторов
    MERGE tms.Indicators_Momentum AS target
    USING FinalRSI AS source
    ON target.TickerJID = @TickerJID
       AND target.BarTime = source.BarTime
       AND target.TimeFrameID = @TimeFrameID
    WHEN MATCHED AND (@ForceRecalculation = 1 OR target.RSI_14 IS NULL) THEN
        UPDATE SET 
            target.RSI_14 = source.RSI_14,
            target.RSI_7 = source.RSI_7,
            target.RSI_21 = source.RSI_21,
            target.Overbought_Flag = CASE WHEN source.RSI_14 > 70 THEN 1 ELSE 0 END,
            target.Oversold_Flag = CASE WHEN source.RSI_14 < 30 THEN 1 ELSE 0 END,
            target.ModifiedDate = SYSDATETIME(),
            target.BatchID = @BatchID
    WHEN NOT MATCHED THEN
        INSERT (TickerJID, BarTime, TimeFrameID, SourceID, 
                RSI_14, RSI_7, RSI_21, 
                Overbought_Flag, Oversold_Flag, 
                BatchID, CreatedDate)
        VALUES (@TickerJID, source.BarTime, @TimeFrameID, 1, 
                source.RSI_14, source.RSI_7, source.RSI_21,
                CASE WHEN source.RSI_14 > 70 THEN 1 ELSE 0 END,
                CASE WHEN source.RSI_14 < 30 THEN 1 ELSE 0 END,
                @BatchID, SYSDATETIME());
    
    SET @RowsProcessed = @@ROWCOUNT;
    
    -- Очищаем временную таблицу
    DROP TABLE #BarsData;
    
    -- Теперь рассчитываем Z-Score и Percentile для новых записей
    IF @RowsProcessed > 0
    BEGIN
        PRINT 'Calculating Z-Score and Percentile for ' + CAST(@RowsProcessed AS VARCHAR(10)) + ' rows...';
        
        -- Временная таблица для статистики
        DECLARE @RSIStats TABLE (
            TickerJID INT,
            TimeFrameID INT,
            MeanRSI DECIMAL(8,4),
            StdDevRSI DECIMAL(8,4),
            MinRSI DECIMAL(8,4),
            MaxRSI DECIMAL(8,4)
        );
        
        -- Собираем статистику по RSI за последние 1000 баров
        INSERT INTO @RSIStats
        SELECT 
            @TickerJID,
            @TimeFrameID,
            AVG(RSI_14) AS MeanRSI,
            STDEV(RSI_14) AS StdDevRSI,
            MIN(RSI_14) AS MinRSI,
            MAX(RSI_14) AS MaxRSI
        FROM tms.Indicators_Momentum
        WHERE TickerJID = @TickerJID
          AND TimeFrameID = @TimeFrameID
          AND RSI_14 IS NOT NULL
          AND BarTime < (
              SELECT MAX(BarTime) 
              FROM tms.Indicators_Momentum 
              WHERE TickerJID = @TickerJID 
                AND TimeFrameID = @TimeFrameID
          )
          AND BarTime >= DATEADD(MINUTE, -(@MinutesPerBar * 1000), GETUTCDATE());
        
        -- Обновляем Z-Score и Percentile
        UPDATE im
        SET 
            RSI_ZScore = CASE 
                WHEN s.StdDevRSI > 0 
                THEN (im.RSI_14 - s.MeanRSI) / s.StdDevRSI 
                ELSE NULL 
            END,
            RSI_Percentile = CASE 
                WHEN s.MaxRSI > s.MinRSI 
                THEN ((im.RSI_14 - s.MinRSI) / (s.MaxRSI - s.MinRSI)) * 100
                ELSE 50 
            END,
            Momentum_Score = CASE 
                WHEN im.RSI_14 < 30 THEN 100 - im.RSI_14  -- Чем ниже RSI (oversold), тем выше скор
                WHEN im.RSI_14 > 70 THEN 100 - im.RSI_14  -- Чем выше RSI (overbought), тем ниже скор
                ELSE 50 + (ABS(50 - im.RSI_14) * 0.5)  -- Нейтральная зона
            END
        FROM tms.Indicators_Momentum im
        CROSS JOIN @RSIStats s
        WHERE im.TickerJID = @TickerJID
          AND im.TimeFrameID = @TimeFrameID
          AND im.BarTime BETWEEN @StartDate AND @EndDate
          AND im.RSI_14 IS NOT NULL
          AND im.BatchID = @BatchID;
    END
    
    DECLARE @EndTime DATETIME2(3) = SYSDATETIME();
    DECLARE @DurationMS INT = DATEDIFF(MILLISECOND, @StartTime, @EndTime);
    
    -- Обновляем время расчета
    UPDATE tms.Indicators_Momentum
    SET CalculationTimeMS = @DurationMS
    WHERE TickerJID = @TickerJID
      AND TimeFrameID = @TimeFrameID
      AND BatchID = @BatchID;
    
    PRINT '=========================================';
    PRINT 'RSI calculation completed!';
    PRINT 'Rows processed: ' + CAST(@RowsProcessed AS VARCHAR(10));
    PRINT 'Duration: ' + CAST(@DurationMS AS VARCHAR(10)) + ' ms';
    PRINT '=========================================';
    
    -- Возвращаем статистику
    SELECT 
        @BatchID AS BatchID,
        @RowsProcessed AS RowsProcessed,
        @DurationMS AS DurationMS;
END
GO

PRINT 'Procedure tms.sp_CalculateAndPopulateRSI created successfully!';
GO


USE cTrader
GO

-- Проверяем есть ли данные в Bars
SELECT TOP 5 
    b.TickerJID,
    am.ticker AS Symbol,
    COUNT(*) AS BarCount,
    MIN(b.BarTime) AS FirstBar,
    MAX(b.BarTime) AS LastBar
FROM tms.Bars b
INNER JOIN ref.assetMasterTable am ON b.TickerJID = am.ID
GROUP BY b.TickerJID, am.ticker
ORDER BY BarCount DESC;

-- Проверяем таймфреймы
SELECT * FROM tms.TimeFrames;


USE cTrader
GO

DECLARE @BatchID UNIQUEIDENTIFIER;
DECLARE @StartDate DATETIME2(3) = DATEADD(day, -2, GETUTCDATE());
DECLARE @EndDate DATETIME2(3) = GETUTCDATE();

PRINT 'StartDate: ' + CONVERT(VARCHAR(30), @StartDate, 120);
PRINT 'EndDate: ' + CONVERT(VARCHAR(30), @EndDate, 120);

-- Запускаем расчет RSI для XAUUSD M5 за последние 2 дня
EXEC tms.sp_CalculateAndPopulateRSI 
    @TickerJID = 13,          -- XAUUSD
    @TimeFrameID = 2,         -- M5
    @StartDate = @StartDate,
    @EndDate = @EndDate,
    @ForceRecalculation = 0,
    @BatchID = @BatchID OUTPUT;

-- Проверяем результат
PRINT 'BatchID: ' + CAST(@BatchID AS VARCHAR(36));

-- Проверяем сколько строк добавили
SELECT 
    COUNT(*) AS TotalRows,
    MIN(BarTime) AS FirstBar,
    MAX(BarTime) AS LastBar,
    AVG(RSI_14) AS AvgRSI14,
    SUM(CASE WHEN Overbought_Flag = 1 THEN 1 ELSE 0 END) AS OverboughtCount,
    SUM(CASE WHEN Oversold_Flag = 1 THEN 1 ELSE 0 END) AS OversoldCount
FROM tms.Indicators_Momentum 
WHERE TickerJID = 13 
  AND TimeFrameID = 2;

-- Смотрим первые 10 строк
SELECT TOP 10 
    im.BarTime,
    im.RSI_14,
    im.RSI_7,
    im.RSI_21,
    im.RSI_ZScore,
    im.RSI_Percentile,
    im.Momentum_Score,
    im.Overbought_Flag,
    im.Oversold_Flag,
    im.CalculationTimeMS
FROM tms.Indicators_Momentum im
WHERE im.TickerJID = 13 
  AND im.TimeFrameID = 2
ORDER BY im.BarTime DESC;

USE cTrader
GO

-- Проверяем View
SELECT TOP 20 
    Symbol,
    BarTime,
    TimeFrameCode,
    RSI_14,
    RSI_Condition,
    Trading_Signal,
    Momentum_Score,
    ZScore_Level,
    RSI_Trend_Direction
FROM tms.vw_Momentum_Signals 
WHERE TickerJID = 13 
  AND TimeFrameID = 2
  AND BarTime >= DATEADD(HOUR, -24, GETUTCDATE())
ORDER BY BarTime DESC;