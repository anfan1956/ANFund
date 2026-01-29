-- Проверим данные для BTCUSD (ticker_jid = 56)
SELECT 
	
    b.timeframeID,
    tf.timeframeCode,
    b.barTime,
    b.closeValue,
    ema.EMA_20_SHORT,
    ema.EMA_50_MEDIUM,
    im.Oversold_Flag,
    im.Overbought_Flag
FROM tms.bars b
INNER JOIN tms.timeframes tf ON b.timeframeID = tf.ID
LEFT JOIN tms.EMA ema ON 
    ema.TickerJID = b.TickerJID 
    AND ema.TimeFrameID = b.timeframeID 
    AND ema.BarTime = b.barTime
LEFT JOIN tms.Indicators_Momentum im ON 
    im.TickerJID = b.TickerJID 
    AND im.TimeFrameID = b.timeframeID 
    AND im.BarTime = b.barTime
WHERE b.TickerJID = 56
  AND b.timeframeID IN (1, 3, 5)  -- M1, M15, H1
  AND b.barTime >= DATEADD(HOUR, -1, GETUTCDATE())  -- Последний час
ORDER BY b.timeframeID, b.barTime DESC;




-- Проверим наличие данных H1
SELECT TOP 5 
    timeframeID,
    timeframeCode,
    barTime,
    closeValue
FROM tms.bars b
INNER JOIN tms.timeframes tf ON b.timeframeID = tf.ID
WHERE b.TickerJID = 56
  AND b.timeframeID = 5  -- H1
ORDER BY barTime DESC;