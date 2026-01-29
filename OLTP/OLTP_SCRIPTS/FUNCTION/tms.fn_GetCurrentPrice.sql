IF OBJECT_ID('tms.fn_GetCurrentPrice') IS NOT NULL
    DROP FUNCTION tms.fn_GetCurrentPrice;
GO

CREATE FUNCTION tms.fn_GetCurrentPrice(@ticker_jid INT, @timeframe_id INT = 1)
RETURNS FLOAT
AS
BEGIN
    DECLARE @price FLOAT;
    
    SELECT TOP 1 @price = closeValue
    FROM tms.bars
    WHERE TickerJID = @ticker_jid 
      AND timeframeID = @timeframe_id
    ORDER BY barTime DESC;
    
    RETURN @price;
END;
GO

-- Тестовый запрос
SELECT tms.fn_GetCurrentPrice(56, 1) as current_price;