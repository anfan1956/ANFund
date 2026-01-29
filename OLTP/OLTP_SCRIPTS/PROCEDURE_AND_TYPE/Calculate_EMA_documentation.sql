USE [cTrader]
GO

-- =============================================
-- Документация и примеры использования процедур EMA
-- =============================================


/*
Ключевые особенности EMA процедур:

Последовательный расчет - EMA рассчитываются с учетом предыдущих значений

Пакетная обработка - обрабатывает данные частями для производительности

Автоматизация - готовые процедуры для SQL Agent

Гибкость - возможность пересчета за любой период

Мониторинг - встроенная статистика и логирование

Рекомендации по настройке SQL Agent для EMA:

Частота: каждые 10-30 минут (в зависимости от объема данных)

Batch size: 2000-5000 баров за запуск

Максимальное время выполнения: 5-10 минут


*/

PRINT '=== ДОКУМЕНТАЦИЯ ПО ПРОЦЕДУРАМ РАСЧЕТА EMA ===';
PRINT '';
PRINT '1. ОСНОВНАЯ ПРОЦЕДУРА - tms.CalculateAllEMAForNewBars';
PRINT '   Назначение: Расчет всех экспоненциальных скользящих средних для новых баров';
PRINT '   Особенность: EMA рассчитываются последовательно с учетом предыдущих значений';
PRINT '   Параметры:';
PRINT '     @BatchSize - размер пакета (по умолчанию 1000)';
PRINT '     @MaxLookbackDays - максимальный период lookback (по умолчанию 500)';
PRINT '';
PRINT '   Примеры использования:';
PRINT '     -- Обработать до 2000 новых баров';
PRINT '     EXEC tms.CalculateAllEMAForNewBars @BatchSize = 2000;';
PRINT '';
PRINT '2. ПРОЦЕДУРА ДЛЯ SQL AGENT - tms.CalculateEMAForSQLAgent';
PRINT '   Назначение: Автоматический расчет EMA для запуска через SQL Agent';
PRINT '   Особенность: Выполняет несколько проходов для обработки всех новых баров';
PRINT '';
PRINT '   Настройка SQL Agent Job для EMA:';
PRINT '     1. Создать новый Job (например: "Calculate EMA")';
PRINT '     2. Добавить шаг типа "Transact-SQL script"';
PRINT '     3. Команда: EXEC tms.CalculateEMAForSQLAgent;';
PRINT '     4. Настроить расписание (рекомендуется каждые 10-30 минут)';
PRINT '     5. Добавить уведомления при ошибках';
PRINT '';
PRINT '3. ПРОЦЕДУРА ПЕРЕСЧЕТА - tms.RecalculateEMAForPeriod';
PRINT '   Назначение: Принудительный пересчет EMA за определенный период';
PRINT '   Важно: Для корректного расчета EMA необходимо пересчитать всю историю';
PRINT '   Параметры:';
PRINT '     @TickerJID - ID тикера (опционально)';
PRINT '     @TimeFrameID - ID таймфрейма (опционально)';
PRINT '     @StartDate - начальная дата (опционально)';
PRINT '     @EndDate - конечная дата (опционально)';
PRINT '     @BatchSize - размер пакета (по умолчанию 500)';
PRINT '';
PRINT '   Примеры использования:';
PRINT '     -- Пересчитать EMA для всех данных';
PRINT '     EXEC tms.RecalculateEMAForPeriod;';
PRINT '';
PRINT '     -- Пересчитать EMA для конкретного тикера за январь 2024';
PRINT '     EXEC tms.RecalculateEMAForPeriod';
PRINT '         @TickerJID = 123,';
PRINT '         @StartDate = ''2024-01-01'',';
PRINT '         @EndDate = ''2024-01-31'';';
PRINT '';
PRINT '4. ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ - tms.CalculateEMAValue';
PRINT '   Назначение: Расчет значения EMA для конкретного периода';
PRINT '   Параметры:';
PRINT '     @TickerJID - ID тикера';
PRINT '     @TimeFrameID - ID таймфрейма';
PRINT '     @CurrentBarTime - время текущего бара';
PRINT '     @Period - период EMA (5, 9, 12, 20, 21, 26, 50, 55, 100, 144, 200, 233)';
PRINT '     @CurrentClose - текущее значение Close';
PRINT '';
PRINT '   Пример использования:';
PRINT '     SELECT tms.CalculateEMAValue(123, 1, GETDATE(), 20, 100.50);';
PRINT '';
PRINT '=== ПРОВЕРКА СОСТОЯНИЯ РАСЧЕТОВ EMA ===';
PRINT '';
PRINT '-- Проверить количество баров без EMA';
PRINT 'SELECT COUNT(*) AS BarsWithoutEMA';
PRINT 'FROM tms.Bars b';
PRINT 'WHERE NOT EXISTS (SELECT 1 FROM tms.EMA e WHERE e.BarID = b.ID);';
PRINT '';
PRINT '-- Проверить последние рассчитанные EMA';
PRINT 'SELECT TOP 10 e.*, b.CloseValue';
PRINT 'FROM tms.EMA e';
PRINT 'INNER JOIN tms.Bars b ON e.BarID = b.ID';
PRINT 'ORDER BY e.BarTime DESC;';
PRINT '';
PRINT '-- Проверить значения MACD (разница между EMA12 и EMA26)';
PRINT 'SELECT TOP 10';
PRINT '    e.BarTime,';
PRINT '    e.EMA_12_MACD_FAST,';
PRINT '    e.EMA_26_MACD_SLOW,';
PRINT '    e.EMA_12_MACD_FAST - e.EMA_26_MACD_SLOW AS MACD_Value,';
PRINT '    e.EMA_9_MACD_SIGNAL AS MACD_Signal';
PRINT 'FROM tms.EMA e';
PRINT 'WHERE e.TickerJID = 123 -- укажите нужный тикер';
PRINT '  AND e.TimeFrameID = 1 -- укажите нужный таймфрейм';
PRINT 'ORDER BY e.BarTime DESC;';
PRINT '';
PRINT '-- Статистика по EMA';
PRINT 'SELECT ';
PRINT '    COUNT(*) AS TotalRecords,';
PRINT '    SUM(CASE WHEN EMA_5_SHORT IS NULL THEN 1 ELSE 0 END) AS MissingEMA5,';
PRINT '    SUM(CASE WHEN EMA_12_MACD_FAST IS NULL THEN 1 ELSE 0 END) AS MissingEMA12,';
PRINT '    SUM(CASE WHEN EMA_26_MACD_SLOW IS NULL THEN 1 ELSE 0 END) AS MissingEMA26,';
PRINT '    SUM(CASE WHEN EMA_200_LONG IS NULL THEN 1 ELSE 0 END) AS MissingEMA200,';
PRINT '    MIN(BarTime) AS EarliestBar,';
PRINT '    MAX(BarTime) AS LatestBar';
PRINT 'FROM tms.EMA;';
PRINT '';
PRINT '=== СОВМЕСТНОЕ ИСПОЛЬЗОВАНИЕ С ТАБЛИЦЕЙ MA ===';
PRINT '';
PRINT '-- Сравнение MA и EMA для анализа';
PRINT 'SELECT TOP 20';
PRINT '    b.BarTime,';
PRINT '    b.CloseValue,';
PRINT '    m.MA20,';
PRINT '    e.EMA_20_SHORT,';
PRINT '    e.EMA_20_SHORT - m.MA20 AS Diff_EMA20_MA20,';
PRINT '    CASE WHEN e.EMA_20_SHORT > m.MA20 THEN ''EMA выше MA'' ELSE ''MA выше EMA'' END AS Trend_Indicator';
PRINT 'FROM tms.Bars b';
PRINT 'INNER JOIN tms.MA m ON b.ID = m.BarID';
PRINT 'INNER JOIN tms.EMA e ON b.ID = e.BarID';
PRINT 'WHERE b.TickerJID = 123';
PRINT '  AND b.TimeFrameID = 1';
PRINT 'ORDER BY b.BarTime DESC;';
GO