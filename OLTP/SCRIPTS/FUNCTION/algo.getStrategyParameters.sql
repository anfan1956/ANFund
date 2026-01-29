use cTrader
go
CREATE OR ALTER FUNCTION algo.getStrategyParameters(@config_id INT = NULL)
RETURNS TABLE
AS
RETURN
(
    -- Все параметры из ParameterSets
    SELECT 
        p.param_name as [Parameter],
        CASE 
            WHEN @config_id IS NOT NULL THEN
                JSON_VALUE(cs.ParameterValuesJson COLLATE DATABASE_DEFAULT, CONCAT('$.', p.param_name))
            ELSE NULL
        END as [Value],
        p.display_name as [Display Name],
        p.description as [Description]
    FROM (
        -- Извлекаем параметры из ParameterSetJson
        SELECT 
            [key] as param_name,
            JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.display_name') as display_name,
            JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.description') as description
        FROM algo.strategies s
        INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id
        CROSS APPLY OPENJSON(ps.ParameterSetJson COLLATE DATABASE_DEFAULT, '$.parameters') 
        WHERE s.strategy_code = 'mtf_rsi_ema'
    ) p
    LEFT JOIN algo.strategy_configurations sc ON sc.ID = @config_id
    LEFT JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
);
go
-- 2. Использование функции:
-- Пустая таблица (все параметры, значения NULL)

SELECT * FROM algo.getStrategyParameters(1);

-- С параметрами для config_id=1
SELECT * FROM algo.getStrategyParameters(1);

-- 3. Альтернативный простой запрос:
SELECT 
    'open_volume' as [Parameter],
    JSON_VALUE(cs.ParameterValuesJson, '$.open_volume') as [Value],
    'Initial position volume in lots' as [Definition]
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1

UNION ALL

SELECT 
    'close_time_utc',
    JSON_VALUE(cs.ParameterValuesJson, '$.close_time_utc'),
    'Time to force close positions (UTC HH:MM)'
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1

UNION ALL

SELECT 
    'broker_id',
    JSON_VALUE(cs.ParameterValuesJson, '$.broker_id'),
    'Broker identifier'
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1

UNION ALL

SELECT 
    'platform_id',
    JSON_VALUE(cs.ParameterValuesJson, '$.platform_id'),
    'Platform identifier'
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1

UNION ALL

SELECT 
    'max_position_checks',
    JSON_VALUE(cs.ParameterValuesJson, '$.max_position_checks'),
    'Max position verification attempts'
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1

UNION ALL

SELECT 
    'check_interval_seconds',
    JSON_VALUE(cs.ParameterValuesJson, '$.check_interval_seconds'),
    'Seconds between checks'
FROM algo.strategy_configurations sc
INNER JOIN algo.ConfigurationSets cs ON sc.ConfigurationSetId = cs.Id
WHERE sc.ID = 1;




USE cTrader
GO

-- Все параметры стратегии mtf_rsi_ema
SELECT 
    [key] as [Parameter],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.display_name') as [Display Name],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.description') as [Description],
    NULL as [Value]  -- Значения будут заполнены в Excel
FROM algo.strategies s
INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id
CROSS APPLY OPENJSON(ps.ParameterSetJson COLLATE DATABASE_DEFAULT, '$.parameters') 
WHERE s.strategy_code = 'mtf_rsi_ema'
ORDER BY [Parameter];