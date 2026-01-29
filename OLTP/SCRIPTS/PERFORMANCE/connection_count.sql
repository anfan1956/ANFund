-- Сколько соединений от каждой стратегии
SELECT 
    program_name,
    COUNT(*) as connection_count,
    MIN(login_time) as first_login,
    MAX(login_time) as last_login
FROM sys.dm_exec_sessions 
WHERE database_id = DB_ID('cTrader')
    AND program_name LIKE '%python%'
GROUP BY program_name
ORDER BY connection_count DESC;