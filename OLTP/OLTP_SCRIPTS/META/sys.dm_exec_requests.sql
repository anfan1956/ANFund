-- Второе окно для мониторинга
SELECT 
    session_id,
    command,
    status,
    DATEDIFF(SECOND, start_time, GETDATE()) as running_seconds,
    DB_NAME(database_id) as db_name
FROM sys.dm_exec_requests 
WHERE command NOT IN ('SELECT', 'AWAITING COMMAND')
ORDER BY start_time;