-- ============================================================
-- Function: algo.fn_GetStrategyConfiguration
-- Description: Returns complete strategy configuration for given config ID
--              including parameter values, timeframe IDs, and ticker mapping
-- Parameters: @configID - ID from algo.ConfigurationSets table
-- Returns: Single row with all configuration parameters ready for strategy use
-- ============================================================

IF OBJECT_ID ('algo.fn_GetStrategyConfiguration') IS NOT NULL DROP FUNCTION algo.fn_GetStrategyConfiguration
GO

CREATE FUNCTION algo.fn_GetStrategyConfiguration
(
    @configID INT
)
RETURNS TABLE
AS
RETURN
(
    WITH ConfigurationParams AS (
        -- Parse JSON parameters from ConfigurationSets
        SELECT 
            cs.Id AS config_id,
            JSON_VALUE(cs.ParameterValuesJson, '$.ticker') AS ticker,
            JSON_VALUE(cs.ParameterValuesJson, '$.timeframe_signal') AS timeframe_signal_code,
            JSON_VALUE(cs.ParameterValuesJson, '$.timeframe_confirmation') AS timeframe_confirmation_code,
            JSON_VALUE(cs.ParameterValuesJson, '$.timeframe_trend') AS timeframe_trend_code,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.open_volume') AS DECIMAL(18, 4)) AS open_volume,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.trading_close_utc') AS TIME) AS trading_close_utc,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.trading_start_utc') AS TIME) AS trading_start_utc,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.broker_id') AS INT) AS broker_id,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.platform_id') AS INT) AS platform_id,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.max_position_checks') AS INT) AS max_position_checks,
            TRY_CAST(JSON_VALUE(cs.ParameterValuesJson, '$.check_interval_seconds') AS INT) AS check_interval_seconds
        FROM 
            algo.ConfigurationSets cs
        WHERE 
            cs.Id = @configID
    )
    SELECT 
        cp.config_id,
        cp.ticker,
        -- Get TickerJID from ref.SymbolMapping using broker_id from parameters
        sm.assetID AS ticker_jid,
        -- Map timeframe codes to IDs
        tf_signal.ID AS timeframe_signal_id,
        tf_confirmation.ID AS timeframe_confirmation_id,
        tf_trend.ID AS timeframe_trend_id,
        cp.open_volume,
        cp.trading_close_utc,
        cp.trading_start_utc,
        cp.broker_id,
        cp.platform_id,
        cp.max_position_checks,
        cp.check_interval_seconds
    FROM 
        ConfigurationParams cp
        -- Get TickerJID from SymbolMapping using broker_id from parameters
        LEFT JOIN ref.SymbolMapping sm ON 
            sm.Symbol = cp.ticker 
            AND sm.brokerID = cp.broker_id
        -- Map signal timeframe code to ID
        LEFT JOIN tms.timeframes tf_signal ON 
            tf_signal.timeframeCode = cp.timeframe_signal_code
        -- Map confirmation timeframe code to ID
        LEFT JOIN tms.timeframes tf_confirmation ON 
            tf_confirmation.timeframeCode = cp.timeframe_confirmation_code
        -- Map trend timeframe code to ID
        LEFT JOIN tms.timeframes tf_trend ON 
            tf_trend.timeframeCode = cp.timeframe_trend_code
);
go

DECLARE @configID INT = 1; -- Replace with actual config ID
SELECT * FROM algo.fn_GetStrategyConfiguration(@configID);