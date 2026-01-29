-- Самый простой способ найти блокировки
SELECT 
    session_id,
    blocking_session_id,
    wait_type,
    wait_time,
    command,
    text
FROM sys.dm_exec_requests
	CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE blocking_session_id > 0 
   OR session_id IN (SELECT DISTINCT blocking_session_id FROM sys.dm_exec_requests);

   