IF OBJECT_ID('algo.fn_GetInstancePositionIDs') IS NOT NULL
    DROP FUNCTION algo.fn_GetInstancePositionIDs;
GO

CREATE FUNCTION algo.fn_GetInstancePositionIDs(@instance_guid UNIQUEIDENTIFIER)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @result NVARCHAR(MAX);
    DECLARE @config_id INT;
    
    -- Get configID from strategyTracker using instance GUID
    SELECT @config_id = configID 
    FROM algo.strategyTracker 
    WHERE configInstanceGUID = @instance_guid;
    
    IF @config_id IS NULL
        RETURN '[]';
    
    SELECT @result = COALESCE(
        '[' + 
        STRING_AGG(
            CONCAT(
                '{"id":', tv.ID,
                ',"direction":"', tv.direction, '"',
                ',"volume":', tv.volume,
                ',"orderUUID":"', tv.orderUUID, '"',
                ',"ticker":"', tv.ticker, '"',
                '}'
            ), 
            ','
        ) + ']',
        '[]'
    )
    FROM trd.trades_v tv
    INNER JOIN algo.strategies_positions sp ON sp.trade_uuid = tv.orderUUID
    WHERE tv.tradeType = 'POSITION'
      AND sp.strategy_configuration_id = @config_id;
    
    RETURN @result;
END;
GO

-- Test query
SELECT algo.fn_GetInstancePositionIDs('D05F3779-25C0-44A9-9FB5-7422C68EA7FE') as positions_json;