USE [msdb]
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'processIndicators')
    EXEC msdb.dbo.sp_delete_job @job_name = N'processIndicators', @delete_unused_schedule = 1;
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job 
    @job_name = N'processIndicators', 
    @enabled = 1, 
    @owner_login_name = N'sa',
    @description = N'Runs every minute to calculate indicators on 1-minute bars.
Procedures:
1. tms.sp_CalculateMAs - moving averages calculation (tested)
2. tms.CalculateEMAForSQLAgent - EMA calculation  
3. tms.sp_RecalculateAllMomentumIndicators - Momentum calculation',
@job_id = @jobId OUTPUT;

IF @@ERROR <> 0 OR @ReturnCode <> 0 GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep 
    @job_id = @jobId, 
    @step_name = N'Calculate Indicators', 
    @step_id = 1,
    @subsystem = N'TSQL', 
    @command = N'
USE [cTrader]
SET NOCOUNT ON;

DECLARE @RowsMA INT, @RowsEMA INT, @RowsMomentum INT;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @timeGap int = 120 -- default parameter for 1 min,


	-- 1. EMA  логируем внутри процедуры
    EXEC tms.sp_UpdateEMA @timeGap = @timeGap; 

	-- 2. MA , логируем внутри процедуры
	EXEC tms.sp_UpdateMA @timeGap = @timeGap;

	-- 3. Momentum (каждую минуту)
	SET @StartTime = GETDATE();
		EXEC tms.sp_UpdateIndicatorsMomentum @timeGap = @timeGap;
		

		
', 
    @database_name = N'cTrader';

IF @@ERROR <> 0 OR @ReturnCode <> 0 GOTO QuitWithRollback;

-- ИЗМЕНЕНО: Каждые 15 секунд (вместо 60)
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule 
    @job_id = @jobId, 
    @name = N'Every 15 Seconds', 
    @enabled = 1, 
    @freq_type = 4, -- Daily
    @freq_interval = 1, -- Every day
    @freq_subday_type = 2, -- Seconds
    @freq_subday_interval = 15; -- ИЗМЕНЕНО: было 1 минута, стало 15 секунд

IF @@ERROR <> 0 OR @ReturnCode <> 0 GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';

IF @@ERROR <> 0 OR @ReturnCode <> 0 GOTO QuitWithRollback;

COMMIT TRANSACTION;
PRINT 'Job processIndicators created (runs every minute)';
GOTO EndSave;

QuitWithRollback:
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Job creation failed';

EndSave:
GO

/*
EXEC msdb.dbo.sp_stop_job N'processIndicators' 
EXEC msdb.dbo.sp_start_job N'processIndicators'
*/