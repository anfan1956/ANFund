-- Для всех символов сразу
SELECT 
    t.ticker,
    b.timeframeID,
    COUNT(*) as BarCount,
    MIN(b.barTime) as FirstBar,
    MAX(b.barTime) as LastBar
FROM tms.Bars b
	JOIN ref.assetMasterTable t ON b.TickerJID = t.ID
WHERE t.Ticker IN ('BTCUSD', 'XPDUSD', 'XAUUSD', 'XAGUSD', 'NAS100', 'XPTUSD')
GROUP BY t.Ticker, b.timeframeID
ORDER BY t.Ticker, b.timeframeID;

-- Или для одного символа
SELECT 
    timeframeID,
    COUNT(*) as BarCount,
    MIN(barTime) as FirstBar,
    MAX(barTime) as LastBar
FROM tms.Bars 
WHERE TickerJID = 56  -- BTCUSD
GROUP BY timeframeID
ORDER BY timeframeID;