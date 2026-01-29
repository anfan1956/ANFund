USE cTrader
GO

PRINT 'Updating procedure sp_PopulateAllRSI to include all timeframes...'

-- Удаляем старую
IF OBJECT_ID('tms.sp_PopulateAllRSI', 'P') IS NOT NULL
    DROP PROCEDURE tms.sp_PopulateAllRSI
GO

-- Создаем новую с ВСЕМИ таймфреймами (1-9)
CREATE PROCEDURE tms.sp_PopulateAllRSI
    @DaysBack INT = 7,               -- Сколько дней данных обрабатывать
    @TimeFramesCSV VARCHAR(100) = NULL,  -- Какие таймфреймы
    @SymbolsCSV VARCHAR(MAX) = NULL,     -- Какие символы
    @MaxParallel INT = 5,            -- Максимум параллельных процессов
    @TestMode BIT = 0                -- 1 = только просмотр
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2(3) = SYSDATETIME();
    DECLARE @MasterBatchID UNIQUEIDENTIFIER = NEWID();
    DECLARE @ProcessedCount INT = 0;
    DECLARE @TotalToProcess INT = 0;
    DECLARE @ErrorCount INT = 0;
    DECLARE @CurrentDate DATETIME2(3) = GETUTCDATE();
    
    PRINT '===================================================================';
    PRINT 'STARTING MASS RSI CALCULATION (ALL TIMEFRAMES 1-9)';
    PRINT 'Master Batch ID: ' + CAST(@MasterBatchID AS VARCHAR(36));
    PRINT '===================================================================';
    
    -- Создаем таблицу для хранения задач
    CREATE TABLE #ProcessingQueue (
        QueueID INT IDENTITY(1,1) PRIMARY KEY,
        TickerJID INT NOT NULL,
        Symbol VARCHAR(20) NOT NULL,
        TimeFrameID INT NOT NULL,
        TimeFrameCode VARCHAR(10) NOT NULL,
        BarCount INT NULL,
        Status VARCHAR(20) DEFAULT 'PENDING',
        BatchID UNIQUEIDENTIFIER NULL,
        StartTime DATETIME2(3) NULL,
        EndTime DATETIME2(3) NULL,
        DurationMS INT NULL,
        ErrorMessage NVARCHAR(MAX) NULL
    );
    
    -- Заполняем очередь задач ВСЕМИ таймфреймами (1-9)
    INSERT INTO #ProcessingQueue (TickerJID, Symbol, TimeFrameID, TimeFrameCode, BarCount)
    SELECT 
        am.ID AS TickerJID,
        am.ticker AS Symbol,
        tf.ID AS TimeFrameID,
        tf.timeframeCode AS TimeFrameCode,
        (SELECT COUNT(*) 
         FROM tms.Bars b 
         WHERE b.TickerJID = am.ID 
           AND b.TimeFrameID = tf.ID 
           AND b.BarTime >= DATEADD(day, -@DaysBack, @CurrentDate)) AS BarCount
    FROM ref.assetMasterTable am
    CROSS JOIN tms.TimeFrames tf
    WHERE 1=1
      AND tf.ID BETWEEN 1 AND 9  -- ВСЕ таймфреймы M1-MN1
      AND EXISTS (SELECT 1 
                  FROM tms.Bars b 
                  WHERE b.TickerJID = am.ID 
                    AND b.TimeFrameID = tf.ID 
                    AND b.BarTime >= DATEADD(day, -@DaysBack, @CurrentDate))
    ORDER BY am.ticker, tf.ID;
    
    -- Фильтруем по CSV если нужно
    IF @TimeFramesCSV IS NOT NULL
    BEGIN
        DELETE FROM #ProcessingQueue
        WHERE TimeFrameID NOT IN (
            SELECT CAST(value AS INT) 
            FROM STRING_SPLIT(@TimeFramesCSV, ',')
        );
    END
    
    IF @SymbolsCSV IS NOT NULL
    BEGIN
        DELETE FROM #ProcessingQueue
        WHERE Symbol NOT IN (
            SELECT TRIM(value) 
            FROM STRING_SPLIT(@SymbolsCSV, ',')
        );
    END
    
    SET @TotalToProcess = @@ROWCOUNT;
    
    PRINT 'Queue prepared. Total tasks: ' + CAST(@TotalToProcess AS VARCHAR(10));
    
    -- Если TestMode = 1, только показываем
    IF @TestMode = 1
    BEGIN
        PRINT 'TEST MODE - No calculations will be performed';
        SELECT * FROM #ProcessingQueue ORDER BY Symbol, TimeFrameID;
        DROP TABLE #ProcessingQueue;
        RETURN;
    END
    
    -- Обрабатываем задачи
    DECLARE @CurrentQueueID INT;
    DECLARE @CurrentTickerJID INT;
    DECLARE @CurrentSymbol VARCHAR(20);
    DECLARE @CurrentTimeFrameID INT;
    DECLARE @CurrentTimeFrameCode VARCHAR(10);
    DECLARE @CurrentBatchID UNIQUEIDENTIFIER;
    DECLARE @CurrentStartTime DATETIME2(3);
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    WHILE EXISTS (SELECT 1 FROM #ProcessingQueue WHERE Status = 'PENDING')
    BEGIN
        SELECT TOP 1 
            @CurrentQueueID = QueueID,
            @CurrentTickerJID = TickerJID,
            @CurrentSymbol = Symbol,
            @CurrentTimeFrameID = TimeFrameID,
            @CurrentTimeFrameCode = TimeFrameCode
        FROM #ProcessingQueue 
        WHERE Status = 'PENDING'
        ORDER BY QueueID;
        
        SET @CurrentStartTime = SYSDATETIME();
        SET @CurrentBatchID = NEWID();
        
        PRINT '[' + CAST(@ProcessedCount + 1 AS VARCHAR(10)) + '/' + CAST(@TotalToProcess AS VARCHAR(10)) + '] ';
        PRINT 'Processing: ' + @CurrentSymbol + ' (' + @CurrentTimeFrameCode + ')';
        
        BEGIN TRY
            UPDATE #ProcessingQueue 
            SET Status = 'IN_PROGRESS',
                BatchID = @CurrentBatchID,
                StartTime = @CurrentStartTime
            WHERE QueueID = @CurrentQueueID;
            
            -- Вызываем процедуру расчета RSI
            DECLARE @CalcStartDate DATETIME2(3) = DATEADD(day, -@DaysBack, @CurrentDate);
            DECLARE @CalcEndDate DATETIME2(3) = @CurrentDate;
            
            EXEC tms.sp_CalculateAndPopulateRSI
                @TickerJID = @CurrentTickerJID,
                @TimeFrameID = @CurrentTimeFrameID,
                @StartDate = @CalcStartDate,
                @EndDate = @CalcEndDate,
                @ForceRecalculation = 1,
                @BatchID = @CurrentBatchID OUTPUT;
            
            UPDATE #ProcessingQueue 
            SET Status = 'COMPLETED',
                EndTime = SYSDATETIME(),
                DurationMS = DATEDIFF(MILLISECOND, StartTime, SYSDATETIME())
            WHERE QueueID = @CurrentQueueID;
            
            SET @ProcessedCount = @ProcessedCount + 1;
            PRINT '  ✓ Completed in ' + CAST(DATEDIFF(MILLISECOND, @CurrentStartTime, SYSDATETIME()) AS VARCHAR(10)) + ' ms';
            
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            SET @ErrorCount = @ErrorCount + 1;
            
            PRINT '  ✗ ERROR: ' + @ErrorMessage;
            
            UPDATE #ProcessingQueue 
            SET Status = 'FAILED',
                EndTime = SYSDATETIME(),
                DurationMS = DATEDIFF(MILLISECOND, StartTime, SYSDATETIME()),
                ErrorMessage = @ErrorMessage
            WHERE QueueID = @CurrentQueueID;
        END CATCH
        
        -- Маленькая пауза
        IF (@ProcessedCount % 5) = 0  -- Каждые 5 задач
            WAITFOR DELAY '00:00:00.050';
    END
    
    DECLARE @TotalTimeMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME());
    DECLARE @TotalTimeMIN DECIMAL(10,2) = @TotalTimeMS / 60000.0;
    
    PRINT '===================================================================';
    PRINT 'PROCESSING COMPLETED';
    PRINT 'Total time: ' + CAST(@TotalTimeMIN AS VARCHAR(10)) + ' minutes';
    PRINT 'Tasks: ' + CAST(@ProcessedCount AS VARCHAR(10)) + ' of ' + CAST(@TotalToProcess AS VARCHAR(10));
    PRINT 'Errors: ' + CAST(@ErrorCount AS VARCHAR(10));
    PRINT '===================================================================';
    
    SELECT 
        Status,
        COUNT(*) as TaskCount,
        AVG(DurationMS) as AvgDurationMS
    FROM #ProcessingQueue
    GROUP BY Status;
    
    -- Итоговая статистика
    SELECT 
        COUNT(*) as TotalIndicators,
        COUNT(DISTINCT TickerJID) as UniqueSymbols,
        COUNT(DISTINCT TimeFrameID) as UniqueTimeFrames,
        MIN(BarTime) as EarliestBar,
        MAX(BarTime) as LatestBar
    FROM tms.Indicators_Momentum;
    
    DROP TABLE #ProcessingQueue;
