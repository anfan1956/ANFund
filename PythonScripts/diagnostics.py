# diagnostic.py
import pyodbc
from datetime import datetime, timedelta

CONNECTION_STRING = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=62.181.56.230;'
    'DATABASE=cTrader;'
    'UID=anfan;'
    'PWD=Gisele12!;'
)

TICKER_JID = 13
TIMEFRAME_H1 = 5
TIMEFRAME_M15 = 3


def check_data_quality():
    conn = pyodbc.connect(CONNECTION_STRING)
    cursor = conn.cursor()

    now = datetime.now()
    hour_ago = now - timedelta(hours=1)

    print("=== ДИАГНОСТИКА ДАННЫХ ДЛЯ XAUUSD ===")

    # 1. Проверяем свечи H1
    print("\n1. Последние 3 свечи H1:")
    cursor.execute("""
        SELECT TOP 3 barTime, closeValue 
        FROM tms.bars 
        WHERE TickerJID = ? AND timeframeID = ?
        ORDER BY barTime DESC
    """, (TICKER_JID, TIMEFRAME_H1))

    for row in cursor.fetchall():
        print(f"   Время: {row.barTime}, Close: {row.closeValue}")

    # 2. Проверяем EMA для последней свечи H1
    print("\n2. EMA для последней свечи H1:")
    cursor.execute("""
        SELECT TOP 1 e.BarTime, e.EMA_50_MEDIUM, b.closeValue
        FROM tms.EMA e
        JOIN tms.bars b ON e.TickerJID = b.TickerJID 
            AND e.BarTime = b.barTime 
            AND e.TimeFrameID = b.timeframeID
        WHERE e.TickerJID = ? AND e.TimeFrameID = ?
        ORDER BY e.BarTime DESC
    """, (TICKER_JID, TIMEFRAME_H1))

    ema_h1 = cursor.fetchone()
    if ema_h1:
        print(f"   Время: {ema_h1.BarTime}")
        print(f"   EMA_50: {ema_h1.EMA_50_MEDIUM}")
        print(f"   Close: {ema_h1.closeValue}")
        print(f"   Разница: {ema_h1.closeValue - ema_h1.EMA_50_MEDIUM}")
    else:
        print("   Нет данных EMA H1")

    # 3. Проверяем свечи M15
    print("\n3. Последние 3 свечи M15:")
    cursor.execute("""
        SELECT TOP 3 barTime, lowValue, highValue, closeValue 
        FROM tms.bars 
        WHERE TickerJID = ? AND timeframeID = ?
        ORDER BY barTime DESC
    """, (TICKER_JID, TIMEFRAME_M15))

    for row in cursor.fetchall():
        print(f"   Время: {row.barTime}, Low: {row.lowValue}, High: {row.highValue}, Close: {row.closeValue}")

    # 4. Проверяем EMA для последней свечи M15
    print("\n4. EMA для последней свечи M15:")
    cursor.execute("""
        SELECT TOP 1 e.BarTime, e.EMA_20_SHORT, b.closeValue
        FROM tms.EMA e
        JOIN tms.bars b ON e.TickerJID = b.TickerJID 
            AND e.BarTime = b.barTime 
            AND e.TimeFrameID = b.timeframeID
        WHERE e.TickerJID = ? AND e.TimeFrameID = ?
        ORDER BY e.BarTime DESC
    """, (TICKER_JID, TIMEFRAME_M15))

    ema_m15 = cursor.fetchone()
    if ema_m15:
        print(f"   Время: {ema_m15.BarTime}")
        print(f"   EMA_20: {ema_m15.EMA_20_SHORT}")
        print(f"   Close: {ema_m15.closeValue}")
        print(f"   Разница: {ema_m15.closeValue - ema_m15.EMA_20_SHORT}")
    else:
        print("   Нет данных EMA M15")

    # 5. Проверяем RSI
    print("\n5. RSI за последние 3 свечи M15:")
    cursor.execute("""
        SELECT TOP 3 BarTime, RSI_14, Oversold_Flag, Overbought_Flag
        FROM tms.Indicators_Momentum
        WHERE TickerJID = ? AND TimeFrameID = ?
        ORDER BY BarTime DESC
    """, (TICKER_JID, TIMEFRAME_M15))

    rsi_rows = cursor.fetchall()
    if rsi_rows:
        for row in rsi_rows:
            print(f"   Время: {row.BarTime}, RSI: {row.RSI_14}, Oversold: {row.Oversold_Flag}, Overbought: {row.Overbought_Flag}")
    else:
        print("   Нет данных RSI")

    # 6. Проверяем, когда обновлялись данные
    print("\n6. Время последнего обновления:")
    for table in ['tms.bars', 'tms.EMA', 'tms.Indicators_Momentum']:
        cursor.execute(f"SELECT MAX(barTime) FROM {table} WHERE TickerJID = ?", TICKER_JID)
        max_time = cursor.fetchone()[0]
        print(f"   {table}: {max_time}")

    cursor.close()
    conn.close()


if __name__ == "__main__":
    check_data_quality()