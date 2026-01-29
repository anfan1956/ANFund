USE msdb;
GO

-- Удалить если существует
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Full Recalculation of All Indicators')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Full Recalculation of All Indicators', @delete_unused_schedule = 1;

-- Создать джобу
DECLARE @jobId BINARY(16);

EXEC msdb.dbo.sp_add_job
    @job_name = N'Full Recalculation of All Indicators',
    @enabled = 1,
    @description = N'Daily full recalculation of all indicators at 22:00 UTC',
    @owner_login_name = N'sa',
    @job_id = @jobId OUTPUT;

-- Шаг
EXEC msdb.dbo.sp_add_jobstep
    @job_id = @jobId,
    @step_name = N'Recalculation All Indicators',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
USE [cTrader]
SET NOCOUNT ON;

DECLARE @StartTime DATETIME = GETDATE();
DECLARE @JobRunID UNIQUEIDENTIFIER = NEWID();

BEGIN TRY
    INSERT INTO tms.logsJob_FullRecalculation (JobRunID, StepName, TableName, Status)
    VALUES (@JobRunID, ''Job Started'', ''All Tables'', ''STARTED'');
    
    -- 1. EMA daily
    DECLARE @timeGap int = NULL
    EXEC tms.sp_UpdateEMA @timeGap = @timeGap; 

    
    -- 2. MA
    DECLARE @MAStartTime DATETIME = GETDATE();
    EXEC tms.sp_UpdateMA @timeGap = NULL, @filterTimeframeID = NULL, @filterTickerJID = NULL;
    INSERT INTO tms.logsJob_FullRecalculation (JobRunID, StepName, TableName, DurationMs, Status)
    VALUES (@JobRunID, ''MA Recalculation'', ''tms.MA'', DATEDIFF(MILLISECOND, @MAStartTime, GETDATE()), ''COMPLETED'');
    
    -- Momentum (ПРАВИЛЬНЫЕ ПАРАМЕТРЫ)
        EXEC tms.sp_UpdateMomentumIndicators @TimeGap = NULL;
		/*
        @TickerJIDs = NULL,     -- Все тикеры
        @TimeFrameIDs = NULL,   -- Все таймфреймы
        @TimeGap = NULL;        -- Полный пересчет
		*/
    
    INSERT INTO tms.logsJob_FullRecalculation (JobRunID, StepName, TableName, DurationMs, Status)
    VALUES (@JobRunID, ''Momentum Recalculation'', ''tms.Indicators_Momentum'', DATEDIFF(MILLISECOND, @MomentumStartTime, GETDATE()), ''COMPLETED'');
    
    INSERT INTO tms.logsJob_FullRecalculation (JobRunID, StepName, TableName, Status)
    VALUES (@JobRunID, ''Job Completed'', ''All Tables'', ''COMPLETED'');
    
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO tms.logsJob_FullRecalculation (JobRunID, StepName, TableName, Status, ErrorMessage)
    VALUES (@JobRunID, ''Job Failed'', ''All Tables'', ''ERROR'', @ErrorMessage);
    THROW;
END CATCH',
    @database_name = N'cTrader';

-- Расписание на 22:00 UTC
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Daily_22_00_UTC',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 220000;

EXEC msdb.dbo.sp_attach_schedule @job_id = @jobId, @schedule_name = N'Daily_22_00_UTC';

-- Назначить серверу
EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';

PRINT 'Джоба создана с расписанием на 22:00 UTC ежедневно.';

USE msdb;
GO

SELECT 
    j.name AS JobName,
    j.enabled AS JobEnabled,
    s.name AS ScheduleName,
    s.enabled AS ScheduleEnabled,
    s.freq_type,
    CASE s.freq_type
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        ELSE 'Other'
    END AS Frequency,
    s.freq_interval,
    CONVERT(TIME, STUFF(STUFF(RIGHT('000000' + CAST(s.active_start_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')) AS StartTime
FROM sysjobs j
JOIN sysjobschedules js ON j.job_id = js.job_id
JOIN sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name = N'Full Recalculation of All Indicators';