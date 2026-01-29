import pyodbc
from datetime import datetime, time
import pytz
import time as sleep_time
import sys
import argparse
from strategy_termination import StrategyTerminationService
from sp_create_signal import execute_signal_procedure

# Configuration
CONNECTION_STRING = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=62.181.56.230;'
    'DATABASE=cTrader;'
    'UID=anfan;'
    'PWD=Gisele12!;'
)

# Будет инициализировано в main()
termination_service = None

STRATEGY_CONFIGURATION_ID = 3  # ← ЗАМЕНИТЕ НА ВАШ ID из algo.strategy_configurations
TICKER = 'BTCUSD'
TICKER_JID = 13  # ID from ref.assetMasterTable for XAUUSD
OPEN_VOLUME = 0.01  # LOTS for opening
CLOSE_TIME_UTC = time(21, 45)  # 21:45 UTC
BROKER_ID = 2
PLATFORM_ID = 1

# timeframeID from Timeframes table
TIMEFRAME_H1 = 5  # 1 Hour
TIMEFRAME_M1 = 1  # 1 Minute
TIMEFRAME_M15 = 3  # 15 Minutes

# Global variables for caching
last_m1_bar_time = None
last_m15_bar_time = None
last_h1_bar_time = None
position_check_counter = 0
MAX_POSITION_CHECKS = 10  # Maximum attempts to verify position opening
CHECK_INTERVAL_SECONDS = 10  # Seconds between position checks
# Heartbeat tracking
last_heartbeat_time = None  # Для отслеживания времени последнего heartbeat

def update_tracker_state(config_id, state, connection_string):
    """
    Update strategy state in algo.strategyTracker table
    """
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        cursor.execute("""
            EXEC algo.sp_UpdateStrategyState @configID = ?, @currentState = ?
        """, (config_id, state))
        conn.commit()
        cursor.close()
        conn.close()
        print(f"[Tracker] State: {state}")
    except Exception as e:
        print(f"Error updating tracker state: {e}")

# Глобальная переменная для heartbeat
last_heartbeat_time = None

def send_heartbeat(config_id, connection_string):
    """
    Send heartbeat if 60 seconds have passed
    """
    global last_heartbeat_time

    current_utc = datetime.now(pytz.UTC)

    # Если прошло 60 секунд с последнего heartbeat
    if (last_heartbeat_time is None or
            (current_utc - last_heartbeat_time).total_seconds() >= 60):
        update_tracker_state(config_id, 'heartbeat', connection_string)
        last_heartbeat_time = current_utc
        return True

    return False


def get_open_positions(connection_string, ticker):
    """Returns list of open positions for ticker"""
    positions = []
    try:
        conn = pyodbc.connect(connection_string)
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
                'direction': row.direction.strip(),  # 'Buy' or 'Sell'
                'volume': float(row.volume)  # in units for closing
            })

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Error getting positions: {e}")

    return positions


def get_current_price(connection_string, ticker_jid):
    """Gets current price from latest M1 candle"""
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        sql = """
        SELECT TOP 1 barTime, closeValue
        FROM tms.bars
        WHERE TickerJID = ? AND timeframeID = 1
        ORDER BY barTime DESC
        """
        cursor.execute(sql, (ticker_jid,))
        price_data = cursor.fetchone()

        cursor.close()
        conn.close()

        if price_data:
            return {
                'price': float(price_data.closeValue),
                'time': price_data.barTime
            }
        return None

    except Exception as e:
        print(f"Error getting price: {e}")
        return None