END
GO

PRINT 'Procedure tms.sp_PopulateAllRSI updated successfully!';
GO


USE cTrader
GO

-- ТОЛЬКО ПРОСМОТР (все символы, все таймфреймы)
EXEC tms.sp_PopulateAllRSI
    @DaysBack = 9999,
    @TestMode = 1;


USE cTrader
GO

-- Запускаем РЕАЛЬНЫЙ расчет для ВСЕХ символов и ВСЕХ таймфреймов
EXEC tms.sp_PopulateAllRSI
    @DaysBack = 9999,           -- ВСЕ данные
    @TimeFramesCSV = NULL,      -- ВСЕ таймфреймы (1-9)
    @SymbolsCSV = NULL,         -- ВСЕ символы
    @TestMode = 0;              -- РЕАЛЬНЫЙ расчет


USE cTrader
GO

-- Детальная статистика по символам
SELECT 
    am.ticker AS Symbol,
    COUNT(*) AS TotalIndicators,
    MIN(im.BarTime) AS FirstBar,
    MAX(im.BarTime) AS LastBar,
    AVG(im.RSI_14) AS AvgRSI14,
    SUM(CASE WHEN im.Overbought_Flag = 1 THEN 1 ELSE 0 END) AS OverboughtCount,
    SUM(CASE WHEN im.Oversold_Flag = 1 THEN 1 ELSE 0 END) AS OversoldCount
