-- Скрипт для пробного заполнения таблицы барами
DECLARE @sourceID INT = (SELECT ID FROM tms.sources WHERE sourceName = 'Peperstone_cTrader');
DECLARE @timeframeID INT = (SELECT ID FROM tms.timeframes WHERE timeframeCode = 'M1');

-- XAUUSD
INSERT INTO tms.bars (TickerJID, barTime, timeframeID, openValue, closeValue, highValue, lowValue, sourceID)
VALUES 
(13, '2026-01-01 00:00:00', @timeframeID, 1800.50, 1801.20, 1802.00, 1800.10, @sourceID),
(13, '2026-01-01 00:01:00', @timeframeID, 1801.20, 1800.80, 1801.50, 1800.50, @sourceID),
(13, '2026-01-01 00:02:00', @timeframeID, 1800.80, 1802.30, 1803.00, 1800.60, @sourceID);

-- XAGUSD
INSERT INTO tms.bars (TickerJID, barTime, timeframeID, openValue, closeValue, highValue, lowValue, sourceID)
VALUES 
(14, '2026-01-01 00:00:00', @timeframeID, 22.50, 22.52, 22.55, 22.48, @sourceID),
(14, '2026-01-01 00:01:00', @timeframeID, 22.52, 22.49, 22.53, 22.47, @sourceID),
(14, '2026-01-01 00:02:00', @timeframeID, 22.49, 22.55, 22.58, 22.48, @sourceID);

-- NAS100
INSERT INTO tms.bars (TickerJID, barTime, timeframeID, openValue, closeValue, highValue, lowValue, sourceID)
VALUES 
(19, '2026-01-01 00:00:00', @timeframeID, 18500.50, 18501.20, 18502.00, 18500.10, @sourceID),
(19, '2026-01-01 00:01:00', @timeframeID, 18501.20, 18500.80, 18501.50, 18500.50, @sourceID),
(19, '2026-01-01 00:02:00', @timeframeID, 18500.80, 18502.30, 18503.00, 18500.60, @sourceID);

-- Проверка вставленных данных
SELECT 
    b.ID,
    am.Ticker,
    b.barTime,
    tf.timeframeCode,
    b.openValue,
    b.closeValue,
    b.highValue,
    b.lowValue
FROM tms.bars b
INNER JOIN ref.assetMasterTable am ON b.TickerJID = am.ID
INNER JOIN tms.timeframes tf ON b.timeframeID = tf.ID
WHERE am.Ticker IN ('XAUUSD', 'XAGUSD', 'NAS100')
ORDER BY am.Ticker, b.barTime;