def get_market_info(connection_string, ticker, ticker_jid, close_time_utc):
    """Gets market information for display"""
    info = {
        'price': 'N/A',
        'price_time': None,
        'positions_count': 0,
        'position_direction': 'NONE',
        'position_id': 'NONE',
        'm1_signal': 'NO_SIGNAL',
        'm15_signal': 'NO_SIGNAL',
        'h1_trend': 'NO_DATA',
        'time_to_close': 'N/A'
    }

    try:
        current_utc = datetime.now(pytz.UTC)

        # Get current price
        price_info = get_current_price(connection_string, ticker_jid)
        if price_info:
            info['price'] = f"{price_info['price']:.2f}"
            info['price_time'] = price_info['time']

        # Get positions
        positions = get_open_positions(connection_string, ticker)
        if positions:
            info['positions_count'] = len(positions)
            if len(positions) > 0:
                info['position_direction'] = positions[0]['direction']
                info['position_id'] = str(positions[0]['id'])

        # Calculate time until force close
        current_time = current_utc.time()
        if current_time < close_time_utc:
            current_dt = current_utc
            close_dt = current_utc.replace(hour=close_time_utc.hour, minute=close_time_utc.minute, second=0)
            if close_dt < current_dt:
                close_dt = close_dt.replace(day=close_dt.day + 1)

            time_diff = close_dt - current_dt
            hours, remainder = divmod(time_diff.seconds, 3600)
            minutes, seconds = divmod(remainder, 60)
            info['time_to_close'] = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
        else:
            info['time_to_close'] = "TIME_PASSED"

    except Exception as e:
        print(f"Error getting market info: {e}")

    return info


def show_minute_info(ticker, market_info, m1_signal, m15_signal, h1_trend):
    """Shows information every minute"""
    try:
        current_utc = datetime.now(pytz.UTC)

        # Format signals
        m1_signal_str = 'NO_SIGNAL' if m1_signal is None else m1_signal.upper()
        m15_signal_str = 'NO_SIGNAL' if m15_signal is None else m15_signal.upper()
        h1_trend_str = 'NO_DATA' if h1_trend is None else h1_trend.upper()

        # Format position info
        if market_info['positions_count'] > 0:
            pos_str = f"ID:{market_info['position_id']} {market_info['position_direction']}"
        else:
            pos_str = "NO_POSITION"

        # Print formatted line
        print(f"[{current_utc.strftime('%H:%M:%S')}] {ticker}: {market_info['price']} | "
              f"Pos: {pos_str} | "
              f"M1: {m1_signal_str} | M15: {m15_signal_str} | H1: {h1_trend_str} | "
              f"Close: {market_info['time_to_close']}")

    except Exception as e:
        print(f"Error showing info: {e}")


def wait_for_position_confirmation(connection_string, ticker, expected_direction='Buy', max_checks=10, check_interval_seconds=2):
    """Waits for position to appear in the database after opening"""
    print(f"Waiting for position confirmation...")

    for check in range(max_checks):
        sleep_time.sleep(check_interval_seconds)

        positions = get_open_positions(connection_string, ticker)
        if positions:
            pos = positions[0]
            print(f"Position confirmed: ID={pos['id']}, Direction={pos['direction']}")
            return positions[0]

        print(f"  Check {check + 1}/{max_checks}: Position not yet confirmed...")

    print("Warning: Position not confirmed after maximum checks")
    return None


def open_initial_position(connection_string, ticker, open_volume, broker_id, platform_id, strategy_configuration_id, max_checks=10, check_interval_seconds=10):
    """Opens initial BUY position on startup with confirmation"""
    print(f"\nOpening initial BUY position for {ticker}")
    print(f"Volume: {open_volume} lots")

    # Send open signal
    execute_signal_procedure(
        connection_string=connection_string,
        ticker=ticker,
        direction='buy',
        volume=open_volume,
        order_price=None,
        stop_loss=None,
        take_profit=None,
        expiry=None,
        broker_id=broker_id,
        platform_id=platform_id,
        trade_id=None,
        trade_type=None,
        strategy_configuration_id=strategy_configuration_id
    )

    # Wait for position to appear in database
    position = wait_for_position_confirmation(connection_string, ticker, 'Buy', max_checks, check_interval_seconds)

    if position:
        print(f"Initial position opened successfully")
        print(f"  Position ID: {position['id']}")
        return position
    else:
        print("Failed to open initial position")
        return None