FROM tms.Indicators_Momentum im
INNER JOIN ref.assetMasterTable am ON im.TickerJID = am.ID
GROUP BY am.ticker
ORDER BY am.ticker;

-- Статистика по таймфреймам
SELECT 
    tf.timeframeCode AS TimeFrame,
    COUNT(*) AS TotalIndicators,
    AVG(im.RSI_14) AS AvgRSI14
FROM tms.Indicators_Momentum im
INNER JOIN tms.TimeFrames tf ON im.TimeFrameID = tf.ID
GROUP BY tf.timeframeCode, tf.ID
ORDER BY tf.ID;

-- Проверяем распределение RSI значений
SELECT 
    CASE 
        WHEN RSI_14 < 20 THEN '0-20 (Extreme Oversold)'
        WHEN RSI_14 < 30 THEN '20-30 (Oversold)'
        WHEN RSI_14 < 40 THEN '30-40 (Bearish)'
        WHEN RSI_14 < 60 THEN '40-60 (Neutral)'
        WHEN RSI_14 < 70 THEN '60-70 (Bullish)'
        WHEN RSI_14 < 80 THEN '70-80 (Overbought)'
        ELSE '80-100 (Extreme Overbought)'
    END AS RSI_Range,
    COUNT(*) AS Count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM tms.Indicators_Momentum
WHERE RSI_14 IS NOT NULL
GROUP BY 
    CASE 
        WHEN RSI_14 < 20 THEN '0-20 (Extreme Oversold)'
        WHEN RSI_14 < 30 THEN '20-30 (Oversold)'
        WHEN RSI_14 < 40 THEN '30-40 (Bearish)'
        WHEN RSI_14 < 60 THEN '40-60 (Neutral)'
        WHEN RSI_14 < 70 THEN '60-70 (Bullish)'
        WHEN RSI_14 < 80 THEN '70-80 (Overbought)'
        ELSE '80-100 (Extreme Overbought)'
    END
ORDER BY MIN(RSI_14);


select top 10 * from tms.Indicators_Momentum