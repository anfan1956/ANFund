-- 1. Создаем VIEW с суффиксом _v
IF OBJECT_ID('algo.strategy_termination_queue_v') IS NOT NULL   DROP VIEW algo.strategy_termination_queue_v;
GO

CREATE VIEW algo.strategy_termination_queue_v
AS
    SELECT 
        config_id,
        id as termination_id,
        requested_at
    FROM algo.strategy_termination_queue 
    WHERE terminate = 1 
      AND terminated_at IS NULL;
GO

-- Тестовый запрос
SELECT * FROM algo.strategy_termination_queue_v;
