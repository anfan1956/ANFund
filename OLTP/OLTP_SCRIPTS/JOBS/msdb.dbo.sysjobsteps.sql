-- Находим задание "processIndicators" и все его шаги
USE msdb;
GO

SELECT 
    j.job_id,
    j.name as JobName,
    j.description,
    j.enabled,
    s.step_id,
    s.step_name,
    s.subsystem,
    s.command,
    s.database_name
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobsteps s ON j.job_id = s.job_id
WHERE j.name = 'processIndicators'
ORDER BY s.step_id;



-- Получаем скрипт с форматированием
DECLARE @job_id UNIQUEIDENTIFIER;
DECLARE @step_id INT;
DECLARE @command NVARCHAR(MAX);

SELECT @job_id = job_id 
FROM msdb.dbo.sysjobs 
WHERE name = 'processIndicators';

SELECT TOP 1 
    @step_id = step_id,
    @command = command
FROM msdb.dbo.sysjobsteps 
WHERE job_id = @job_id
ORDER BY step_id;

-- Выводим с переносами строк
SELECT 
    'Step ID: ' + CAST(@step_id AS VARCHAR(10)) as Info,
    @command as CommandText;