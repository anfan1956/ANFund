use cTrader
go

if OBJECT_ID ('tms.sp_UpdateMA') is not null drop proc tms.sp_UpdateMA
go

CREATE PROC tms.sp_UpdateMA
    @timeGap INT = NULL,
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
        IF @timeGap IS NULL
        BEGIN
            TRUNCATE TABLE tms.MA;
        END
        
        MERGE tms.MA AS target
        USING (
            SELECT 
                m.BarID,
                m.TickerJID, 
                m.TimeFrameID, 
                m.BarTime,
                m.MA5,
                m.MA8,
                m.MA20,
                m.MA30,
                m.MA50,
                m.MA100,
                m.MA200,
                m.MA500,
                m.MA21_FIB,
                m.MA55_FIB,
                m.MA144_FIB,
                m.MA233_FIB,
                m.MA195_NYSE,
                m.MA390_NYSE
            FROM dbo.CalculateAllMASeriesBatch(@timeGap, @filterTimeframeID, @filterTickerJID) m
        ) AS source
        ON target.ID = source.BarID  -- ID в таблице = BarID из функции
        
        WHEN MATCHED THEN
            UPDATE SET 
                TickerJID = source.TickerJID,
                TimeFrameID = source.TimeFrameID,
                BarTime = source.BarTime,
                MA5 = source.MA5,
                MA8 = source.MA8,
                MA20 = source.MA20,
                MA30 = source.MA30,
                MA50 = source.MA50,
                MA100 = source.MA100,
                MA200 = source.MA200,
                MA500 = source.MA500,
                MA21_FIB = source.MA21_FIB,
                MA55_FIB = source.MA55_FIB,
                MA144_FIB = source.MA144_FIB,
                MA233_FIB = source.MA233_FIB,
                MA195_NYSE = source.MA195_NYSE,
                MA390_NYSE = source.MA390_NYSE,
                CreatedDate = GETDATE()
                
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                ID,  -- BarID (но колонка называется ID)
                TickerJID, 
                TimeFrameID, 
                BarTime,
                MA5,
                MA8,
                MA20,
                MA30,
                MA50,
                MA100,
                MA200,
                MA500,
                MA21_FIB,
                MA55_FIB,
                MA144_FIB,
                MA233_FIB,
                MA195_NYSE,
                MA390_NYSE,
                CreatedDate
            )
            VALUES (
                source.BarID,
                source.TickerJID, 
                source.TimeFrameID, 
                source.BarTime,
                source.MA5,
                source.MA8,
                source.MA20,
                source.MA30,
                source.MA50,
                source.MA100,
                source.MA200,
                source.MA500,
                source.MA21_FIB,
                source.MA55_FIB,
                source.MA144_FIB,
                source.MA233_FIB,
                source.MA195_NYSE,
                source.MA390_NYSE,
                GETDATE()
            );
        
        SET @RowsAffected = @@ROWCOUNT;

		        -- Логируем выполнение
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, Status)
        VALUES ('MA Update', 'tms.sp_UpdateMA', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @note);


            
    END TRY
    BEGIN CATCH
	        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        
        INSERT INTO tms.logsJob_processIndicators (StepName, ProcedureName, RowsProcessed, DurationMs, ErrorMessage, Status)
        VALUES ('MA Update ERROR', 'tms.sp_UpdateMA', @RowsAffected, DATEDIFF(MILLISECOND, @StartTime, GETDATE()), @ErrorMessage, 'Error');
     
        THROW;
    END CATCH
END;
GO

declare @timeGap int = null;
EXEC tms.sp_UpdateMA @timeGap = @timeGap;
select * from tms.logsJob_processIndicators order by 1 desc;
