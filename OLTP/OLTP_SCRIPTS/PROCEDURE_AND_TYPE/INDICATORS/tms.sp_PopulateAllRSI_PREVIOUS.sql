USE cTrader
GO

PRINT 'Dropping old procedure if exists...'
IF OBJECT_ID('tms.sp_PopulateAllRSI', 'P') IS NOT NULL
    DROP PROCEDURE tms.sp_PopulateAllRSI
GO

PRINT 'Creating new procedure sp_PopulateAllRSI...'
GO

CREATE PROCEDURE tms.sp_PopulateAllRSI
    @DaysBack INT = 5000,               -- Сколько дней данных обрабатывать
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
    PRINT 'STARTING MASS RSI CALCULATION';
    PRINT 'Master Batch ID: ' + CAST(@MasterBatchID AS VARCHAR(36));
    PRINT 'Days Back: ' + CAST(@DaysBack AS VARCHAR(10));
    PRINT 'Current Date: ' + CONVERT(VARCHAR(30), @CurrentDate, 120);
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
    
    -- Заполняем очередь задач
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
      AND tf.ID IN (1,2,3,4,5)  -- M1, M5, M15, M30, H1
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
        
        PRINT '-----------------------------------------------------------';
        PRINT 'Processing: ' + @CurrentSymbol + ' (' + @CurrentTimeFrameCode + ')';
        PRINT 'QueueID: ' + CAST(@CurrentQueueID AS VARCHAR(10));
        PRINT 'BatchID: ' + CAST(@CurrentBatchID AS VARCHAR(36));
        PRINT '-----------------------------------------------------------';
        
        BEGIN TRY
            UPDATE #ProcessingQueue 
            SET Status = 'IN_PROGRESS',
                BatchID = @CurrentBatchID,
                StartTime = @CurrentStartTime
            WHERE QueueID = @CurrentQueueID;
            
            -- Вызываем процедуру расчета RSI с исправленным вызовом
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
            PRINT '✓ Completed: ' + @CurrentSymbol + ' (' + @CurrentTimeFrameCode + ')';
            
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            SET @ErrorCount = @ErrorCount + 1;
            
            PRINT '✗ ERROR: ' + @CurrentSymbol + ' (' + @CurrentTimeFrameCode + ')';
            PRINT '  Message: ' + @ErrorMessage;
            
            UPDATE #ProcessingQueue 
            SET Status = 'FAILED',
                EndTime = SYSDATETIME(),
                DurationMS = DATEDIFF(MILLISECOND, StartTime, SYSDATETIME()),
                ErrorMessage = @ErrorMessage
            WHERE QueueID = @CurrentQueueID;
        END CATCH
        
        WAITFOR DELAY '00:00:00.100';
    END
    
    DECLARE @TotalTimeMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME());
    
    PRINT '===================================================================';
    PRINT 'PROCESSING COMPLETED';
    PRINT 'Total time: ' + CAST(@TotalTimeMS AS VARCHAR(10)) + ' ms';
    PRINT 'Tasks processed: ' + CAST(@ProcessedCount AS VARCHAR(10)) + ' of ' + CAST(@TotalToProcess AS VARCHAR(10));
    PRINT 'Errors: ' + CAST(@ErrorCount AS VARCHAR(10));
    PRINT '===================================================================';
    
    SELECT 
        Status,
        COUNT(*) as TaskCount,
        AVG(DurationMS) as AvgDurationMS
    FROM #ProcessingQueue
    GROUP BY Status;
    
    DROP TABLE #ProcessingQueue;
END
GO

PRINT 'Procedure tms.sp_PopulateAllRSI created successfully!';
GO


USE cTrader
GO

-- Запускаем РЕАЛЬНЫЙ расчет только для XAUUSD M5
EXEC tms.sp_PopulateAllRSI
    @DaysBack = 9999,           -- ВСЕ данные
    @TimeFramesCSV = '2',       -- Только M5 (ID=2)
    @SymbolsCSV = 'XAUUSD',     -- Только XAUUSD
    @TestMode = 0;              -- РЕАЛЬНЫЙ расчет

USE cTrader
GO

-- Проверяем результат для XAUUSD M5
SELECT 
    COUNT(*) as TotalIndicators,
    MIN(BarTime) as FirstBar,
    MAX(BarTime) as LastBar,
    AVG(RSI_14) as AvgRSI,
    MIN(RSI_14) as MinRSI,
    MAX(RSI_14) as MaxRSI,
    SUM(CASE WHEN Overbought_Flag = 1 THEN 1 ELSE 0 END) as OverboughtCount,
    SUM(CASE WHEN Oversold_Flag = 1 THEN 1 ELSE 0 END) as OversoldCount
FROM tms.Indicators_Momentum 
WHERE TickerJID = 13  -- XAUUSD
  AND TimeFrameID = 2; -- M5

-- Смотрим последние 10 записей
SELECT TOP 10 
    BarTime,
    RSI_14,
    RSI_7,
    RSI_21,
    RSI_ZScore,
    RSI_Percentile,
    Momentum_Score,
    Overbought_Flag,
    Oversold_Flag
FROM tms.Indicators_Momentum 
WHERE TickerJID = 13 
  AND TimeFrameID = 2
ORDER BY BarTime DESC;

select * from tms.timeframes