def ensure_single_position(connection_string, ticker, broker_id, platform_id, strategy_configuration_id):
    """Ensures only one position exists for the ticker"""
    positions = get_open_positions(connection_string, ticker)

    if len(positions) > 1:
        print(f"WARNING: Multiple positions found ({len(positions)})!")
        # Keep only the latest position, close others
        latest_position = max(positions, key=lambda x: x['id'])

        for pos in positions:
            if pos['id'] != latest_position['id']:
                print(f"Closing duplicate position ID={pos['id']}")
                execute_signal_procedure(
                    connection_string=connection_string,
                    ticker=ticker,
                    direction='drop',
                    volume=pos['volume'],
                    order_price=None,
                    stop_loss=None,
                    take_profit=None,
                    expiry=None,
                    broker_id=broker_id,
                    platform_id=platform_id,
                    trade_id=pos['id'],
                    trade_type='POSITION',
                    strategy_configuration_id=strategy_configuration_id
                )
                sleep_time.sleep(1)  # Wait for close

        return [latest_position]

    return positions


def get_latest_bar_data(connection_string, ticker_jid, timeframe_id, timeframe_name="Unknown"):
    """Gets latest candle and indicator data"""
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        # Get latest candle
        sql_bar = """
        SELECT TOP 1 barTime, openValue, highValue, lowValue, closeValue
        FROM tms.bars
        WHERE TickerJID = ? AND timeframeID = ?
        ORDER BY barTime DESC
        """
        cursor.execute(sql_bar, (ticker_jid, timeframe_id))
        bar = cursor.fetchone()

        if not bar:
            return None

        # Get EMA for this candle
        sql_ema = """
        SELECT TOP 1 BarTime, EMA_50_MEDIUM, EMA_20_SHORT
        FROM tms.EMA
        WHERE TickerJID = ? AND TimeFrameID = ? AND BarTime = ?
        ORDER BY BarTime DESC
        """
        cursor.execute(sql_ema, (ticker_jid, timeframe_id, bar.barTime))
        ema = cursor.fetchone()

        # Get RSI for this and previous candle
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
            'prev_rsi': prev_rsi,
            'timeframe_name': timeframe_name
        }

    except Exception as e:
        print(f"Error getting data TF={timeframe_name}: {e}")
        return None


def check_trend_h1(connection_string, ticker_jid, timeframe_h1):
    """Checks trend on H1"""
    global last_h1_bar_time

    data = get_latest_bar_data(connection_string, ticker_jid, timeframe_h1, "H1")

    if not data or not data['bar'] or not data['ema']:
        return None

    current_bar_time = data['bar'].barTime

    if last_h1_bar_time and last_h1_bar_time == current_bar_time:
        return 'cached'

    last_h1_bar_time = current_bar_time

    close_h1 = float(data['bar'].closeValue)

    if hasattr(data['ema'].EMA_50_MEDIUM, 'as_tuple'):
        ema50_h1 = float(data['ema'].EMA_50_MEDIUM)
    else:
        ema50_h1 = data['ema'].EMA_50_MEDIUM

    if close_h1 > ema50_h1:
        return 'bullish'
    elif close_h1 < ema50_h1:
        return 'bearish'
    else:
        return None


def check_signal_m1(connection_string, ticker_jid, timeframe_m1):
    """Checks signal on M1"""
    global last_m1_bar_time

    data = get_latest_bar_data(connection_string, ticker_jid, timeframe_m1, "M1")

    if not data or not data['bar'] or not data['ema']:
        return None

    current_bar_time = data['bar'].barTime

    if last_m1_bar_time and last_m1_bar_time == current_bar_time:
        return None

    last_m1_bar_time = current_bar_time

    low_m1 = float(data['bar'].lowValue)
    high_m1 = float(data['bar'].highValue)

    if hasattr(data['ema'].EMA_20_SHORT, 'as_tuple'):
        ema20_m1 = float(data['ema'].EMA_20_SHORT)
    else:
        ema20_m1 = data['ema'].EMA_20_SHORT

    if data['prev_rsi'] and data['current_rsi']:
        prev_oversold = bool(data['prev_rsi'].Oversold_Flag)
        curr_oversold = bool(data['current_rsi'].Oversold_Flag)
        prev_overbought = bool(data['prev_rsi'].Overbought_Flag)
        curr_overbought = bool(data['current_rsi'].Overbought_Flag)

        if low_m1 <= ema20_m1 and prev_oversold and not curr_oversold:
            return 'buy'

        if high_m1 >= ema20_m1 and prev_overbought and not curr_overbought:
            return 'sell'

    return None


