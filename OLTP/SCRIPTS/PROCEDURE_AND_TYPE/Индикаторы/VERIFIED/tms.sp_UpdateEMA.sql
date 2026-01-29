use cTrader
go
if OBJECT_ID ('tms.sp_UpdateEMA') is not null drop proc tms.sp_UpdateEMA
go
CREATE PROCEDURE tms.sp_UpdateEMA
    @timeGap INT = NULL,          -- NULL = полный пересчет, число = инкрементальный (минуты)
    @filterTimeframeID INT = NULL,
    @filterTickerJID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowsAffected INT = 0;
	declare @note varchar(max);

	select @note =	case 
						when @timeGap is null then 'Full recalculation'
						else 'last ' + cast(@timeGap as varchar(5)) + ' min recalc'
					end
    
    BEGIN TRY
        -- Если полный пересчет - очищаем таблицу
        IF @timeGap IS NULL
        BEGIN
            TRUNCATE TABLE tms.EMA;
        END
        
        -- MERGE по BarID
        MERGE tms.EMA AS target
        USING (
            SELECT 
                ema.BarID,
                ema.TickerJID, 
                ema.TimeFrameID, 
                ema.BarTime,
                ema.EMA_5_SHORT, 
                ema.EMA_9_MACD_SIGNAL, 
                ema.EMA_12_MACD_FAST,
                ema.EMA_20_SHORT, 
                ema.EMA_26_MACD_SLOW, 
                ema.EMA_50_MEDIUM,
                ema.EMA_100_LONG, 
                ema.EMA_200_LONG, 
                ema.EMA_21_FIBO,
                ema.EMA_55_FIBO, 
                ema.EMA_144_FIBO, 
                ema.EMA_233_FIBO,
                ema.EMA_8_SHORT
            FROM dbo.CalculateAllEMASeriesBatch(@timeGap, @filterTimeframeID, @filterTickerJID) ema
        ) AS source
        ON target.BarID = source.BarID  -- MERGE по BarID
        
        WHEN MATCHED THEN
            UPDATE SET 
                TickerJID = source.TickerJID,
                TimeFrameID = source.TimeFrameID,
                BarTime = source.BarTime,
                EMA_5_SHORT = source.EMA_5_SHORT,
                EMA_9_MACD_SIGNAL = source.EMA_9_MACD_SIGNAL,
                EMA_12_MACD_FAST = source.EMA_12_MACD_FAST,
                EMA_20_SHORT = source.EMA_20_SHORT,
                EMA_26_MACD_SLOW = source.EMA_26_MACD_SLOW,
                EMA_50_MEDIUM = source.EMA_50_MEDIUM,
                EMA_100_LONG = source.EMA_100_LONG,
                EMA_200_LONG = source.EMA_200_LONG,
                EMA_21_FIBO = source.EMA_21_FIBO,
                EMA_55_FIBO = source.EMA_55_FIBO,
                EMA_144_FIBO = source.EMA_144_FIBO,
                EMA_233_FIBO = source.EMA_233_FIBO,
                EMA_8_SHORT = source.EMA_8_SHORT,
                CreatedDate = GETDATE()
                
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                BarID,
                TickerJID, 
                TimeFrameID, 
                BarTime,
                EMA_5_SHORT, 
                EMA_9_MACD_SIGNAL, 
                EMA_12_MACD_FAST,
                EMA_20_SHORT, 
                EMA_26_MACD_SLOW, 
                EMA_50_MEDIUM,
                EMA_100_LONG, 
                EMA_200_LONG, 
                EMA_21_FIBO,
                EMA_55_FIBO, 
                EMA_144_FIBO, 
                EMA_233_FIBO,
                EMA_8_SHORT, 
                CreatedDate
            )
            VALUES (
                source.BarID,
                source.TickerJID, 
                source.TimeFrameID, 
                source.BarTime,
                source.EMA_5_SHORT, 
                source.EMA_9_MACD_SIGNAL, 
                source.EMA_12_MACD_FAST,
                source.EMA_20_SHORT, 
                source.EMA_26_MACD_SLOW, 
                source.EMA_50_MEDIUM,
                source.EMA_100_LONG, 
                source.EMA_200_LONG, 
                source.EMA_21_FIBO,
                source.EMA_55_FIBO, 
                source.EMA_144_FIBO, 
                source.EMA_233_FIBO,
                source.EMA_8_SHORT, 
                GETDATE()
            );
        
        SET @RowsAffected = @@ROWCOUNT;

        -- Логируем выполнение
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, Status)
        VALUES ('EMA Update', 'tms.sp_UpdateEMA', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @note);
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, ErrorMessage, Status)
        VALUES ('EMA Update ERROR', 'tms.sp_UpdateEMA', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @ErrorMessage, 'Error');
        
        THROW;
    END CATCH
END;
GO

EXEC tms.sp_UpdateEMA @timeGap = 120
select top 10 * from tms.logsJob_processIndicators order by 1 desc