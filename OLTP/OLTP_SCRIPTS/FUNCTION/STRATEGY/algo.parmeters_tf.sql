USE cTrader
GO
/*****************
D:\TradingSystems\OLTP\OLTP\FUNCTION\STRATEGY\algo.parmeters_tf.sql

**************************/



IF OBJECT_ID('algo.parmeters_tf') IS NOT NULL 
    DROP FUNCTION algo.parmeters_tf
GO




CREATE FUNCTION algo.parmeters_tf (@strategyCode NVARCHAR(60), @configID INT = NULL) 
RETURNS TABLE 
AS
RETURN (
    SELECT 
        param.value AS [Parameter],
        CASE 
            WHEN @configID IS NOT NULL THEN 
                JSON_VALUE(cs.ParameterValuesJson, CONCAT('$."', param.value, '"'))
            ELSE NULL 
        END AS [Value]
    FROM algo.strategies s
    INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id  -- Предполагаем, что у стратегии один ParameterSet
    CROSS APPLY OPENJSON(ps.ParameterSetJson) AS param
    -- Подключаем ConfigurationSets только если указан configID
    LEFT JOIN algo.ConfigurationSets cs ON 
        cs.ParameterSetId = ps.Id
        AND (@configID IS NULL OR cs.Id = @configID)
    WHERE s.strategy_code = @strategyCode
)
GO

-- 1. Список параметров стратегии без значений
SELECT * FROM algo.parmeters_tf('mtf_rsi_ema', NULL)
ORDER BY [Parameter]

-- 2. Параметры с значениями для конкретной конфигурации
SELECT * FROM algo.parmeters_tf('mtf_rsi_ema', 3) -- для config_id = 1
ORDER BY [Parameter]

-- 3. Проверка для всех конфигураций стратегии
SELECT 
    cs.Id AS ConfigId,
    f.*
FROM algo.strategies s
INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id
INNER JOIN algo.ConfigurationSets cs ON ps.Id = cs.ParameterSetId
CROSS APPLY algo.parmeters_tf(s.strategy_code, cs.Id) AS f
WHERE s.strategy_code = 'mtf_rsi_ema'
ORDER BY cs.Id, f.[Parameter]
select * from algo.ConfigurationSets