def check_signal_m15(connection_string, ticker_jid, timeframe_m15):
    """Checks signal on M15"""
    global last_m15_bar_time

    data = get_latest_bar_data(connection_string, ticker_jid, timeframe_m15, "M15")

    if not data or not data['bar'] or not data['ema']:
        return None

    current_bar_time = data['bar'].barTime

    if last_m15_bar_time and last_m15_bar_time == current_bar_time:
        return None

    last_m15_bar_time = current_bar_time

    low_m15 = float(data['bar'].lowValue)
    high_m15 = float(data['bar'].highValue)

    if hasattr(data['ema'].EMA_20_SHORT, 'as_tuple'):
        ema20_m15 = float(data['ema'].EMA_20_SHORT)
    else:
        ema20_m15 = data['ema'].EMA_20_SHORT

    if data['prev_rsi'] and data['current_rsi']:
        prev_oversold = bool(data['prev_rsi'].Oversold_Flag)
        curr_oversold = bool(data['current_rsi'].Oversold_Flag)
        prev_overbought = bool(data['prev_rsi'].Overbought_Flag)
        curr_overbought = bool(data['current_rsi'].Overbought_Flag)

        if low_m15 <= ema20_m15 and prev_oversold and not curr_oversold:
            return 'buy'

        if high_m15 >= ema20_m15 and prev_overbought and not curr_overbought:
            return 'sell'

    return None


def check_force_close(connection_string, ticker, close_time_utc, broker_id, platform_id, strategy_configuration_id):
    """Checks and executes forced close at specified UTC time"""
    current_utc = datetime.now(pytz.UTC)
    current_time = current_utc.time()

    if current_time >= close_time_utc:
        positions = get_open_positions(connection_string, ticker)

        if positions:
            pos = positions[0]
            print(f"\n=== FORCE CLOSE at {current_time} ===")
            print(f"Closing position ID={pos['id']}")

            execute_signal_procedure(
                connection_string=connection_string,
                ticker=ticker,
                direction='drop',
                volume=pos['volume'],
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=broker_id,
                platform_id=platform_id,
                trade_id=pos['id'],
                trade_type='POSITION',
                strategy_configuration_id=strategy_configuration_id
            )

            # Wait for close confirmation
            sleep_time.sleep(1)

            # Verify position closed
            positions_after = get_open_positions(connection_string, ticker)
            if not positions_after:
                print("✓ Position successfully closed")
            else:
                print("✗ Position still open, trying again...")

            return True

    return False


def process_trading_signal(connection_string, ticker, open_volume, broker_id, platform_id, strategy_configuration_id,
                          m1_signal, m15_signal, h1_trend, positions):
    """Process trading signal if conditions are met"""
    # Determine final signal
    signal = None

    if m1_signal and m15_signal:
        if m1_signal == m15_signal:
            signal = m1_signal
    elif m1_signal:
        signal = m1_signal

    if not signal:
        return False

    # Filter signal by H1 trend if available
    if h1_trend and h1_trend != 'cached':
        if (h1_trend == 'bullish' and signal != 'buy') or (h1_trend == 'bearish' and signal != 'sell'):
            return False

    # Position management
    if not positions:
        return False

    pos = positions[0]
    current_dir = 'buy' if pos['direction'] == 'Buy' else 'sell'

    if current_dir != signal:
        # Execute reversal
        print(f"\n  === EXECUTING REVERSAL ===")
        print(f"  Current: {current_dir.upper()}, New: {signal.upper()}")

        # Close current position
        print(f"  Closing position ID={pos['id']}")
        execute_signal_procedure(
            connection_string=connection_string,
            ticker=ticker,
            direction='drop',
            volume=pos['volume'],
            order_price=None,
            stop_loss=None,
            take_profit=None,
            expiry=None,
            broker_id=broker_id,
            platform_id=platform_id,
            trade_id=pos['id'],
            trade_type='POSITION',
            strategy_configuration_id=strategy_configuration_id
        )

        # Wait for close confirmation
        sleep_time.sleep(1)

        # Open new position
        print(f"  Opening {signal.upper()} position")
        execute_signal_procedure(
            connection_string=connection_string,
            ticker=ticker,
            direction=signal,
            volume=open_volume,
            order_price=None,
            stop_loss=None,
            take_profit=None,
            expiry=None,
            broker_id=broker_id,
            platform_id=platform_id,
            trade_id=None,
            trade_type=None,
            strategy_configuration_id=strategy_configuration_id
        )

        return True

    return False


