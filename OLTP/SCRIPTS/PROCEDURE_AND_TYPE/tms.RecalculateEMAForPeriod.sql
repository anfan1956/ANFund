USE [cTrader]
GO

-- =============================================
-- Author: AI Assistant
-- Create date: 2024
-- Description: ѕроцедура дл€ принудительного пересчета EMA за определенный период
-- =============================================
CREATE OR ALTER PROCEDURE tms.RecalculateEMAForPeriod
    @TickerJID INT = NULL,
    @TimeFrameID INT = NULL,
    @StartDate DATETIME = NULL,
    @EndDate DATETIME = NULL,
    @BatchSize INT = 500
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DeletedCount INT = 0;
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT 'Starting EMA recalculation process at: ' + CONVERT(VARCHAR, @StartTime, 120);
    
    IF @TickerJID IS NOT NULL
        PRINT 'TickerJID: ' + CAST(@TickerJID AS VARCHAR);
    
    IF @TimeFrameID IS NOT NULL
        PRINT 'TimeFrameID: ' + CAST(@TimeFrameID AS VARCHAR);
    
    IF @StartDate IS NOT NULL
        PRINT 'Start Date: ' + CONVERT(VARCHAR, @StartDate, 120);
    
    IF @EndDate IS NOT NULL
        PRINT 'End Date: ' + CONVERT(VARCHAR, @EndDate, 120);
    
    PRINT 'Batch Size: ' + CAST(@BatchSize AS VARCHAR);
    
    -- ќпредел€ем минимальную дату дл€ удалени€ (с учетом, что нужны данные дл€ расчета EMA)
    DECLARE @ActualStartDate DATETIME;
    
    IF @StartDate IS NOT NULL
    BEGIN
        -- ƒл€ EMA 233 нужно минимум 233 бара назад
        SET @ActualStartDate = DATEADD(DAY, -300, @StartDate);
    END
    ELSE
    BEGIN
        SET @ActualStartDate = NULL;
    END
    
    -- ”дал€ем существующие EMA записи дл€ указанного периода
    DELETE FROM tms.EMA
    WHERE BarID IN (
        SELECT b.ID
        FROM tms.Bars b
        WHERE (@TickerJID IS NULL OR b.TickerJID = @TickerJID)
          AND (@TimeFrameID IS NULL OR b.TimeFrameID = @TimeFrameID)
          AND (@StartDate IS NULL OR b.BarTime >= @StartDate)
          AND (@EndDate IS NULL OR b.BarTime <= @EndDate)
    );
    
    SET @DeletedCount = @@ROWCOUNT;
    
    PRINT 'Deleted ' + CAST(@DeletedCount AS VARCHAR) + ' existing EMA records';
    
    -- ѕолучаем бары дл€ пересчета
    DECLARE @BarsToRecalc TABLE (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        BarID BIGINT NOT NULL,
        TickerJID INT NOT NULL,
        TimeFrameID INT NOT NULL,
        BarTime DATETIME NOT NULL
    );
    
    -- ¬ставл€ем бары с учетом, что нужны данные дл€ расчета EMA
    INSERT INTO @BarsToRecalc (BarID, TickerJID, TimeFrameID, BarTime)
    SELECT 
        b.ID,
        b.TickerJID,
        b.TimeFrameID,
        b.BarTime
    FROM tms.Bars b
    WHERE (@TickerJID IS NULL OR b.TickerJID = @TickerJID)
      AND (@TimeFrameID IS NULL OR b.TimeFrameID = @TimeFrameID)
      AND (@StartDate IS NULL OR b.BarTime >= @ActualStartDate)
      AND (@EndDate IS NULL OR b.BarTime <= @EndDate)
    ORDER BY b.BarTime ASC;
    
    DECLARE @TotalBars INT = @@ROWCOUNT;
    
    PRINT 'Found ' + CAST(@TotalBars AS VARCHAR) + ' bars to recalculate (including history for EMA calculation)';
    
    IF @TotalBars = 0
    BEGIN
        PRINT 'No bars found for recalculation. Exiting.';
        RETURN;
    END
    
    -- –ассчитываем EMA дл€ всех баров (нужно пересчитать последовательно)
    DECLARE @CurrentRow INT = 1;
    DECLARE @ProcessedBars INT = 0;
    
    WHILE @CurrentRow <= @TotalBars
    BEGIN
        -- —оздаем временную таблицу дл€ очередного пакета
        IF OBJECT_ID('tempdb..#BatchBars') IS NOT NULL
            DROP TABLE #BatchBars;
        
        CREATE TABLE #BatchBars (
            BarID BIGINT PRIMARY KEY,
            TickerJID INT NOT NULL,
            TimeFrameID INT NOT NULL,
            BarTime DATETIME NOT NULL
        );
        
        -- Ѕерем следующий пакет баров
        INSERT INTO #BatchBars (BarID, TickerJID, TimeFrameID, BarTime)
        SELECT BarID, TickerJID, TimeFrameID, BarTime
        FROM @BarsToRecalc
        WHERE RowNum >= @CurrentRow 
          AND RowNum < @CurrentRow + @BatchSize;
        
        DECLARE @BatchSizeActual INT = @@ROWCOUNT;
        
        PRINT 'Processing batch of ' + CAST(@BatchSizeActual AS VARCHAR) + ' bars (rows ' + 
              CAST(@CurrentRow AS VARCHAR) + ' to ' + CAST(@CurrentRow + @BatchSizeActual - 1 AS VARCHAR) + ')';
        
        -- –ассчитываем EMA дл€ этого пакета
        DECLARE @AdjustedBatchSize INT = @BatchSizeActual * 2;
        
        EXEC tms.CalculateAllEMAForNewBars 
            @BatchSize = @AdjustedBatchSize, -- ”величиваем batch дл€ захвата всех нужных баров
            @MaxLookbackDays = 500;
        
        SET @ProcessedBars = @ProcessedBars + @BatchSizeActual;
        SET @CurrentRow = @CurrentRow + @BatchSizeActual;
        
        -- ќчищаем временную таблицу
        DROP TABLE #BatchBars;
        
        -- ѕауза между пакетами
        IF @CurrentRow <= @TotalBars
        BEGIN
            PRINT 'Pausing for 1 second...';
            WAITFOR DELAY '00:00:01';
        END
    END
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT '=== EMA recalculation completed ===';
    PRINT 'Deleted records: ' + CAST(@DeletedCount AS VARCHAR);
    PRINT 'Recalculated bars: ' + CAST(@ProcessedBars AS VARCHAR);
    PRINT 'Total duration: ' + CAST(@DurationSeconds AS VARCHAR) + ' seconds';
    PRINT 'Completion time: ' + CONVERT(VARCHAR, @EndTime, 120);
    
    -- ¬озвращаем статистику
    SELECT 
        @DeletedCount AS DeletedRecords,
        @ProcessedBars AS RecalculatedBars,
        @DurationSeconds AS DurationSeconds,
        GETDATE() AS CompletionTime;
END;
GO