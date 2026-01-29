USE [msdb]
GO
/*
-- Проверяем статус Job
SELECT 
    name as JobName,
    enabled as IsEnabled,
    CASE enabled 
        WHEN 1 THEN 'Enabled' 
        ELSE 'Disabled' 
    END as Status,
    date_created as CreatedDate,
    date_modified as ModifiedDate
FROM sysjobs 
WHERE name = 'processIndicators';
GO
*/

use cTrader
go


USE [cTrader]
GO
-- Проверяем последние бары и их индикаторы
PRINT '=== Проверяем расчеты за последние 2 минуты ===';

SELECT 
    b.ID,
    a.ticker,
    a.name as SymbolName,
    b.TimeFrameID,
    b.BarTime,
    b.CloseValue,
    CASE WHEN m.ID IS NULL THEN 'NO' ELSE 'YES' END as HasMA,
    CASE WHEN e.ID IS NULL THEN 'NO' ELSE 'YES' END as HasEMA
FROM tms.Bars b
INNER JOIN ref.assetMasterTable a ON b.TickerJID = a.ID
LEFT JOIN tms.MA m ON b.ID = m.BarID
LEFT JOIN tms.EMA e ON b.ID = e.BarID
WHERE b.BarTime >= DATEADD(MINUTE, -2, GETDATE())
ORDER BY b.BarTime DESC, a.ticker;
GO

USE [cTrader]
GO
select * from tms.logsJob_processIndicators order by 1 desc

USE [msdb]
GO

-- Проверяем историю выполнения Job
SELECT TOP 5
    j.name as JobName,
    h.step_id as Step,
    h.step_name as StepName,
    h.run_date as RunDate,
    h.run_time as RunTime,
    h.run_duration as Duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        ELSE 'Unknown'
    END as Status,
    h.message as Message
FROM sysjobhistory h
INNER JOIN sysjobs j ON h.job_id = j.job_id
WHERE j.name = 'processIndicators'
  AND h.step_id = 0 -- Сводная информация
ORDER BY h.run_date DESC, h.run_time DESC;
GO

USE [msdb]
GO

-- Смотрим детальные ошибки шагов Job
SELECT TOP 10
    j.name as JobName,
    h.step_id as Step,
    h.step_name as StepName,
    h.run_date as RunDate,
    h.run_time as RunTime,
    h.run_duration as Duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        ELSE 'Unknown'
    END as Status,
    h.message as ErrorMessage
FROM sysjobhistory h
INNER JOIN sysjobs j ON h.job_id = j.job_id
WHERE j.name = 'processIndicators'
  AND h.step_id > 0  -- Детали шагов
  AND h.run_status = 0  -- Только ошибки
ORDER BY h.run_date DESC, h.run_time DESC;
GO





USE [msdb]
GO

-- Проверяем последние запуски Job
SELECT TOP 5
    j.name as JobName,
    h.run_date as RunDate,
    h.run_time as RunTime,
    h.run_duration as Duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        ELSE 'Unknown'
    END as Status,
    LEFT(h.message, 200) as Message
FROM sysjobhistory h
INNER JOIN sysjobs j ON h.job_id = j.job_id
WHERE j.name = 'processIndicators'
  AND h.step_id = 0
ORDER BY h.run_date DESC, h.run_time DESC;
GO

SELECT command 
FROM msdb.dbo.sysjobsteps s
INNER JOIN msdb.dbo.sysjobs j ON s.job_id = j.job_id
WHERE j.name = 'processIndicators';