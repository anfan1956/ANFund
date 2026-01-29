
-- 2. Процедура с префиксом sp_ (остается как есть)
IF OBJECT_ID('algo.sp_MarkTerminationCompleted') IS NOT NULL  DROP PROCEDURE algo.sp_MarkTerminationCompleted;
GO

CREATE PROCEDURE algo.sp_MarkTerminationCompleted
    @termination_id INT
AS
BEGIN
    UPDATE algo.strategy_termination_queue 
    SET terminated_at = GETUTCDATE()
    WHERE id = @termination_id;
END;
GO

-- Тестовый вызов
EXEC algo.sp_MarkTerminationCompleted @termination_id = 1;