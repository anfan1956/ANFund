use cTrader
go


--D:\TradingSystems\OLTP\OLTP\PROCEDURE_AND_TYPE\Индикаторы\tms.sp_RecalculateAllMomentumIndicators.sql


CREATE OR ALTER PROCEDURE tms.sp_RecalculateAllMomentumIndicators
    @TickerJIDs VARCHAR(MAX) = NULL,  -- '1,2,3' или NULL = все
    @TimeFrameIDs VARCHAR(MAX) = NULL, -- '1,5,15' или NULL = все
    @TimeGap INT = NULL  -- NULL = все данные, N = минут от UTC
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
	DECLARE @lastBarTime datetime = (select max(bartime) from tms.bars);
    DECLARE @CutoffTimeUTC DATETIME  = '1900-01-01';
        if  @TimeGap IS not NULL  -- Все данные
            SELECT @CutoffTimeUTC =  DATEADD(MINUTE, -@TimeGap,  @lastBarTime);
		
		--select max(bartime) from tms.bars;   
		--select @CutoffTimeUTC;
    
	DECLARE @Messages NVARCHAR(MAX) = '';
    
    SET @Messages = @Messages + '========================================' + CHAR(10);
    SET @Messages = @Messages + 'RECALCULATION OF MOMENTUM INDICATORS' + CHAR(10);
    SET @Messages = @Messages + 'Start Time (Local): ' + CONVERT(VARCHAR, @StartTime, 120) + CHAR(10);
    SET @Messages = @Messages + 'Batch ID: ' + CAST(@BatchID AS VARCHAR(36)) + CHAR(10);
    SET @Messages = @Messages + 'TimeGap: ' + ISNULL(CAST(@TimeGap AS VARCHAR), 'ALL') + ' hours' + CHAR(10);
    SET @Messages = @Messages + 'Cutoff (UTC): ' + CONVERT(VARCHAR, @CutoffTimeUTC, 120) + CHAR(10);
    
    -- Парсим строки в таблицы
    DECLARE @TickerTable TABLE (TickerJID INT PRIMARY KEY);
    DECLARE @TimeFrameTable TABLE (TimeFrameID INT PRIMARY KEY);
    
    IF @TickerJIDs IS NOT NULL
        INSERT INTO @TickerTable
        SELECT Value FROM STRING_SPLIT(@TickerJIDs, ',');
    
    IF @TimeFrameIDs IS NOT NULL
        INSERT INTO @TimeFrameTable
        SELECT Value FROM STRING_SPLIT(@TimeFrameIDs, ',');
    
    SET @Messages = @Messages + 'Tickers: ' + ISNULL(@TickerJIDs, 'ALL') + CHAR(10);
    SET @Messages = @Messages + 'TimeFrames: ' + ISNULL(@TimeFrameIDs, 'ALL') + CHAR(10);
    SET @Messages = @Messages + '========================================' + CHAR(10);
    
    SET @Messages = @Messages + CHAR(10) + 'Calculating indicators...' + CHAR(10);
    
    WITH PriceData AS (
        SELECT 
            b.TickerJID,
            b.TimeFrameID,
            b.BarTime,
            b.SourceID,
            b.CloseValue,
            b.HighValue,
            b.LowValue,
            CASE WHEN b.CloseValue > LAG(b.CloseValue) OVER (
                    PARTITION BY b.TickerJID, b.TimeFrameID ORDER BY b.BarTime)
                 THEN b.CloseValue - LAG(b.CloseValue) OVER (
                    PARTITION BY b.TickerJID, b.TimeFrameID ORDER BY b.BarTime)
                 ELSE 0 END as Gain,
            CASE WHEN b.CloseValue < LAG(b.CloseValue) OVER (
                    PARTITION BY b.TickerJID, b.TimeFrameID ORDER BY b.BarTime)
                 THEN LAG(b.CloseValue) OVER (
                    PARTITION BY b.TickerJID, b.TimeFrameID ORDER BY b.BarTime) - b.CloseValue
                 ELSE 0 END as Loss,
            MIN(b.LowValue) OVER (
                PARTITION BY b.TickerJID, b.TimeFrameID 
                ORDER BY b.BarTime 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ) as LowestLow14,
            MAX(b.HighValue) OVER (
                PARTITION BY b.TickerJID, b.TimeFrameID 
                ORDER BY b.BarTime 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ) as HighestHigh14,
            LAG(b.CloseValue, 7) OVER (
                PARTITION BY b.TickerJID, b.TimeFrameID 
                ORDER BY b.BarTime
            ) as Close_7_Ago,
            LAG(b.CloseValue, 14) OVER (
                PARTITION BY b.TickerJID, b.TimeFrameID 
                ORDER BY b.BarTime
            ) as Close_14_Ago
        FROM tms.Bars b
        WHERE b.BarTime >= @CutoffTimeUTC
          AND (@TickerJIDs IS NULL OR EXISTS (SELECT 1 FROM @TickerTable WHERE TickerJID = b.TickerJID))
          AND (@TimeFrameIDs IS NULL OR EXISTS (SELECT 1 FROM @TimeFrameTable WHERE TimeFrameID = b.TimeFrameID))
    ),
    RSI_Calculations AS (
        SELECT 
            TickerJID,
            TimeFrameID,
            BarTime,
            SourceID,
            CloseValue,
            CASE WHEN AVG(Loss) OVER (
                    PARTITION BY TickerJID, TimeFrameID 
                    ORDER BY BarTime ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) > 0
                 THEN 100 - (100 / (1 + 
                    (AVG(Gain) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) 
                     / AVG(Loss) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 13 PRECEDING AND CURRENT ROW))))
                 ELSE 100 END as RSI_14_Calc,
            CASE WHEN AVG(Loss) OVER (
                    PARTITION BY TickerJID, TimeFrameID 
                    ORDER BY BarTime ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) > 0
                 THEN 100 - (100 / (1 + 
                    (AVG(Gain) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) 
                     / AVG(Loss) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))))
                 ELSE 100 END as RSI_7_Calc,
            CASE WHEN AVG(Loss) OVER (
                    PARTITION BY TickerJID, TimeFrameID 
                    ORDER BY BarTime ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) > 0
                 THEN 100 - (100 / (1 + 
                    (AVG(Gain) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) 
                     / AVG(Loss) OVER (
                        PARTITION BY TickerJID, TimeFrameID 
                        ORDER BY BarTime ROWS BETWEEN 20 PRECEDING AND CURRENT ROW))))
                 ELSE 100 END as RSI_21_Calc,
            CASE WHEN HighestHigh14 - LowestLow14 > 0 
                 THEN ((CloseValue - LowestLow14) / NULLIF(HighestHigh14 - LowestLow14, 0)) * 100
                 ELSE 50 END as Stoch_K_Calc,
            CASE WHEN Close_14_Ago IS NOT NULL AND Close_14_Ago > 0 
                 THEN ((CloseValue / NULLIF(Close_14_Ago, 0)) - 1) * 100 
                 ELSE NULL END as ROC_14_Calc,
            CASE WHEN Close_7_Ago IS NOT NULL AND Close_7_Ago > 0 
                 THEN ((CloseValue / NULLIF(Close_7_Ago, 0)) - 1) * 100 
                 ELSE NULL END as ROC_7_Calc
        FROM PriceData
    ),
    AllIndicators AS (
        SELECT 
            TickerJID,
            TimeFrameID,
            BarTime,
            SourceID,
            RSI_14_Calc,
            RSI_7_Calc,
            RSI_21_Calc,
            (RSI_14_Calc - AVG(RSI_14_Calc) OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY BarTime ROWS BETWEEN 19 PRECEDING AND CURRENT ROW))
            / NULLIF(STDEV(RSI_14_Calc) OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY BarTime ROWS BETWEEN 19 PRECEDING AND CURRENT ROW), 0) as RSI_ZScore_Calc,
            PERCENT_RANK() OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY RSI_14_Calc) as RSI_Percentile_Calc,
            RSI_14_Calc - LAG(RSI_14_Calc, 5) OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY BarTime) as RSI_Slope_5_Calc,
            Stoch_K_Calc,
            AVG(Stoch_K_Calc) OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY BarTime ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as Stoch_D_Calc,
            Stoch_K_Calc - LAG(Stoch_K_Calc, 3) OVER (
                PARTITION BY TickerJID, TimeFrameID 
                ORDER BY BarTime) as Stoch_Slope_Calc,
            ROC_14_Calc,
            ROC_7_Calc,
            ((RSI_14_Calc / 100) * 0.3 + 
             (Stoch_K_Calc / 100) * 0.3 + 
             (CASE 
                WHEN ROC_14_Calc > 100 THEN 1.0
                WHEN ROC_14_Calc < -100 THEN 0.0
                ELSE (ROC_14_Calc + 100) / 200 
              END) * 0.4) * 100 as Momentum_Score_Calc,
            CASE WHEN RSI_14_Calc > 70 THEN 1 ELSE 0 END as Overbought_Flag_Calc,
            CASE WHEN RSI_14_Calc < 30 THEN 1 ELSE 0 END as Oversold_Flag_Calc
        FROM RSI_Calculations
    ),
    CTE AS (
        SELECT 
            TickerJID,
            TimeFrameID,
            BarTime,
            SourceID,
            RSI_14_Calc,
            RSI_7_Calc,
            RSI_21_Calc,
            RSI_ZScore_Calc,
            RSI_Percentile_Calc,
            RSI_Slope_5_Calc,
            Stoch_K_Calc,
            Stoch_D_Calc,
            Stoch_Slope_Calc,
            ROC_14_Calc,
            ROC_7_Calc,
            Momentum_Score_Calc,
            Overbought_Flag_Calc,
            Oversold_Flag_Calc,
            @BatchID as BatchID_Calc,
            DATEDIFF(MILLISECOND, @StartTime, GETDATE()) as CalculationTimeMS_Calc,
            GETDATE() as ModifiedDate_Calc,
            @StartTime as CreatedDate_Calc
        FROM AllIndicators
    )
    MERGE tms.Indicators_Momentum AS t
    USING CTE AS s ON t.TickerJID = s.TickerJID
        AND t.TimeFrameID = s.TimeFrameID
        AND t.BarTime = s.BarTime
        AND t.SourceID = s.SourceID
    
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            TickerJID, TimeFrameID, BarTime, SourceID,
            RSI_14, RSI_7, RSI_21, RSI_ZScore, RSI_Percentile, RSI_Slope_5,
            Stoch_K_14, Stoch_D_14, Stoch_Slope,
            ROC_14, ROC_7, Momentum_Score,
            Overbought_Flag, Oversold_Flag,
            BatchID, CalculationTimeMS, CreatedDate, ModifiedDate
        ) VALUES (
            s.TickerJID, s.TimeFrameID, s.BarTime, s.SourceID,
            s.RSI_14_Calc, s.RSI_7_Calc, s.RSI_21_Calc, s.RSI_ZScore_Calc, s.RSI_Percentile_Calc, s.RSI_Slope_5_Calc,
            s.Stoch_K_Calc, s.Stoch_D_Calc, s.Stoch_Slope_Calc,
            s.ROC_14_Calc, s.ROC_7_Calc, s.Momentum_Score_Calc,
            s.Overbought_Flag_Calc, s.Oversold_Flag_Calc,
            s.BatchID_Calc, s.CalculationTimeMS_Calc, s.CreatedDate_Calc, s.ModifiedDate_Calc
        )
    
    WHEN MATCHED THEN
        UPDATE SET
            t.RSI_14 = s.RSI_14_Calc,
            t.RSI_7 = s.RSI_7_Calc,
            t.RSI_21 = s.RSI_21_Calc,
            t.RSI_ZScore = s.RSI_ZScore_Calc,
            t.RSI_Percentile = s.RSI_Percentile_Calc,
            t.RSI_Slope_5 = s.RSI_Slope_5_Calc,
            t.Stoch_K_14 = s.Stoch_K_Calc,
            t.Stoch_D_14 = s.Stoch_D_Calc,
            t.Stoch_Slope = s.Stoch_Slope_Calc,
            t.ROC_14 = s.ROC_14_Calc,
            t.ROC_7 = s.ROC_7_Calc,
            t.Momentum_Score = s.Momentum_Score_Calc,
            t.Overbought_Flag = s.Overbought_Flag_Calc,
            t.Oversold_Flag = s.Oversold_Flag_Calc,
            t.BatchID = s.BatchID_Calc,
            t.CalculationTimeMS = s.CalculationTimeMS_Calc,
            t.ModifiedDate = s.ModifiedDate_Calc;
    
    SET @Messages = @Messages + 'MERGE completed: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows affected' + CHAR(10);
    
    SET @Messages = @Messages + CHAR(10) + '========================================' + CHAR(10);
    SET @Messages = @Messages + 'RECALCULATION COMPLETE' + CHAR(10);
    SET @Messages = @Messages + 'Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR) + ' seconds' + CHAR(10);
    SET @Messages = @Messages + '========================================';
    
    PRINT @Messages;
END;
GO

declare @timeGap int =10;
exec tms.sp_RecalculateAllMomentumIndicators  @timeGap = @timeGap

/*


-- Проверяем что все индикаторы заполнены
SELECT 
    COUNT(*) as TotalRows,
    COUNT(CASE WHEN RSI_14 IS NULL THEN 1 END) as Null_RSI_14,
    COUNT(CASE WHEN Stoch_K_14 IS NULL THEN 1 END) as Null_Stoch_K_14,
    COUNT(CASE WHEN ROC_14 IS NULL THEN 1 END) as Null_ROC_14,
    COUNT(CASE WHEN Momentum_Score IS NULL THEN 1 END) as Null_Momentum_Score
FROM tms.Indicators_Momentum;

-- Проверяем последние 5 записей
SELECT TOP 5 
    BarTime,
    RSI_14,
    Stoch_K_14,
    ROC_14,
    Momentum_Score,
    Overbought_Flag,
    Oversold_Flag
FROM tms.Indicators_Momentum 
ORDER BY BarTime DESC;


select max(bartime) from tms.bars
*/