USE cTrader
GO

PRINT 'Creating view vw_Momentum_Signals...'

-- Удаляем view если существует
IF OBJECT_ID('tms.vw_Momentum_Signals', 'V') IS NOT NULL
    DROP VIEW tms.vw_Momentum_Signals
GO

-- Создаем view для сигналов
CREATE VIEW tms.vw_Momentum_Signals
AS
SELECT 
    im.MomentumID,
    im.TickerJID,
    am.ticker AS Symbol,
    im.BarTime,
    im.TimeFrameID,
    tf.timeframeCode AS TimeFrameCode,  -- Исправил здесь!
    im.SourceID,
    src.sourceName AS SourceName,
    
    -- RSI значения
    im.RSI_14,
    im.RSI_7,
    im.RSI_21,
    
    -- Статистические метрики
    im.RSI_ZScore,
    im.RSI_Percentile,
    im.RSI_Slope_5,
    
    -- Композитные оценки
    im.Momentum_Score,
    
    -- Флаги состояний
    im.Overbought_Flag,
    im.Oversold_Flag,
    
    -- Условия RSI (для фильтрации)
    CASE 
        WHEN im.RSI_14 < 25 THEN 'EXTREME_OVERSOLD'
        WHEN im.RSI_14 < 30 THEN 'STRONG_OVERSOLD'
        WHEN im.RSI_14 < 35 THEN 'OVERSOLD'
        WHEN im.RSI_14 > 75 THEN 'EXTREME_OVERBOUGHT'
        WHEN im.RSI_14 > 70 THEN 'STRONG_OVERBOUGHT'
        WHEN im.RSI_14 > 65 THEN 'OVERBOUGHT'
        ELSE 'NEUTRAL'
    END AS RSI_Condition,
    
    -- Уровень Z-Score
    CASE 
        WHEN im.RSI_ZScore < -2.5 THEN 'EXTREME_LOW'
        WHEN im.RSI_ZScore < -2.0 THEN 'VERY_LOW'
        WHEN im.RSI_ZScore < -1.0 THEN 'LOW'
        WHEN im.RSI_ZScore > 2.5 THEN 'EXTREME_HIGH'
        WHEN im.RSI_ZScore > 2.0 THEN 'VERY_HIGH'
        WHEN im.RSI_ZScore > 1.0 THEN 'HIGH'
        ELSE 'NORMAL'
    END AS ZScore_Level,
    
    -- Направление тренда по RSI
    CASE 
        WHEN im.RSI_Slope_5 > 0.5 THEN 'STRONG_UP'
        WHEN im.RSI_Slope_5 > 0.1 THEN 'UP'
        WHEN im.RSI_Slope_5 < -0.5 THEN 'STRONG_DOWN'
        WHEN im.RSI_Slope_5 < -0.1 THEN 'DOWN'
        ELSE 'FLAT'
    END AS RSI_Trend_Direction,
    
    -- Сигналы для торговли
    CASE 
        -- Сильные сигналы на покупку
        WHEN im.RSI_14 < 30 AND im.RSI_Slope_5 > 0.1 THEN 'STRONG_BUY'
        WHEN im.RSI_14 < 35 AND im.RSI_ZScore < -1.5 THEN 'BUY'
        -- Сильные сигналы на продажу
        WHEN im.RSI_14 > 70 AND im.RSI_Slope_5 < -0.1 THEN 'STRONG_SELL'
        WHEN im.RSI_14 > 65 AND im.RSI_ZScore > 1.5 THEN 'SELL'
        -- Нейтральные условия
        ELSE 'HOLD'
    END AS Trading_Signal,
    
    -- Метаданные
    im.BatchID,
    im.CalculationTimeMS,
    im.CreatedDate,
    im.ModifiedDate,
    
    -- Время с последнего обновления (в минутах)
    DATEDIFF(MINUTE, im.BarTime, GETUTCDATE()) AS Minutes_Since_Bar
    
FROM tms.Indicators_Momentum im
INNER JOIN ref.assetMasterTable am ON im.TickerJID = am.ID
INNER JOIN tms.TimeFrames tf ON im.TimeFrameID = tf.ID
INNER JOIN tms.Sources src ON im.SourceID = src.ID
WHERE im.RSI_14 IS NOT NULL
GO

PRINT 'View tms.vw_Momentum_Signals created successfully!';
GO