def run_strategy(connection_string, ticker, ticker_jid, open_volume, close_time_utc,
                 broker_id, platform_id, strategy_configuration_id,
                 timeframe_h1, timeframe_m1, timeframe_m15,
                 max_position_checks, check_interval_seconds):
    """
    Main strategy logic - called every minute
    Returns: True if strategy should terminate, False otherwise
    """
    # Используем глобальную переменную для heartbeat
    global last_heartbeat_time

    # ========== ПРОВЕРКА ЗАВЕРШЕНИЯ ==========
    termination_info = termination_service.check_my_termination(strategy_configuration_id)
    if termination_info:
        print(f"[Termination] Strategy {strategy_configuration_id} termination requested at {termination_info['requested_at']}")
        print(f"[Termination] Termination ID: {termination_info['termination_id']}")

        # 1. Обновить статус в tracker
        update_tracker_state(strategy_configuration_id, 'terminating', connection_string)

        # 2. Закрыть все открытые позиции
        positions = get_open_positions(connection_string, ticker)
        if positions:
            print(f"[Termination] Closing {len(positions)} open position(s)...")

            # Список ID позиций, которые нужно закрыть
            positions_to_close = [(pos['id'], pos['direction'], pos['volume']) for pos in positions]

            # Закрыть каждую позицию
            for pos_id, direction, volume in positions_to_close:
                print(f"  Closing position ID={pos_id} (Direction: {direction})")
                execute_signal_procedure(
                    connection_string=connection_string,
                    ticker=ticker,
                    direction='drop',
                    volume=volume,
                    order_price=None,
                    stop_loss=None,
                    take_profit=None,
                    expiry=None,
                    broker_id=broker_id,
                    platform_id=platform_id,
                    trade_id=pos_id,
                    trade_type='POSITION',
                    strategy_configuration_id=strategy_configuration_id
                )

            # Подождать и проверить, что позиции закрылись
            sleep_time.sleep(1)

            # Проверить, остались ли открытые позиции
            remaining_positions = get_open_positions(connection_string, ticker)
            if remaining_positions:
                print(f"[Warning] {len(remaining_positions)} position(s) still open after close attempt")
                # Попробовать закрыть еще раз
                for pos in remaining_positions:
                    print(f"  Retry closing position ID={pos['id']}")
                    execute_signal_procedure(
                        connection_string=connection_string,
                        ticker=ticker,
                        direction='drop',
                        volume=pos['volume'],
                        order_price=None,
                        stop_loss=None,
                        take_profit=None,
                        expiry=None,
                        broker_id=broker_id,
                        platform_id=platform_id,
                        trade_id=pos['id'],
                        trade_type='POSITION',
                        strategy_configuration_id=strategy_configuration_id
                    )

                sleep_time.sleep(1)

                # Финальная проверка
                final_positions = get_open_positions(connection_string, ticker)
                if final_positions:
                    print(f"[Error] {len(final_positions)} position(s) could not be closed")
                    for pos in final_positions:
                        print(f"  Still open: ID={pos['id']}, Direction={pos['direction']}")
                else:
                    print("[Termination] All positions successfully closed on retry")
            else:
                print("[Termination] All positions successfully closed")

        # 3. Пометить запрос на завершение как выполненный
        termination_service.mark_completed(termination_info['termination_id'])

        # 4. Обновить tracker как завершенный
        update_tracker_state(strategy_configuration_id, 'terminated', connection_string)

        print(f"\n{'=' * 70}")
        print(f"[Termination] Strategy {strategy_configuration_id} terminated successfully")
        print(f"Exiting program...")
        print(f"{'=' * 70}")

        # ЗАВЕРШАЕМ ПРОГРАММУ ПОЛНОСТЬЮ
        sys.exit(0)

    current_utc = datetime.now(pytz.UTC)
    current_minute = current_utc.minute

    # 0. Send heartbeat if needed
    send_heartbeat(strategy_configuration_id, connection_string)

    # 1. Check force close time
    if check_force_close(connection_string, ticker, close_time_utc, broker_id, platform_id, strategy_configuration_id):
        return True  # Вернуть True для остановки

    # 2. Get market info
    market_info = get_market_info(connection_string, ticker, ticker_jid, close_time_utc)

    # 3. Check signals
    m1_signal = check_signal_m1(connection_string, ticker_jid, timeframe_m1)

    m15_signal = None
    if current_minute % 15 == 0:
        m15_signal = check_signal_m15(connection_string, ticker_jid, timeframe_m15)

    h1_trend = None
    if current_minute % 5 == 0:
        h1_trend = check_trend_h1(connection_string, ticker_jid, timeframe_h1)

    # 4. Show info every minute
    show_minute_info(ticker, market_info, m1_signal, m15_signal, h1_trend)

    # 5. Ensure single position
    positions = ensure_single_position(connection_string, ticker, broker_id, platform_id, strategy_configuration_id)

    # 6. Process trading signal if we have a position
    if positions and len(positions) > 0:
        trade_executed = process_trading_signal(
            connection_string, ticker, open_volume, broker_id, platform_id, strategy_configuration_id,
            m1_signal, m15_signal, h1_trend, positions
        )
        if trade_executed:
            # After trading, show updated info
            sleep_time.sleep(1)
            updated_info = get_market_info(connection_string, ticker, ticker_jid, close_time_utc)
            show_minute_info(ticker, updated_info, 'TRADED', 'TRADED', h1_trend)

    return False  # Вернуть False для продолжения работы

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Trading Strategy')
    parser.add_argument('--config-id', type=int, help='Configuration ID from database')
    args = parser.parse_args()

    # Set variables based on config-id
    if args.config_id:
        print(f"=== Using config ID: {args.config_id} ===")
        STRATEGY_CONFIGURATION_ID = args.config_id

        # For testing - use BTCUSD for config_id = 3
        if args.config_id == 3:
            TICKER = 'BTCUSD'
            TICKER_JID = 56
            OPEN_VOLUME = 0.05
            CLOSE_TIME_UTC = time(22, 0)
        else:
            # Default to XAUUSD for other config_ids
            TICKER = 'XAUUSD'
            TICKER_JID = 13
            OPEN_VOLUME = 0.01
            CLOSE_TIME_UTC = time(21, 45)
    else:
        # Default values for backward compatibility
        STRATEGY_CONFIGURATION_ID = 1
        TICKER = 'XAUUSD'
        TICKER_JID = 13
        OPEN_VOLUME = 0.01
        CLOSE_TIME_UTC = time(21, 45)

    # Connection string
    CONNECTION_STRING = (
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=62.181.56.230;'
        'DATABASE=cTrader;'
        'UID=anfan;'
        'PWD=Gisele12!;'
    )

    # Other constants
    BROKER_ID = 2
    PLATFORM_ID = 1
    TIMEFRAME_H1 = 5
    TIMEFRAME_M1 = 1
    TIMEFRAME_M15 = 3
    MAX_POSITION_CHECKS = 10
    CHECK_INTERVAL_SECONDS = 5
    # Инициализация сервиса завершения стратегий
    global termination_service
    termination_service = StrategyTerminationService(CONNECTION_STRING)

    print("=" * 70)
    print(f"{TICKER} Trading Strategy - Resident Mode")
    print("=" * 70)
    print(f"Config ID: {STRATEGY_CONFIGURATION_ID}")
    print(f"Ticker: {TICKER}")
    print(f"Volume: {OPEN_VOLUME} lots")
    print(f"Daily Close: {CLOSE_TIME_UTC} UTC")
    print("Press Ctrl+C to stop")
    print("=" * 70)

    # ДОБАВИТЬ ЭТУ СТРОЧКУ: START tracking
    update_tracker_state(STRATEGY_CONFIGURATION_ID, 'start', CONNECTION_STRING)


    # Initial setup
    try:
        # Check existing positions
        positions = get_open_positions(CONNECTION_STRING, TICKER)

        if not positions:
            print("\nNo existing position found.")
            print("Opening initial position...")
            position = open_initial_position(
                connection_string=CONNECTION_STRING,
                ticker=TICKER,
                open_volume=OPEN_VOLUME,
                broker_id=BROKER_ID,
                platform_id=PLATFORM_ID,
                strategy_configuration_id=STRATEGY_CONFIGURATION_ID,
                max_checks=MAX_POSITION_CHECKS,
                check_interval_seconds=CHECK_INTERVAL_SECONDS
            )

            if not position:
                print("Failed to open initial position. Exiting.")
                return
        else:
            print(f"\nExisting position found:")
            for pos in positions:
                print(f"  ID: {pos['id']}, Direction: {pos['direction']}")

            if len(positions) > 1:
                print("Cleaning up duplicate positions...")
                positions = ensure_single_position(
                    connection_string=CONNECTION_STRING,
                    ticker=TICKER,
                    broker_id=BROKER_ID,
                    platform_id=PLATFORM_ID,
                    strategy_configuration_id=STRATEGY_CONFIGURATION_ID
                )

    except Exception as e:
        print(f"Initialization error: {e}")
        return

    print("\n" + "=" * 70)
    print("Strategy monitoring started")
    print("=" * 70)

    iteration = 0

    try:
        while True:
            iteration += 1

            # Run strategy every minute - i think i changed that
            try:
                # Теперь run_strategy возвращает True если нужно завершить стратегию
                should_terminate = run_strategy(
                    connection_string=CONNECTION_STRING,
                    ticker=TICKER,
                    ticker_jid=TICKER_JID,
                    open_volume=OPEN_VOLUME,
                    close_time_utc=CLOSE_TIME_UTC,
                    broker_id=BROKER_ID,
                    platform_id=PLATFORM_ID,
                    strategy_configuration_id=STRATEGY_CONFIGURATION_ID,
                    timeframe_h1=TIMEFRAME_H1,
                    timeframe_m1=TIMEFRAME_M1,
                    timeframe_m15=TIMEFRAME_M15,
                    max_position_checks=MAX_POSITION_CHECKS,
                    check_interval_seconds=CHECK_INTERVAL_SECONDS
                )

                # Если стратегия вернула True - значит нужно завершить работу
                if should_terminate:
                    print(f"\n{'=' * 70}")
                    print(f"Strategy {STRATEGY_CONFIGURATION_ID} terminated by termination request")
                    print(f"{'=' * 70}")
                    break  # Выходим из главного цикла

            except Exception as e:
                print(f"Error in strategy: {e}")
                # Continue despite errors

            # Wait for next minute
            now = datetime.now(pytz.UTC)
            seconds_until_next_minute = 60 - now.second
            sleep_time.sleep(max(1, seconds_until_next_minute))

        # ====== НОРМАЛЬНОЕ ЗАВЕРШЕНИЕ (после выхода из цикла) ======
        print("\n\n" + "=" * 70)
        print(f"Strategy {STRATEGY_CONFIGURATION_ID} completed successfully")
        print("=" * 70)

        # Обновить tracker с состоянием 'completed'
        update_tracker_state(STRATEGY_CONFIGURATION_ID, 'completed', CONNECTION_STRING)

        # Финальная проверка позиций
        positions = get_open_positions(CONNECTION_STRING, TICKER)
        if positions:
            print(f"\nFinal position status:")
            for pos in positions:
                print(f"  ID: {pos['id']}, Direction: {pos['direction']}, Volume: {pos['volume']}")
        else:
            print("\nNo open positions")

        print("\nExiting...")
        sys.exit(0)

    except KeyboardInterrupt:
        print("\n\n" + "=" * 70)
        print("Strategy stopped by user")
        print("=" * 70)

        # ДОБАВИТЬ ЭТУ СТРОЧКУ: STOP tracking
        update_tracker_state(STRATEGY_CONFIGURATION_ID, 'stop', CONNECTION_STRING)

        # Final position status
        positions = get_open_positions(CONNECTION_STRING, TICKER)
        if positions:
            print(f"\nFinal position status:")
            for pos in positions:
                print(f"  ID: {pos['id']}, Direction: {pos['direction']}, Volume: {pos['volume']}")
        else:
            print("\nNo open positions")

        print("\nExiting...")
        sys.exit(0)


if __name__ == "__main__":
    main()