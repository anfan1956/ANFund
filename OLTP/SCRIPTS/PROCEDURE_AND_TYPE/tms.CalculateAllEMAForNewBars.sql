USE [cTrader]
GO

-- =============================================
-- Author: AI Assistant
-- Create date: 2024
-- Description: Основная процедура расчета всех экспоненциальных скользящих средних (EMA)
--D:\TradingSystems\OLTP\OLTP\PROCEDURE_AND_TYPE\tms.CalculateAllEMAForNewBars.sql

-- =============================================
CREATE OR ALTER PROCEDURE tms.CalculateAllEMAForNewBars
    @BatchSize INT = 50000,
    @MaxLookbackDays INT = 5000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProcessedCount INT = 0;
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT 'Starting EMA calculation process at: ' + CONVERT(VARCHAR, @StartTime, 120);
    
    -- Создаем временную таблицу для хранения новых/обновляемых баров
    IF OBJECT_ID('tempdb..#BarsToProcess') IS NOT NULL
        DROP TABLE #BarsToProcess;
    
    CREATE TABLE #BarsToProcess (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        BarID BIGINT NOT NULL,
        TickerJID INT NOT NULL,
        TimeFrameID INT NOT NULL,
        BarTime DATETIME NOT NULL,
        CloseValue DECIMAL(18,8) NULL,
        INDEX IX_Temp_BarsToProcess_Group (TickerJID, TimeFrameID, BarTime)
    );
    
    -- Получаем бары, которые нужно обработать
    INSERT INTO #BarsToProcess (BarID, TickerJID, TimeFrameID, BarTime, CloseValue)
    SELECT TOP (@BatchSize)
        b.ID,
        b.TickerJID,
        b.TimeFrameID,
        b.BarTime,
        b.CloseValue
    FROM tms.Bars b
    WHERE 
        -- Бара нет в таблице EMA
        NOT EXISTS (
            SELECT 1 
            FROM tms.EMA m 
            WHERE m.BarID = b.ID
        )
        -- Или у бара есть EMA, но они не рассчитаны (NULL)
        OR EXISTS (
            SELECT 1 
            FROM tms.EMA m 
            WHERE m.BarID = b.ID 
            AND (m.EMA_5_SHORT IS NULL OR m.EMA_20_SHORT IS NULL)
        )
    ORDER BY b.BarTime ASC;
    
    SELECT @ProcessedCount = COUNT(*) FROM #BarsToProcess;
    
    PRINT 'Found ' + CAST(@ProcessedCount AS VARCHAR) + ' bars to process';
    
    IF @ProcessedCount = 0
    BEGIN
        PRINT 'No bars to process. Exiting.';
        RETURN;
    END
    
    -- Создаем временную таблицу для расчета EMA
    IF OBJECT_ID('tempdb..#EMACalculations') IS NOT NULL
        DROP TABLE #EMACalculations;
    
    CREATE TABLE #EMACalculations (
        BarID BIGINT PRIMARY KEY,
        TickerJID INT NOT NULL,
        TimeFrameID INT NOT NULL,
        BarTime DATETIME NOT NULL,
        CloseValue DECIMAL(18,8) NULL,
        
        -- Экспоненциальные скользящие средние
        EMA_5_SHORT DECIMAL(18,8) NULL,
        EMA_8_SHORT DECIMAL(18,8) NULL,
        EMA_9_MACD_SIGNAL DECIMAL(18,8) NULL,
        EMA_12_MACD_FAST DECIMAL(18,8) NULL,
        EMA_20_SHORT DECIMAL(18,8) NULL,
        EMA_26_MACD_SLOW DECIMAL(18,8) NULL,
        EMA_50_MEDIUM DECIMAL(18,8) NULL,
        EMA_100_LONG DECIMAL(18,8) NULL,
        EMA_200_LONG DECIMAL(18,8) NULL,
        
        -- EMA на основе чисел Фибоначчи
        EMA_21_FIBO DECIMAL(18,8) NULL,
        EMA_55_FIBO DECIMAL(18,8) NULL,
        EMA_144_FIBO DECIMAL(18,8) NULL,
        EMA_233_FIBO DECIMAL(18,8) NULL,
        
        -- Флаг для вставки/обновления
        OperationType VARCHAR(10) NOT NULL
    );
    
    -- Вставляем бары для расчета
    INSERT INTO #EMACalculations (BarID, TickerJID, TimeFrameID, BarTime, CloseValue, OperationType)
    SELECT 
        bp.BarID,
        bp.TickerJID,
        bp.TimeFrameID,
        bp.BarTime,
        bp.CloseValue,
        CASE WHEN EXISTS (SELECT 1 FROM tms.EMA WHERE BarID = bp.BarID) 
            THEN 'UPDATE' 
            ELSE 'INSERT' 
        END
    FROM #BarsToProcess bp;
    
    -- Рассчитываем EMA для каждого тикера и таймфрейма
    DECLARE @CurrentTickerJID INT;
    DECLARE @CurrentTimeFrameID INT;
    
    DECLARE curTickerTimeFrame CURSOR FOR
    SELECT DISTINCT TickerJID, TimeFrameID
    FROM #BarsToProcess
    ORDER BY TickerJID, TimeFrameID;
    
    OPEN curTickerTimeFrame;
    FETCH NEXT FROM curTickerTimeFrame INTO @CurrentTickerJID, @CurrentTimeFrameID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Calculating EMA for TickerJID=' + CAST(@CurrentTickerJID AS VARCHAR) + 
              ', TimeFrameID=' + CAST(@CurrentTimeFrameID AS VARCHAR);
        
        -- Получаем все бары для этого тикера и таймфрейма (упорядоченные по времени)
        DECLARE @BarsForCalculation TABLE (
            RowNum INT IDENTITY(1,1) PRIMARY KEY,
            BarID BIGINT NOT NULL,
            BarTime DATETIME NOT NULL,
            CloseValue DECIMAL(18,8) NULL
        );
        
        INSERT INTO @BarsForCalculation (BarID, BarTime, CloseValue)
        SELECT BarID, BarTime, CloseValue
        FROM #EMACalculations
        WHERE TickerJID = @CurrentTickerJID 
          AND TimeFrameID = @CurrentTimeFrameID
        ORDER BY BarTime;
        
        -- Переменные для расчета EMA
        DECLARE @CurrentRow INT = 1;
        DECLARE @TotalRows INT;
        DECLARE @CurrentBarID BIGINT;
        DECLARE @CurrentClose DECIMAL(18,8);
        DECLARE @PrevEMA5 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA8 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA9 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA12 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA20 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA26 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA50 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA100 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA200 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA21 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA55 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA144 DECIMAL(18,8) = NULL;
        DECLARE @PrevEMA233 DECIMAL(18,8) = NULL;
        
        SELECT @TotalRows = COUNT(*) FROM @BarsForCalculation;
        
        -- Константы для расчета (коэффициенты сглаживания)
        DECLARE @Alpha5 DECIMAL(18,8) = 2.0 / (5 + 1);
        DECLARE @Alpha8 DECIMAL(18,8) = 2.0 / (5 + 1);
        DECLARE @Alpha9 DECIMAL(18,8) = 2.0 / (9 + 1);
        DECLARE @Alpha12 DECIMAL(18,8) = 2.0 / (12 + 1);
        DECLARE @Alpha20 DECIMAL(18,8) = 2.0 / (20 + 1);
        DECLARE @Alpha26 DECIMAL(18,8) = 2.0 / (26 + 1);
        DECLARE @Alpha50 DECIMAL(18,8) = 2.0 / (50 + 1);
        DECLARE @Alpha100 DECIMAL(18,8) = 2.0 / (100 + 1);
        DECLARE @Alpha200 DECIMAL(18,8) = 2.0 / (200 + 1);
        DECLARE @Alpha21 DECIMAL(18,8) = 2.0 / (21 + 1);
        DECLARE @Alpha55 DECIMAL(18,8) = 2.0 / (55 + 1);
        DECLARE @Alpha144 DECIMAL(18,8) = 2.0 / (144 + 1);
        DECLARE @Alpha233 DECIMAL(18,8) = 2.0 / (233 + 1);
        
        WHILE @CurrentRow <= @TotalRows
        BEGIN
            SELECT 
                @CurrentBarID = BarID,
                @CurrentClose = CloseValue
            FROM @BarsForCalculation
            WHERE RowNum = @CurrentRow;
            
            -- Для первого бара EMA = Close
            IF @CurrentRow = 1
            BEGIN
                SET @PrevEMA5 = @CurrentClose;
                SET @PrevEMA8 = @CurrentClose;
                SET @PrevEMA9 = @CurrentClose;
                SET @PrevEMA12 = @CurrentClose;
                SET @PrevEMA20 = @CurrentClose;
                SET @PrevEMA26 = @CurrentClose;
                SET @PrevEMA50 = @CurrentClose;
                SET @PrevEMA100 = @CurrentClose;
                SET @PrevEMA200 = @CurrentClose;
                SET @PrevEMA21 = @CurrentClose;
                SET @PrevEMA55 = @CurrentClose;
                SET @PrevEMA144 = @CurrentClose;
                SET @PrevEMA233 = @CurrentClose;
            END
            ELSE
            BEGIN
                -- Рассчитываем EMA по формуле: EMA = (Close * Alpha) + (PrevEMA * (1 - Alpha))
                SET @PrevEMA5 = (@CurrentClose * @Alpha5) + (@PrevEMA5 * (1 - @Alpha5));
                SET @PrevEMA8 = (@CurrentClose * @Alpha8) + (@PrevEMA8 * (1 - @Alpha8));
                SET @PrevEMA9 = (@CurrentClose * @Alpha9) + (@PrevEMA9 * (1 - @Alpha9));
                SET @PrevEMA12 = (@CurrentClose * @Alpha12) + (@PrevEMA12 * (1 - @Alpha12));
                SET @PrevEMA20 = (@CurrentClose * @Alpha20) + (@PrevEMA20 * (1 - @Alpha20));
                SET @PrevEMA26 = (@CurrentClose * @Alpha26) + (@PrevEMA26 * (1 - @Alpha26));
                SET @PrevEMA50 = (@CurrentClose * @Alpha50) + (@PrevEMA50 * (1 - @Alpha50));
                SET @PrevEMA100 = (@CurrentClose * @Alpha100) + (@PrevEMA100 * (1 - @Alpha100));
                SET @PrevEMA200 = (@CurrentClose * @Alpha200) + (@PrevEMA200 * (1 - @Alpha200));
                SET @PrevEMA21 = (@CurrentClose * @Alpha21) + (@PrevEMA21 * (1 - @Alpha21));
                SET @PrevEMA55 = (@CurrentClose * @Alpha55) + (@PrevEMA55 * (1 - @Alpha55));
                SET @PrevEMA144 = (@CurrentClose * @Alpha144) + (@PrevEMA144 * (1 - @Alpha144));
                SET @PrevEMA233 = (@CurrentClose * @Alpha233) + (@PrevEMA233 * (1 - @Alpha233));
            END
            
            -- Обновляем временную таблицу с рассчитанными EMA
            UPDATE #EMACalculations
            SET 
                EMA_5_SHORT = @PrevEMA5,
                EMA_8_SHORT = @PrevEMA8,
                EMA_9_MACD_SIGNAL = @PrevEMA9,
                EMA_12_MACD_FAST = @PrevEMA12,
                EMA_20_SHORT = @PrevEMA20,
                EMA_26_MACD_SLOW = @PrevEMA26,
                EMA_50_MEDIUM = @PrevEMA50,
                EMA_100_LONG = @PrevEMA100,
                EMA_200_LONG = @PrevEMA200,
                EMA_21_FIBO = @PrevEMA21,
                EMA_55_FIBO = @PrevEMA55,
                EMA_144_FIBO = @PrevEMA144,
                EMA_233_FIBO = @PrevEMA233
            WHERE BarID = @CurrentBarID;
            
            SET @CurrentRow = @CurrentRow + 1;
            
            -- Выводим прогресс
            IF (@CurrentRow % 100 = 0) OR (@CurrentRow > @TotalRows)
            BEGIN
                PRINT '  Processed ' + CAST(@CurrentRow - 1 AS VARCHAR) + ' of ' + CAST(@TotalRows AS VARCHAR) + ' bars';
            END
        END
        
        FETCH NEXT FROM curTickerTimeFrame INTO @CurrentTickerJID, @CurrentTimeFrameID;
    END
    
    CLOSE curTickerTimeFrame;
    DEALLOCATE curTickerTimeFrame;
    
    -- Обновляем существующие записи в EMA
    UPDATE ema
    SET 
        ema.EMA_5_SHORT = calc.EMA_5_SHORT,
        ema.EMA_8_SHORT = calc.EMA_8_SHORT,
        ema.EMA_9_MACD_SIGNAL = calc.EMA_9_MACD_SIGNAL,
        ema.EMA_12_MACD_FAST = calc.EMA_12_MACD_FAST,
        ema.EMA_20_SHORT = calc.EMA_20_SHORT,
        ema.EMA_26_MACD_SLOW = calc.EMA_26_MACD_SLOW,
        ema.EMA_50_MEDIUM = calc.EMA_50_MEDIUM,
        ema.EMA_100_LONG = calc.EMA_100_LONG,
        ema.EMA_200_LONG = calc.EMA_200_LONG,
        ema.EMA_21_FIBO = calc.EMA_21_FIBO,
        ema.EMA_55_FIBO = calc.EMA_55_FIBO,
        ema.EMA_144_FIBO = calc.EMA_144_FIBO,
        ema.EMA_233_FIBO = calc.EMA_233_FIBO,
        ema.CreatedDate = GETDATE()
    FROM tms.EMA ema
    INNER JOIN #EMACalculations calc ON ema.BarID = calc.BarID
    WHERE calc.OperationType = 'UPDATE';
    
    PRINT 'Updated ' + CAST(@@ROWCOUNT AS VARCHAR) + ' existing records in tms.EMA';
    
    -- Вставляем новые записи в EMA
    INSERT INTO tms.EMA (
        BarID, TickerJID, BarTime, TimeFrameID,
        EMA_5_SHORT, EMA_8_SHORT, EMA_9_MACD_SIGNAL, EMA_12_MACD_FAST, EMA_20_SHORT,
        EMA_26_MACD_SLOW, EMA_50_MEDIUM, EMA_100_LONG, EMA_200_LONG,
        EMA_21_FIBO, EMA_55_FIBO, EMA_144_FIBO, EMA_233_FIBO,
        CreatedDate
    )
    SELECT 
        calc.BarID,
        calc.TickerJID,
        calc.BarTime,
        calc.TimeFrameID,
        calc.EMA_5_SHORT,
        calc.EMA_8_SHORT,
        calc.EMA_9_MACD_SIGNAL,
        calc.EMA_12_MACD_FAST,
        calc.EMA_20_SHORT,
        calc.EMA_26_MACD_SLOW,
        calc.EMA_50_MEDIUM,
        calc.EMA_100_LONG,
        calc.EMA_200_LONG,
        calc.EMA_21_FIBO,
        calc.EMA_55_FIBO,
        calc.EMA_144_FIBO,
        calc.EMA_233_FIBO,
        GETDATE()
    FROM #EMACalculations calc
    WHERE calc.OperationType = 'INSERT'
      AND NOT EXISTS (SELECT 1 FROM tms.EMA e WHERE e.BarID = calc.BarID);
    
    PRINT 'Inserted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' new records into tms.EMA';
    
    -- Очищаем временные таблицы
    DROP TABLE #BarsToProcess;
    DROP TABLE #EMACalculations;
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT 'EMA calculation completed at: ' + CONVERT(VARCHAR, @EndTime, 120);
    PRINT 'Total duration: ' + CAST(@DurationSeconds AS VARCHAR) + ' seconds';
    PRINT 'Total bars processed: ' + CAST(@ProcessedCount AS VARCHAR);
    
    -- Возвращаем статистику
    SELECT 
        @ProcessedCount AS BarsProcessed,
        @DurationSeconds AS DurationSeconds,
        CASE 
            WHEN @DurationSeconds > 0 
            THEN CAST(@ProcessedCount AS FLOAT) / @DurationSeconds 
            ELSE 0 
        END AS BarsPerSecond;
END;
GO

-- Or just for specific ticker/timeframe
--EXEC tms.CalculateAllEMA_Fastest @TickerJID = 4, @TimeFrameID = 1; -- XAUUSD, 1m


tms.CalculateAllEMAForNewBars

select count(*) from tms.EMA
select count(*) as nullCount 
from tms.EMA where EMA_8_SHORT is NULL