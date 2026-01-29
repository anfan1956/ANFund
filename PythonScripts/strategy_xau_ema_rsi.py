import pyodbc
from datetime import datetime, time
import pytz

# Конфигурация
CONNECTION_STRING = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=62.181.56.230;'
    'DATABASE=cTrader;'
    'UID=anfan;'
    'PWD=Gisele12!;'
)

TICKER = 'XAUUSD'
TICKER_JID = 13  # ID из ref.assetMasterTable для XAUUSD
OPEN_VOLUME = 0.01  # лоты
CLOSE_TIME_UTC = time(21, 45)  # 21:45 UTC
BROKER_ID = 2
PLATFORM_ID = 1

# timeframeID из таблицы Timeframes
TIMEFRAME_H1 = 5  # 1 Hour
TIMEFRAME_M15 = 3  # 15 Minutes

# Импорт функции из sp_create_signal.py
from sp_create_signal import execute_signal_procedure


def get_open_positions(ticker):
    """Возвращает список открытых позиций по тикеру"""
    positions = []
    try:
        conn = pyodbc.connect(CONNECTION_STRING)
        cursor = conn.cursor()

        sql = """
        SELECT ID, direction, volume
        FROM trd.trades_v
        WHERE ticker = ? AND tradeType = 'POSITION'
        """

        cursor.execute(sql, (ticker,))

        for row in cursor.fetchall():
            positions.append({
                'id': row.ID,
                'direction': row.direction.strip(),  # 'Buy' или 'Sell'
                'volume': float(row.volume)  # в единицах
            })

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Ошибка получения позиций: {e}")

    return positions


def get_latest_bar_data(ticker_jid, timeframe_id):
    """Получает последние данные свечи и индикаторов"""
    try:
        conn = pyodbc.connect(CONNECTION_STRING)
        cursor = conn.cursor()

        # Получаем последнюю свечу
        sql_bar = """
        SELECT TOP 1 barTime, openValue, highValue, lowValue, closeValue
        FROM tms.bars
        WHERE TickerJID = ? AND timeframeID = ?
        ORDER BY barTime DESC
        """
        cursor.execute(sql_bar, (ticker_jid, timeframe_id))
        bar = cursor.fetchone()

        if not bar:
            print(f"Нет данных свечей для TickerJID={ticker_jid}, timeframeID={timeframe_id}")
            cursor.close()
            conn.close()
            return None

        print(f"\n=== ОТЛАДКА timeframeID={timeframe_id} ===")
        print(f"Последняя свеча - BarTime: {bar.barTime}, Close: {bar.closeValue}")

        # Получаем EMA для этой свечи
        sql_ema = """
        SELECT TOP 1 BarTime, EMA_50_MEDIUM, EMA_20_SHORT
        FROM tms.EMA
        WHERE TickerJID = ? AND TimeFrameID = ? AND BarTime = ?
        ORDER BY BarTime DESC
        """
        cursor.execute(sql_ema, (ticker_jid, timeframe_id, bar.barTime))
        ema = cursor.fetchone()

        if ema:
            print(f"Найдена EMA для BarTime={bar.barTime}:")
            print(f"  EMA BarTime: {ema.BarTime}")
            print(f"  EMA_50: {ema.EMA_50_MEDIUM}")
            print(f"  EMA_20: {ema.EMA_20_SHORT}")
        else:
            print(f"Нет точного совпадения EMA для BarTime={bar.barTime}")

            # Проверим последнюю доступную EMA
            cursor.execute("""
                SELECT TOP 1 BarTime, EMA_50_MEDIUM, EMA_20_SHORT
                FROM tms.EMA
                WHERE TickerJID = ? AND TimeFrameID = ?
                ORDER BY BarTime DESC
            """, (ticker_jid, timeframe_id))
            last_ema = cursor.fetchone()
            if last_ema:
                print(f"Последняя доступная EMA:")
                print(f"  BarTime: {last_ema.BarTime}")
                print(f"  EMA_50: {last_ema.EMA_50_MEDIUM}")
                print(f"  EMA_20: {last_ema.EMA_20_SHORT}")

        # Получаем RSI для этой и предыдущей свечи
        sql_rsi = """
        SELECT TOP 2 BarTime, RSI_14, Oversold_Flag, Overbought_Flag
        FROM tms.Indicators_Momentum
        WHERE TickerJID = ? AND TimeFrameID = ?
        ORDER BY BarTime DESC
        """
        cursor.execute(sql_rsi, (ticker_jid, timeframe_id))
        rsi_rows = cursor.fetchall()

        cursor.close()
        conn.close()

        current_rsi = rsi_rows[0] if len(rsi_rows) > 0 else None
        prev_rsi = rsi_rows[1] if len(rsi_rows) > 1 else None

        return {
            'bar': bar,
            'ema': ema,
            'current_rsi': current_rsi,
            'prev_rsi': prev_rsi
        }

    except Exception as e:
        print(f"Ошибка получения данных: {e}")
        return None


def check_trend_h1():
    """Проверяет тренд на H1"""
    data = get_latest_bar_data(TICKER_JID, TIMEFRAME_H1)

    if not data or not data['bar'] or not data['ema']:
        print("Нет данных H1 для анализа тренда")
        return None

    close_h1 = float(data['bar'].closeValue)

    # Конвертируем decimal в float
    if hasattr(data['ema'].EMA_50_MEDIUM, 'as_tuple'):
        ema50_h1 = float(data['ema'].EMA_50_MEDIUM)
    else:
        ema50_h1 = data['ema'].EMA_50_MEDIUM

    print(f"H1: Close={close_h1}, EMA50={ema50_h1}")

    if close_h1 > ema50_h1:
        return 'bullish'
    elif close_h1 < ema50_h1:
        return 'bearish'
    else:
        return None


