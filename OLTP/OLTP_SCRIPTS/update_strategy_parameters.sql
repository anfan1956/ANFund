USE cTrader
GO

USE cTrader
GO

-- Обновить ParameterSets с правильными именами timeframe параметров
DECLARE @ParameterSetId INT;
SELECT @ParameterSetId = ParameterSetId 
FROM algo.strategies 
WHERE strategy_code = 'mtf_rsi_ema';

UPDATE algo.ParameterSets
SET ParameterSetJson = JSON_MODIFY(
    ParameterSetJson,
    '$.parameters',
    JSON_QUERY(
	'{
        "ticker": {
            "type": "string",
            "display_name": "ticker",
            "description": "Trading instrument symbol (e.g. XAUUSD, XAGUSD)"
        },
        "timeframe_signal": {
            "type": "integer",
            "display_name": "Signal Timeframe ID",
            "description": "Timeframe ID for signal generation (e.g. M1 = 1)"
        },
        "timeframe_confirmation": {
            "type": "integer",
            "display_name": "Confirmation Timeframe ID", 
            "description": "Timeframe ID for signal confirmation (e.g. M15 = 3)"
        },
        "timeframe_trend": {
            "type": "integer",
            "display_name": "Trend Timeframe ID",
            "description": "Timeframe ID for trend filter (e.g. H1 = 5)"
        },
        "open_volume": {
            "type": "number",
            "display_name": "Position Volume",
            "description": "Initial position volume in lots",
            "validation": {
                "min": 0.01,
                "max": 10,
                "decimal_places": 2
            }
        },
        "trading_close_utc": {
            "type": "time",
            "display_name": "Daily Close Time",
            "description": "Time to force close positions (UTC HH:MM)"
        },
        "trading_start_utc": {
            "type": "time",
            "display_name": "Daily Start Time",
            "description": "Time to allow positions (UTC HH:MM)"
        },
        "broker_id": {
            "type": "integer",
            "display_name": "Broker ID",
            "description": "Broker identifier for trading signals"
        },
        "platform_id": {
            "type": "integer",
            "display_name": "Platform ID",
            "description": "Trading platform identifier"
        },
        "max_position_checks": {
            "type": "integer",
            "display_name": "Max Position Checks",
            "description": "Maximum attempts to verify position opening"
        },
        "check_interval_seconds": {
            "type": "integer",
            "display_name": "Check Interval",
            "description": "Seconds between position verification checks"
        }
    }'
	))
WHERE Id = @ParameterSetId;

-- Проверить результат
SELECT 
    [key] as [Parameter],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.display_name') as [Display Name],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.description') as [Description]
FROM algo.strategies s
INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id
CROSS APPLY OPENJSON(ps.ParameterSetJson COLLATE DATABASE_DEFAULT, '$.parameters') 
WHERE s.strategy_code = 'mtf_rsi_ema'
ORDER BY [Parameter];

USE cTrader
GO

-- Все параметры стратегии mtf_rsi_ema (обновлённые имена)
SELECT 
    [key] as [Parameter],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.display_name') as [Display Name],
    JSON_VALUE([value] COLLATE DATABASE_DEFAULT, '$.description') as [Description],
    NULL as [Value]  -- Для заполнения в Excel
FROM algo.strategies s
INNER JOIN algo.ParameterSets ps ON s.ParameterSetId = ps.Id
CROSS APPLY OPENJSON(ps.ParameterSetJson COLLATE DATABASE_DEFAULT, '$.parameters') 
WHERE s.strategy_code = 'mtf_rsi_ema'
ORDER BY [Parameter];
