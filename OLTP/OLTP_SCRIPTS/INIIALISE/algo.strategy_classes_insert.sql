-- ============================================
-- Window 2: Initial Data Population
-- ============================================

-- Trend Following Strategies
INSERT INTO algo.strategy_classes 
(class_name, class_code, category, description, typical_instruments, typical_timeframes,
 required_data_frequency, required_history_days, typical_position_hold_time,
 requires_realtime_data, requires_news_feed, requires_multiple_instruments,
 requires_options_data, requires_fundamental_data,
 implementation_complexity, backtesting_complexity, maintenance_complexity,
 risk_level, capital_requirements, drawdown_characteristics,
 feasible_with_current_setup, recommended_for_start)
VALUES
-- Moving Average Systems
('Moving Average Crossover', 'MA_CROSSOVER', 'Trend',
 'Buy when fast MA crosses above slow MA, sell when fast MA crosses below slow MA.',
 'Forex, Commodities, Indices', 'H1,H4,D1',
 '1Min', 100, 'Hours to Days',
 0, 0, 0, 0, 0,
 2, 2, 2, 3, 'Low', 'Moderate during ranging markets',
 1, 1),

('Dual Moving Average System', 'DUAL_MA_SYSTEM', 'Trend',
 'Two MAs (fast and slow) with trend filter. Trades only in trend direction.',
 'Forex, Stocks', 'M15,H1,H4',
 '1Min', 60, 'Hours',
 0, 0, 0, 0, 0,
 2, 2, 2, 3, 'Low', 'Controlled',
 1, 1),

('EMA Ribbon Strategy', 'EMA_RIBBON', 'Trend',
 'Multiple EMAs aligned in order. Buy when faster EMAs are above slower ones.',
 'Forex, Crypto', 'H1,H4',
 '5Min', 90, 'Days',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Slow developing',
 1, 0),

-- ADX Based Trend Strategies
('ADX with MA Trend', 'ADX_MA_TREND', 'Trend',
 'ADX for trend strength + MA for direction. Trade only when ADX > 25.',
 'All liquid pairs', 'H1,H4,D1',
 '5Min', 120, 'Days',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Medium', 'Low during sideways',
 1, 1),

-- Reversal/Mean Reversion Strategies
('RSI Overbought/Oversold', 'RSI_REVERSAL', 'Reversal',
 'Buy when RSI < 30, sell when RSI > 70. Classic mean reversion.',
 'Forex, Stocks, Commodities', 'M15,H1,H4',
 '1Min', 60, 'Minutes to Hours',
 0, 0, 0, 0, 0,
 2, 2, 2, 4, 'Low', 'High during strong trends',
 1, 1),

('Bollinger Bands Reversion', 'BB_REVERSAL', 'Reversal',
 'Price touches upper/lower Bollinger Band + RSI/Stochastic confirmation.',
 'Forex, Indices', 'M15,H1',
 '1Min', 90, 'Minutes to Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 4, 'Low', 'High in trending markets',
 1, 1),

('Stochastic Reversal', 'STOCH_REVERSAL', 'Reversal',
 'Stochastic in extreme zones + divergence. Slow stochastic 14,3,3.',
 'Forex, Commodities', 'H1,H4',
 '5Min', 60, 'Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 4, 'Low', 'Moderate',
 1, 0),

-- Breakout Strategies
('Support Resistance Breakout', 'SR_BREAKOUT', 'Breakout',
 'Breakout of key support/resistance levels with volume confirmation.',
 'Forex, Stocks, Indices', 'H1,H4,D1',
 '5Min', 90, 'Hours to Days',
 0, 0, 0, 0, 0,
 3, 3, 3, 4, 'Medium', 'False breakouts can cause losses',
 1, 1),

('Triangle Breakout', 'TRIANGLE_BREAKOUT', 'Breakout',
 'Trade breakouts from triangles (symmetrical, ascending, descending).',
 'Forex, Stocks', 'H4,D1',
 '15Min', 120, 'Days',
 0, 0, 0, 0, 0,
 4, 4, 3, 4, 'Medium', 'Low frequency, high reward potential',
 1, 0),

