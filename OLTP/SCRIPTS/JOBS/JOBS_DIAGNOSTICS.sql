
USE msdb;
GO

--EXEC sp_start_job N'Full Recalculation of All Indicators';

USE [cTrader];
GO
SELECT TOP 10 *
FROM tms.logsJob_FullRecalculation
ORDER BY CreatedDate DESC;


USE msdb;
GO

SELECT 
    j.name AS JobName,
    CASE 
        WHEN ja.start_execution_date IS NULL THEN 'Not Started'
        WHEN ja.stop_execution_date IS NULL THEN 'Running' 
        ELSE 'Completed'
    END AS Status,
    ja.start_execution_date AS StartTime,
    ja.stop_execution_date AS EndTime
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
--WHERE j.name in ( N'Full Recalculation of All Indicators', N'processIndicators')
AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity);



USE msdb;
GO

SELECT 
    j.name AS JobName,
    CASE j.enabled WHEN 1 THEN 'Enabled' ELSE 'Disabled' END AS Status,
    s.name AS ScheduleName,
    s.enabled AS ScheduleEnabled,
    CONVERT(TIME, STUFF(STUFF(RIGHT('000000' + CAST(s.active_start_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')) AS RunTime,
    CASE s.freq_type
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly' 
        ELSE 'Other'
    END AS Frequency,
    j.date_created AS CreatedDate,
    j.description
FROM sysjobs j
LEFT JOIN sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name LIKE '%Recalculation%' OR j.name LIKE '%Indicator%'
ORDER BY j.name;