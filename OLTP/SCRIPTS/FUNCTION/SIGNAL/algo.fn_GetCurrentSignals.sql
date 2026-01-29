-- ============================================================
-- Function: algo.fn_GetCurrentSignals
-- Description: Returns current trading signals for all timeframes in one query
-- Parameters: 
--   @ticker_jid - Ticker JID from ref.SymbolMapping
--   @timeframe_signal_id - Signal timeframe ID (e.g., 1 for M1)
--   @timeframe_confirmation_id - Confirmation timeframe ID (e.g., 3 for M15)
--   @timeframe_trend_id - Trend timeframe ID (e.g., 5 for H1)
-- Returns: Single row with signals for all timeframes
-- ============================================================


-- Минималистичная функция - только проверка условий
IF OBJECT_ID('algo.fn_GetCurrentSignals') IS NOT NULL  DROP FUNCTION algo.fn_GetCurrentSignals;
GO

CREATE FUNCTION algo.fn_GetCurrentSignals
(
    @ticker_jid INT,
    @timeframe_signal_id INT,
    @timeframe_confirmation_id INT,
    @timeframe_trend_id INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Финалный сигнал
        CASE 
            -- BUY: M1 buy + (M15 buy или NULL) + H1 bullish
            WHEN m1_signal = 'buy' 
                 AND (m15_signal = 'buy' OR m15_signal IS NULL)
                 AND h1_trend = 'bullish'
            THEN 'buy'
            
            -- SELL: M1 sell + (M15 sell или NULL) + H1 bearish
            WHEN m1_signal = 'sell' 
                 AND (m15_signal = 'sell' OR m15_signal IS NULL)
                 AND h1_trend = 'bearish'
            THEN 'sell'
            
            ELSE NULL
        END as trading_signal
    FROM (
        -- Базовые сигналы для каждого таймфрейма
        SELECT 
            MAX(CASE WHEN timeframeID = @timeframe_signal_id THEN trading_signal END) as m1_signal,
            MAX(CASE WHEN timeframeID = @timeframe_confirmation_id THEN trading_signal END) as m15_signal,
            MAX(CASE WHEN timeframeID = @timeframe_trend_id THEN trend END) as h1_trend
        FROM (
            SELECT 
                b.timeframeID,
                -- Сигнал по RSI+EMA
                CASE 
                    WHEN b.lowValue <= ema.EMA_20_SHORT 
                         AND prev_im.Oversold_Flag = 1
                         AND im.Oversold_Flag = 0
                    THEN 'buy'
                    WHEN b.highValue >= ema.EMA_20_SHORT 
                         AND prev_im.Overbought_Flag = 1
                         AND im.Overbought_Flag = 0
                    THEN 'sell'
                    ELSE NULL
                END as trading_signal,
                -- Тренд
                CASE 
                    WHEN b.closeValue > ema.EMA_50_MEDIUM THEN 'bullish'
                    WHEN b.closeValue < ema.EMA_50_MEDIUM THEN 'bearish'
                    ELSE NULL
                END as trend
            FROM tms.bars b
            LEFT JOIN tms.Indicators_Momentum im ON 
                im.TickerJID = b.TickerJID 
                AND im.TimeFrameID = b.timeframeID 
                AND im.BarTime = b.barTime
            LEFT JOIN tms.EMA ema ON 
                ema.TickerJID = b.TickerJID 
                AND ema.TimeFrameID = b.timeframeID 
                AND ema.BarTime = b.barTime
            OUTER APPLY (
                SELECT TOP 1 Oversold_Flag, Overbought_Flag
                FROM tms.Indicators_Momentum 
                WHERE TickerJID = b.TickerJID
                  AND TimeFrameID = b.timeframeID
                  AND BarTime < b.barTime
                ORDER BY BarTime DESC
            ) as prev_im
            WHERE b.TickerJID = @ticker_jid
              AND b.timeframeID IN (@timeframe_signal_id, @timeframe_confirmation_id, @timeframe_trend_id)
              AND b.barTime = (
                  SELECT MAX(barTime) 
                  FROM tms.bars 
                  WHERE TickerJID = b.TickerJID 
                    AND timeframeID = b.timeframeID
              )
        ) as base_signals
    ) as all_signals
);
GO

-- Тест

DECLARE @StartTime DATETIME  = GETDATE()
SELECT * FROM algo.fn_GetCurrentSignals(56, 1, 3, 5);
SELECT DATEDIFF(MILLISECOND, @StartTime, GETDATE()) as execTime


-- Проверка последней свечи M1
SELECT TOP 1 
    b.barTime,
    b.lowValue,
    b.highValue,
    b.closeValue,
    im.Oversold_Flag,
    im.Overbought_Flag,
    ema.EMA_20_SHORT,
    ema.EMA_50_MEDIUM,
    -- Предыдущие флаги
    LAG(im.Oversold_Flag) OVER (ORDER BY im.BarTime) as prev_Oversold,
    LAG(im.Overbought_Flag) OVER (ORDER BY im.BarTime) as prev_Overbought
FROM tms.bars b
LEFT JOIN tms.Indicators_Momentum im ON 
    im.TickerJID = b.TickerJID 
    AND im.TimeFrameID = b.timeframeID 
    AND im.BarTime = b.barTime
LEFT JOIN tms.EMA ema ON 
    ema.TickerJID = b.TickerJID 
    AND ema.TimeFrameID = b.timeframeID 
    AND ema.BarTime = b.barTime
WHERE b.TickerJID = 56 
  AND b.timeframeID = 1
ORDER BY b.barTime DESC;