('Channel Breakout', 'CHANNEL_BREAKOUT', 'Breakout',
 'Breakout of channel upper/lower boundaries.',
 'All instruments', 'H1,H4',
 '5Min', 60, 'Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Moderate',
 1, 1),

-- Range Trading Strategies
('Range Trading RSI', 'RANGE_RSI', 'Range',
 'Buy at range bottom with RSI < 40, sell at range top with RSI > 60.',
 'Forex, Commodities', 'H1,H4',
 '5Min', 45, 'Hours',
 0, 0, 0, 0, 0,
 2, 2, 2, 3, 'Low', 'Low during trends',
 1, 1),

('Bollinger Band Squeeze', 'BB_SQUEEZE', 'Range',
 'Trade on Bollinger Band squeeze and expansion. Enter on expansion after squeeze.',
 'Forex, Indices', 'M15,H1',
 '1Min', 60, 'Minutes to Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Low during high volatility',
 1, 0),

('Keltner Channel Range', 'KELTNER_RANGE', 'Range',
 'Trade within Keltner Channel using ATR for stop losses.',
 'Forex, Stocks', 'H1,H4',
 '5Min', 75, 'Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Controlled',
 1, 1),

-- Multi-Timeframe Strategies
('Multi-Timeframe MA Alignment', 'MTF_MA_ALIGN', 'Multi-Timeframe',
 'Trend alignment across three timeframes (H4, H1, M15). Trade only when all agree.',
 'Forex, Crypto', 'M15,H1,H4',
 '1Min', 150, 'Hours',
 0, 0, 0, 0, 0,
 4, 4, 3, 2, 'Low', 'Very low, filters false signals',
 1, 1),

('Higher TF Support with Lower TF Entry', 'HTF_SUPPORT_LTF_ENTRY', 'Multi-Timeframe',
 'Support/resistance on higher TF + entry pattern on lower TF.',
 'All instruments', 'H4/D1 + M15/M5',
 '1Min', 90, 'Hours to Days',
 0, 0, 0, 0, 0,
 4, 4, 3, 3, 'Medium', 'Low due to confluence',
 1, 0),

-- Indicator Combination Strategies
('MACD + RSI Combo', 'MACD_RSI_COMBO', 'Indicator Combo',
 'MACD for direction + RSI for overbought/oversold conditions.',
 'Forex, Stocks, Indices', 'H1,H4',
 '5Min', 100, 'Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Moderate',
 1, 1),

('Ichimoku Cloud System', 'ICHIMOKU', 'Indicator Combo',
 'Complete Ichimoku system: cloud, conversion/base lines, Chikou Span.',
 'Forex, Crypto', 'H1,H4,D1',
 '5Min', 200, 'Days',
 0, 0, 0, 0, 0,
 5, 4, 4, 3, 'Medium', 'Complex but robust',
 1, 0),

('Parabolic SAR + ADX', 'PSAR_ADX', 'Indicator Combo',
 'Parabolic SAR for trailing stop + ADX for trend strength.',
 'Forex, Commodities', 'H1,H4',
 '5Min', 80, 'Hours to Days',
 0, 0, 0, 0, 0,
 3, 3, 2, 3, 'Low', 'Works well in trends',
 1, 1),

-- Pattern Based Strategies
('Candlestick Pattern Recognition', 'CANDLE_PATTERNS', 'Patterns',
 'Candlestick pattern recognition: pin bar, inside bar, engulfing.',
 'All instruments', 'H1,H4,D1',
 '1Min', 60, 'Hours',
 0, 0, 0, 0, 0,
 4, 4, 3, 4, 'Low', 'Pattern failure risk',
 1, 0),

