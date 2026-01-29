"""
Проверка целостности данных Bitcoin (TickerJID=56)
"""

import pyodbc
import pandas as pd
from datetime import datetime, timedelta

def check_bitcoin_data_integrity():
    """Проверяем целостность данных Bitcoin"""

    connection_string = (
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=62.181.56.230;'
        'DATABASE=cTrader;'
        'UID=anfan;'
        'PWD=Gisele12!;'
    )

    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        print("✓ Подключено к базе данных")
    except Exception as e:
        print(f"✗ Ошибка подключения: {e}")
        return

    ticker_jid = 56  # Bitcoin

    print(f"\n{'='*70}")
    print(f"ПРОВЕРКА ЦЕЛОСТНОСТИ ДАННЫХ BITCOIN (TickerJID={ticker_jid})")
    print(f"{'='*70}")

    print(f"1. Проверяем данные для TickerJID={ticker_jid}...")

    # 2. Проверяем доступные таймфреймы напрямую из Bars
    print(f"\n2. Доступные таймфреймы в таблице Bars:")
    cursor.execute("""
        SELECT DISTINCT TimeFrameID, COUNT(*) as BarCount
        FROM tms.Bars
        WHERE TickerJID = ?
        GROUP BY TimeFrameID
        ORDER BY TimeFrameID
    """, ticker_jid)

    timeframes = cursor.fetchall()
    if not timeframes:
        print(f"   ✗ Нет данных для TickerJID={ticker_jid}")
        return
    else:
        for tf_id, count in timeframes:
            print(f"   - TimeFrameID: {tf_id}, Барoв: {count:,}")

    # 3. Проверяем 1-минутные данные (TimeFrameID=1)
    print(f"\n3. Анализ 1-минутных данных (TimeFrameID=1):")

    # Общий объем данных
    cursor.execute("""
        SELECT 
            MIN(barTime) as FirstBar,
            MAX(barTime) as LastBar,
            COUNT(*) as TotalBars,
            COUNT(DISTINCT CAST(barTime as DATE)) as TradingDays
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
    """, ticker_jid)

    stats = cursor.fetchone()
    if stats:
        first_bar, last_bar, total_bars, trading_days = stats
        print(f"   Первый бар:    {first_bar}")
        print(f"   Последний бар: {last_bar}")
        print(f"   Всего баров:   {total_bars:,}")
        print(f"   Торговых дней: {trading_days}")

        if first_bar and last_bar:
            date_range = (last_bar - first_bar).days
            print(f"   Диапазон дат:  {date_range} дней")

            # Ожидаемое количество баров (24 часа * 60 минут)
            expected_bars_per_day = 24 * 60  # 1440
            expected_total_bars = trading_days * expected_bars_per_day
            data_completeness = (total_bars / expected_total_bars * 100) if expected_total_bars > 0 else 0

            print(f"   Ожидалось баров: {expected_total_bars:,}")
            print(f"   Полнота данных:  {data_completeness:.1f}%")

    # 4. Проверяем пропуски в данных
    print(f"\n4. Проверка пропусков в данных (последний день):")

    # Берем последний доступный день
    cursor.execute("""
        SELECT MAX(CAST(barTime as DATE)) as LastDate 
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
    """, ticker_jid)

    last_date_row = cursor.fetchone()
    if last_date_row and last_date_row[0]:
        last_date = last_date_row[0]
        print(f"   Проверяем дату: {last_date}")

        # Проверяем количество баров за последний день
        cursor.execute("""
            SELECT 
                COUNT(*) as ActualBars,
                1440 as ExpectedBars,
                (COUNT(*) * 100.0 / 1440) as CompletenessPercent
            FROM tms.Bars 
            WHERE TickerJID = ? AND TimeFrameID = 1
                AND CAST(barTime as DATE) = ?
        """, ticker_jid, last_date)

        day_stats = cursor.fetchone()
        if day_stats:
            actual, expected, percent = day_stats
            print(f"   Баров в день: {actual} из {expected} ({percent:.1f}%)")

            if actual < expected:
                print(f"   ⚠ Пропущено баров: {expected - actual}")

    # 5. Проверяем качество ценовых данных
    print(f"\n5. Проверка качества ценовых данных:")

    cursor.execute("""
        SELECT 
            COUNT(*) as TotalRows,
            SUM(CASE WHEN openValue IS NULL THEN 1 ELSE 0 END) as NullOpens,
            SUM(CASE WHEN highValue IS NULL THEN 1 ELSE 0 END) as NullHighs,
            SUM(CASE WHEN lowValue IS NULL THEN 1 ELSE 0 END) as NullLows,
            SUM(CASE WHEN closeValue IS NULL THEN 1 ELSE 0 END) as NullCloses,
            SUM(CASE WHEN closeValue <= 0 THEN 1 ELSE 0 END) as ZeroCloses,
            SUM(CASE WHEN highValue < lowValue THEN 1 ELSE 0 END) as HighLowErrors,
            SUM(CASE WHEN highValue < openValue THEN 1 ELSE 0 END) as HighOpenErrors,
            SUM(CASE WHEN highValue < closeValue THEN 1 ELSE 0 END) as HighCloseErrors,
            SUM(CASE WHEN lowValue > openValue THEN 1 ELSE 0 END) as LowOpenErrors,
            SUM(CASE WHEN lowValue > closeValue THEN 1 ELSE 0 END) as LowCloseErrors,
            SUM(CASE WHEN openValue = closeValue AND openValue = highValue AND openValue = lowValue THEN 1 ELSE 0 END) as FlatBars
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
            AND barTime >= DATEADD(DAY, -7, GETDATE())
    """, ticker_jid)

    quality_stats = cursor.fetchone()
    if quality_stats:
        total_rows = quality_stats[0]
        if total_rows > 0:
            print(f"   Проанализировано строк (7 дней): {total_rows:,}")

            issues_found = False

            if quality_stats[1] > 0:
                print(f"   ⚠ Пустые Open:      {quality_stats[1]} ({quality_stats[1]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[2] > 0:
                print(f"   ⚠ Пустые High:      {quality_stats[2]} ({quality_stats[2]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[3] > 0:
                print(f"   ⚠ Пустые Low:       {quality_stats[3]} ({quality_stats[3]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[4] > 0:
                print(f"   ⚠ Пустые Close:     {quality_stats[4]} ({quality_stats[4]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[5] > 0:
                print(f"   ⚠ Close <= 0:       {quality_stats[5]} ({quality_stats[5]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[6] > 0:
                print(f"   ⚠ High < Low:       {quality_stats[6]} ({quality_stats[6]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[7] > 0:
                print(f"   ⚠ High < Open:      {quality_stats[7]} ({quality_stats[7]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[8] > 0:
                print(f"   ⚠ High < Close:     {quality_stats[8]} ({quality_stats[8]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[9] > 0:
                print(f"   ⚠ Low > Open:       {quality_stats[9]} ({quality_stats[9]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[10] > 0:
                print(f"   ⚠ Low > Close:      {quality_stats[10]} ({quality_stats[10]/total_rows*100:.1f}%)")
                issues_found = True
            if quality_stats[11] > 0:
                print(f"   ⚠ Плоские бары:     {quality_stats[11]} ({quality_stats[11]/total_rows*100:.1f}%)")
                issues_found = True

            if not issues_found:
                print(f"   ✓ Все проверки пройдены успешно")

    # 6. Проверяем объем данных по дням
    print(f"\n6. Распределение данных по дням (последние 10 дней):")

    cursor.execute("""
        SELECT TOP 10
            CAST(barTime as DATE) as TradingDate,
            COUNT(*) as BarsCount,
            MIN(closeValue) as MinPrice,
            MAX(closeValue) as MaxPrice,
            AVG(closeValue) as AvgPrice
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
        GROUP BY CAST(barTime as DATE)
        ORDER BY TradingDate DESC
    """, ticker_jid)

    daily_stats = cursor.fetchall()
    for date, count, min_price, max_price, avg_price in daily_stats:
        print(f"   {date}: {count} баров, Цена: ${min_price:,.0f}-${max_price:,.0f} (сред: ${avg_price:,.0f})")

    # 7. Проверяем наличие таблиц индикаторов
    print(f"\n7. Проверка таблиц индикаторов:")

    # Список таблиц для проверки
    tables_to_check = ['tms.EMA', 'tms.Indicators_Momentum']

    for table_name in tables_to_check:
        try:
            cursor.execute(f"SELECT TOP 1 1 FROM {table_name} WHERE TickerJID = ? AND TimeFrameID = 1", ticker_jid)
            result = cursor.fetchone()
            if result:
                print(f"   ✓ Таблица {table_name} существует и содержит данные")
            else:
                print(f"   ⚠ Таблица {table_name} существует, но нет данных для TickerJID={ticker_jid}")
        except Exception:
            print(f"   ✗ Таблица {table_name} не существует или ошибка доступа")

    # 8. Проверяем данные EMA (если таблица существует)
    print(f"\n8. Проверка данных EMA:")

    try:
        cursor.execute("""
            SELECT TOP 5
                e.BarTime,
                b.closeValue as Price,
                e.EMA_5_SHORT as EMA5,
                e.EMA_20_SHORT as EMA20
            FROM tms.EMA e
            INNER JOIN tms.Bars b ON e.BarTime = b.barTime 
                AND e.TickerJID = b.TickerJID 
                AND e.TimeFrameID = b.TimeFrameID
            WHERE e.TickerJID = ? AND e.TimeFrameID = 1
                AND b.closeValue > 0
            ORDER BY e.BarTime DESC
        """, ticker_jid)

        ema_samples = cursor.fetchall()
        if ema_samples:
            print(f"   Примеры EMA данных (последние 5 записей):")
            anomalies_count = 0
            for time, price, ema5, ema20 in ema_samples:
                try:
                    price_float = float(price)
                    ema5_float = float(ema5) if ema5 is not None else 0
                    if ema5 is not None and price_float > 0:
                        diff = abs((price_float - ema5_float) / price_float * 100)
                        if diff > 10:  # Если разница больше 10%
                            print(f"     ⚠ {time}: Price=${price_float:,.2f}, EMA5=${ema5_float:,.2f}, Diff={diff:.1f}%")
                            anomalies_count += 1
                        else:
                            print(f"     ✓ {time}: Price=${price_float:,.2f}, EMA5=${ema5_float:,.2f}, Diff={diff:.1f}%")
                    else:
                        print(f"     ? {time}: Price=${price_float:,.2f}, EMA5={ema5}")
                except Exception as e:
                    print(f"     ! {time}: Ошибка обработки: {str(e)[:30]}")

            if anomalies_count > 0:
                print(f"   ⚠ Найдено аномальных EMA: {anomalies_count}")
            else:
                print(f"   ✓ Аномалий EMA не найдено")
        else:
            print(f"   ⚠ Нет данных EMA для проверки")
    except Exception as e:
        print(f"   ✗ Ошибка при проверке EMA: {str(e)[:50]}")

    # 9. Проверяем последние цены
    print(f"\n9. Текущие данные Bitcoin:")

    cursor.execute("""
        SELECT TOP 1
            barTime,
            openValue,
            highValue,
            lowValue,
            closeValue
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
        ORDER BY barTime DESC
    """, ticker_jid)

    latest_bar = cursor.fetchone()
    if latest_bar:
        time, open_val, high, low, close = latest_bar
        print(f"   Последний бар ({time}):")
        print(f"     Open:  ${open_val:,.2f}")
        print(f"     High:  ${high:,.2f}")
        print(f"     Low:   ${low:,.2f}")
        print(f"     Close: ${close:,.2f}")

        if open_val > 0:
            change = close - open_val
            change_pct = (change / open_val * 100)
            print(f"     Change: ${change:,.2f} ({change_pct:.2f}%)")

    # 10. Проверяем диапазон цен
    print(f"\n10. Общий диапазон цен:")

    cursor.execute("""
        SELECT 
            MIN(closeValue) as MinPrice,
            MAX(closeValue) as MaxPrice,
            AVG(closeValue) as AvgPrice,
            STDEV(closeValue) as StdDev
        FROM tms.Bars 
        WHERE TickerJID = ? AND TimeFrameID = 1
            AND closeValue > 0
    """, ticker_jid)

    price_range = cursor.fetchone()
    if price_range:
        min_price, max_price, avg_price, std_dev = price_range
        print(f"   Минимальная цена:  ${min_price:,.2f}")
        print(f"   Максимальная цена: ${max_price:,.2f}")
        print(f"   Средняя цена:      ${avg_price:,.2f}")
        print(f"   Стандартное отклонение: ${std_dev:,.2f}")

        if max_price > 0:
            volatility = (std_dev / avg_price * 100) if avg_price > 0 else 0
            print(f"   Волатильность:      {volatility:.2f}%")

    # Закрываем соединение
    cursor.close()
    conn.close()

    print(f"\n{'='*70}")
    print("ПРОВЕРКА ЗАВЕРШЕНА")
    print(f"{'='*70}")


if __name__ == "__main__":
    check_bitcoin_data_integrity()
    input("\nНажмите Enter для выхода...")