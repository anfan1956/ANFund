USE [cTrader]
GO

if OBJECT_ID('tms.sp_UpdateIndicatorsMomentum') is not null drop proc tms.sp_UpdateIndicatorsMomentum
go
CREATE PROCEDURE tms.sp_UpdateIndicatorsMomentum
    @timeGap INT = NULL,
    @filterTimeframeID INT = NULL,
    @filterTickerJID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RowsAffected INT = 0;
	declare @note varchar (max);

	select @note =	case 
						when @timeGap is null then 'Full recalculation'
						else 'last ' + cast(@timeGap as varchar(5)) + ' min recalc'
					end
    
    BEGIN TRY
        IF @timeGap IS NULL
        BEGIN
            TRUNCATE TABLE tms.Indicators_Momentum;
        END
        
        MERGE tms.Indicators_Momentum AS target
        USING (
            SELECT 
                m.BarID,
                m.TickerJID, 
                m.TimeFrameID, 
                m.BarTime,
                m.RSI_14,
                m.RSI_7,
                m.RSI_21,
                m.RSI_ZScore,
                m.RSI_Percentile,
                m.RSI_Slope_5,
                m.Stoch_K_14,
                m.Stoch_D_14,
                m.Stoch_Slope,
                m.ROC_14,
                m.ROC_7,
                m.Momentum_Score,
                m.Overbought_Flag,
                m.Oversold_Flag
            FROM dbo.CalculateAllMomentumBatch(@timeGap, @filterTimeframeID, @filterTickerJID) m
        ) AS source
        ON target.ID = source.BarID
        
        WHEN MATCHED THEN
            UPDATE SET 
                RSI_14 = source.RSI_14,
                RSI_7 = source.RSI_7,
                RSI_21 = source.RSI_21,
                RSI_ZScore = source.RSI_ZScore,
                RSI_Percentile = source.RSI_Percentile,
                RSI_Slope_5 = source.RSI_Slope_5,
                Stoch_K_14 = source.Stoch_K_14,
                Stoch_D_14 = source.Stoch_D_14,
                Stoch_Slope = source.Stoch_Slope,
                ROC_14 = source.ROC_14,
                ROC_7 = source.ROC_7,
                Momentum_Score = source.Momentum_Score,
                Overbought_Flag = source.Overbought_Flag,
                Oversold_Flag = source.Oversold_Flag,
                ModifiedDate = GETDATE()
                
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                ID,
                TickerJID, 
                TimeFrameID, 
                BarTime,
                RSI_14,
                RSI_7,
                RSI_21,
                RSI_ZScore,
                RSI_Percentile,
                RSI_Slope_5,
                Stoch_K_14,
                Stoch_D_14,
                Stoch_Slope,
                ROC_14,
                ROC_7,
                Momentum_Score,
                Overbought_Flag,
                Oversold_Flag,
                CreatedDate
            )
            VALUES (
                source.BarID,
                source.TickerJID, 
                source.TimeFrameID, 
                source.BarTime,
                source.RSI_14,
                source.RSI_7,
                source.RSI_21,
                source.RSI_ZScore,
                source.RSI_Percentile,
                source.RSI_Slope_5,
                source.Stoch_K_14,
                source.Stoch_D_14,
                source.Stoch_Slope,
                source.ROC_14,
                source.ROC_7,
                source.Momentum_Score,
                source.Overbought_Flag,
                source.Oversold_Flag,
                GETDATE()
            );
        
        SET @RowsAffected = @@ROWCOUNT;

        -- Логируем выполнение
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, Status)
        VALUES ('Momentum Indicators Update', 'tms.sp_UpdateIndicatorsMomentum', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @note);

            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, ErrorMessage, Status)
        VALUES ('Momentum Indicators Update', 'tms.sp_UpdateIndicatorsMomentum', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @ErrorMessage, 'Error');
        

        THROW;
    END CATCH
END;
GO

declare @start datetime = getdate();
EXEC tms.sp_UpdateIndicatorsMomentum @timeGap = 120;
select DATEDIFF(MILLISECOND,@start, GETDATE());