('Chart Pattern Trading', 'CHART_PATTERNS', 'Patterns',
 'Trade chart patterns: head and shoulders, double top/bottom, flags.',
 'Stocks, Forex', 'H4,D1,W1',
 '15Min', 180, 'Days',
 0, 0, 0, 0, 0,
 5, 5, 4, 4, 'Medium', 'Low frequency, high reward',
 1, 0),

-- Simple Momentum Strategies
('Momentum with ATR', 'MOMENTUM_ATR', 'Momentum',
 'Price momentum combined with ATR for dynamic stop losses.',
 'Forex, Stocks', 'M15,H1',
 '1Min', 50, 'Hours',
 0, 0, 0, 0, 0,
 3, 3, 2, 4, 'Low', 'High during reversals',
 1, 1),

('Price Action Swing Trading', 'PRICE_ACTION_SWING', 'Momentum',
 'Swing trading based on price action patterns and momentum.',
 'All instruments', 'H4,D1',
 '15Min', 120, 'Days',
 0, 0, 0, 0, 0,
 4, 4, 3, 4, 'Medium', 'Moderate',
 1, 0),

-- Simple Grid/Martingale (with caution)
('Fixed Grid Trading', 'FIXED_GRID', 'Grid',
 'Place buy/sell orders at fixed price intervals. Simple grid approach.',
 'Forex, Crypto', 'Any',
 '5Min', 30, 'Variable',
 0, 0, 0, 0, 0,
 2, 3, 3, 5, 'High', 'Very high in trending markets',
 1, 0),

-- Time Based Strategies
('End of Day Close', 'EOD_CLOSE', 'Time Based',
 'Close all positions at end of trading day. Avoid overnight risk.',
 'All instruments', 'Any',
 '1Min', 1, 'Intraday only',
 0, 0, 0, 0, 0,
 1, 1, 1, 2, 'Low', 'None for overnight',
 1, 1),

('Fixed Duration Trade', 'FIXED_DURATION', 'Time Based',
 'Fixed time exit after entry. Close after N minutes regardless of price.',
 'Any', 'Any',
 '1Min', 1, 'Fixed time',
 0, 0, 0, 0, 0,
 1, 1, 1, 5, 'Low', 'High',
 1, 0),

-- Educational/Test Strategies
('Random Entry System', 'RANDOM_ENTRY', 'Educational',
 'Random entries with fixed stop loss and take profit for execution testing.',
 'Any', 'Any',
 '1Min', 1, 'Minutes',
 0, 0, 0, 0, 0,
 1, 1, 1, 5, 'Low', 'Very high',
 1, 0),

('Market Maker Simulator', 'MM_SIMULATOR', 'Educational',
 'Simulate market maker behavior for educational purposes.',
 'Any', 'Any',
 '1Min', 7, 'Variable',
 0, 0, 0, 0, 0,
 2, 2, 2, 3, 'Low', 'Simulated only',
 1, 0);

-- Show insertion count
PRINT '============================================';
PRINT 'Inserted ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' strategy classes';
PRINT '============================================';

-- Verify data
SELECT 
    COUNT(*) as TotalStrategies,
    SUM(CASE WHEN feasible_with_current_setup = 1 THEN 1 ELSE 0 END) as FeasibleNow,
    SUM(CASE WHEN recommended_for_start = 1 THEN 1 ELSE 0 END) as RecommendedStart,
    COUNT(DISTINCT category) as CategoriesCount
FROM algo.strategy_classes 
WHERE is_active = 1;

-- Show by category
SELECT 
    category,
    COUNT(*) as StrategyCount,
    SUM(CASE WHEN feasible_with_current_setup = 1 THEN 1 ELSE 0 END) as FeasibleCount,
    SUM(CASE WHEN recommended_for_start = 1 THEN 1 ELSE 0 END) as RecommendedCount,
    AVG(CAST(risk_level AS FLOAT)) as AvgRisk,
    AVG(CAST(implementation_complexity AS FLOAT)) as AvgComplexity
FROM algo.strategy_classes 
WHERE is_active = 1
GROUP BY category
ORDER BY FeasibleCount DESC;