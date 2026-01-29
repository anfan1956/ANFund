use cTrader
go

SELECT 
    j.name AS JobName,
    ja.start_execution_date AS StartTime,
    js.step_name AS CurrentStep,
    -- Human-readable schedule type
    CASE s.freq_type
        WHEN 1 THEN 'No repetition'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly, relative to frequency interval'
        WHEN 64 THEN 'When SQL Server Agent starts'
        WHEN 128 THEN 'When computer is idle'
        ELSE 'Other/Unknown'

    END AS ScheduleType,
    -- Duration as HH:MM
    RIGHT('0' + CAST(DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) / 60 AS VARCHAR), 2) + ':' +
    RIGHT('0' + CAST(DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) % 60 AS VARCHAR), 2) AS Duration,
  -- Owner name (readable)
  suser_sname(j.owner_sid) AS JobOwner            
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
LEFT JOIN msdb.dbo.sysjobsteps js 
    ON ja.job_id = js.job_id AND ja.last_executed_step_id = js.step_id
LEFT JOIN msdb.dbo.sysjobschedules jsch ON j.job_id = jsch.job_id
LEFT JOIN msdb.dbo.sysschedules s ON jsch.schedule_id = s.schedule_id
JOIN (
    SELECT job_id, MAX(start_execution_date) AS MaxStart
    FROM msdb.dbo.sysjobactivity
    GROUP BY job_id
) MaxDates ON ja.job_id = MaxDates.job_id AND ja.start_execution_date = MaxDates.MaxStart
WHERE ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL
ORDER BY StartTime;