def check_signal_m15():
    """Проверяет сигнал на M15"""
    data = get_latest_bar_data(TICKER_JID, TIMEFRAME_M15)

    if not data or not data['bar'] or not data['ema']:
        print("Нет данных M15 для анализа сигнала")
        return None

    low_m15 = float(data['bar'].lowValue)
    high_m15 = float(data['bar'].highValue)

    # Конвертируем decimal в float
    if hasattr(data['ema'].EMA_20_SHORT, 'as_tuple'):
        ema20_m15 = float(data['ema'].EMA_20_SHORT)
    else:
        ema20_m15 = data['ema'].EMA_20_SHORT

    print(f"M15: Low={low_m15}, High={high_m15}, EMA20={ema20_m15}")

    # Проверяем условия для BUY
    if data['prev_rsi'] and data['current_rsi']:
        print(f"RSI: prev Oversold={data['prev_rsi'].Oversold_Flag}, current Oversold={data['current_rsi'].Oversold_Flag}")
        print(f"RSI: prev Overbought={data['prev_rsi'].Overbought_Flag}, current Overbought={data['current_rsi'].Overbought_Flag}")

        if (low_m15 <= ema20_m15 and
                data['prev_rsi'].Oversold_Flag == 1 and
                data['current_rsi'].Oversold_Flag == 0):
            return 'buy'

        # Проверяем условия для SELL
        if (high_m15 >= ema20_m15 and
                data['prev_rsi'].Overbought_Flag == 1 and
                data['current_rsi'].Overbought_Flag == 0):
            return 'sell'

    return None


def run_strategy():
    """Основная логика стратегии"""
    current_utc = datetime.now(pytz.UTC)
    current_time = current_utc.time()

    print(f"[{current_utc.strftime('%Y-%m-%d %H:%M:%S')}] Проверка стратегии для {TICKER}")

    # 1. Проверяем время на принудительное закрытие
    if current_time >= CLOSE_TIME_UTC:
        print(f"Время {current_time} >= {CLOSE_TIME_UTC} UTC - проверяем закрытие")
        positions = get_open_positions(TICKER)

        if positions:
            pos = positions[0]
            print(f"Закрываем позицию ID={pos['id']}, volume={pos['volume']}")

            execute_signal_procedure(
                connection_string=CONNECTION_STRING,
                ticker=TICKER,
                direction='drop',
                volume=pos['volume'],
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=BROKER_ID,
                platform_id=PLATFORM_ID,
                trade_id=pos['id'],
                trade_type='POSITION'
            )
        else:
            print("Нет открытых позиций для закрытия")

        return

    # 2. Получаем текущие позиции
    positions = get_open_positions(TICKER)
    has_position = len(positions) > 0

    if has_position:
        print(f"Есть открытая позиция: {positions[0]['direction']}, ID={positions[0]['id']}")

    # 3. Проверяем тренд H1
    trend = check_trend_h1()
    if not trend:
        print("Тренд H1 не определен")
        return

    print(f"Тренд H1: {'бычий' if trend == 'bullish' else 'медвежий'}")

    # 4. Проверяем сигнал M15
    signal = check_signal_m15()
    if not signal:
        print("Сигнал M15 не сформирован")
        return

    print(f"Сигнал M15: {signal}")

    # 5. Фильтруем сигнал по тренду
    if (trend == 'bullish' and signal != 'buy') or (trend == 'bearish' and signal != 'sell'):
        print(f"Сигнал {signal} не соответствует тренду {trend} - пропускаем")
        return

    # 6. Логика управления позициями
    if has_position:
        pos = positions[0]
        current_dir = 'buy' if pos['direction'] == 'Buy' else 'sell'

        # Проверяем на разворот
        if current_dir != signal:
            print(f"Разворот: текущая позиция {current_dir}, новый сигнал {signal}")

            # Закрываем текущую позицию
            execute_signal_procedure(
                connection_string=CONNECTION_STRING,
                ticker=TICKER,
                direction='drop',
                volume=pos['volume'],
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=BROKER_ID,
                platform_id=PLATFORM_ID,
                trade_id=pos['id'],
                trade_type='POSITION'
            )

            # Открываем новую в противоположном направлении
            execute_signal_procedure(
                connection_string=CONNECTION_STRING,
                ticker=TICKER,
                direction=signal,
                volume=OPEN_VOLUME,
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=BROKER_ID,
                platform_id=PLATFORM_ID,
                trade_id=None,
                trade_type=None
            )
        else:
            print(f"Позиция уже открыта в направлении {signal} - ничего не делаем")

    else:
        # Открываем новую позицию
        print(f"Открываем новую позицию {signal} объемом {OPEN_VOLUME} лотов")

        execute_signal_procedure(
            connection_string=CONNECTION_STRING,
            ticker=TICKER,
            direction=signal,
            volume=OPEN_VOLUME,
            order_price=None,
            stop_loss=None,
            take_profit=None,
            expiry=None,
            broker_id=BROKER_ID,
            platform_id=PLATFORM_ID,
            trade_id=None,
            trade_type=None
        )


if __name__ == "__main__":
    run_strategy()