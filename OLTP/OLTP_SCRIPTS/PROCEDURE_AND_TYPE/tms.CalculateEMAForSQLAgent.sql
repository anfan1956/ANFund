USE [cTrader]
GO

-- =============================================
-- Author: AI Assistant
-- Create date: 2024
-- Description: Упрощенная процедура для запуска расчета EMA из SQL Agent
-- =============================================
CREATE OR ALTER PROCEDURE tms.CalculateEMAForSQLAgent
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MaxBarsPerRun INT = 1000;
    
    PRINT '=== Starting EMA calculation for SQL Agent ===';
    PRINT 'Current time: ' + CONVERT(VARCHAR, GETDATE(), 120);
    
    -- Выполняем расчет в несколько проходов
    DECLARE @BarsProcessed INT = 1;
    DECLARE @TotalProcessed INT = 0;
    DECLARE @RunCount INT = 0;
    DECLARE @MaxRuns INT = 8;
    
    WHILE @BarsProcessed > 0 AND @RunCount < @MaxRuns
    BEGIN
        SET @RunCount = @RunCount + 1;
        
        PRINT '--- Run ' + CAST(@RunCount AS VARCHAR) + ' ---';
        
        -- Вызываем основную процедуру
        EXEC tms.CalculateAllEMAForNewBars 
            @BatchSize = @MaxBarsPerRun,
            @MaxLookbackDays = 2;
        
        -- Получаем количество обработанных баров
        SET @BarsProcessed = @@ROWCOUNT;
        
        SET @TotalProcessed = @TotalProcessed + @BarsProcessed;
        
        IF @BarsProcessed > 0
        BEGIN
            PRINT 'Run ' + CAST(@RunCount AS VARCHAR) + 
                  ': Processed ' + CAST(@BarsProcessed AS VARCHAR) + ' bars';
            
            -- Небольшая пауза между запусками для снижения нагрузки
            --IF @RunCount < @MaxRuns
            --BEGIN
            --    PRINT 'Pausing for 2 seconds...';
            --    WAITFOR DELAY '00:00:02';
            --END
        END
        ELSE
        BEGIN
            PRINT 'Run ' + CAST(@RunCount AS VARCHAR) + ': No bars to process';
        END
    END
    
    PRINT '=== EMA calculation completed ===';
    PRINT 'Total runs: ' + CAST(@RunCount AS VARCHAR);
    PRINT 'Total bars processed: ' + CAST(@TotalProcessed AS VARCHAR);
    PRINT 'Completion time: ' + CONVERT(VARCHAR, GETDATE(), 120);
    
    -- Возвращаем статистику для мониторинга
    SELECT 
        @TotalProcessed AS TotalBarsProcessed,
        @RunCount AS RunCount,
        GETDATE() AS CompletionTime,
        CASE 
            WHEN @TotalProcessed > 0 THEN 'SUCCESS' 
            ELSE 'NO_DATA' 
        END AS Status;
END;
GO