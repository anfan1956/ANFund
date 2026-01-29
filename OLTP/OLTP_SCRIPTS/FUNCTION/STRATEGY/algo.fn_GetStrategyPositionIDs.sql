IF OBJECT_ID('algo.fn_GetStrategyPositionIDs') IS NOT NULL
    DROP FUNCTION algo.fn_GetStrategyPositionIDs;
GO

CREATE FUNCTION algo.fn_GetStrategyPositionIDs(@config_id INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @result NVARCHAR(MAX);
    
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

-- Тестовый запрос
SELECT algo.fn_GetStrategyPositionIDs(3) as positions_json;
-- Тестовый запрос


select * from trd.trades_v 