"""
MTF RSI EMA Strategy
Multi-Timeframe RSI and EMA trading strategy
Follows the architecture from Technical Specification
"""

import json
import time        # FUNCTION: Sleep and timing operations
import sys         # FUNCTION: System-specific parameters and functions
import os          # MODULE: Operating system interfaces
import pyodbc      # MODULE: Database connection for SQL Server
import pytz        # MODULE: Timezone handling
from datetime import datetime, time as time_type, timedelta  # CLASS: Date and time manipulation
import argparse    # MODULE: Command line argument parsing
import importlib   # MODULE: Module reloading
# ===== IMPORT ANFRAMEWORK =====
import ANFramework
from ANFramework import EnvironmentConfig, LocalConnectionProvider, DatabaseHelper
# ===== CLEAN CACHE ON START =====


def clean_pycache():
    """Clean .pyc files to prevent stale imports"""
    try:
        # Disable bytecode writing for this process
        sys.dont_write_bytecode = True

        # Clean current directory .pyc files
        for f in os.listdir('.'):
            if f.endswith('.pyc'):
                try:
                    os.remove(f)
                except:
                    pass

        # Clean __pycache__ if exists
        pycache = '__pycache__'
        if os.path.exists(pycache) and os.path.isdir(pycache):
            import shutil
            shutil.rmtree(pycache, ignore_errors=True)

    except Exception as e:
        print(f"[CACHE] Cleanup warning: {e}")

# Execute cache cleanup before imports
clean_pycache()


# ===== SAFE IMPORT WITH RELOAD =====
def safe_import_modules():
    """Safely import modules with forced reload"""
    try:
        # First import modules
        import sp_create_signal
        import strategy_termination

        # Force reload to ensure fresh code
        importlib.reload(sp_create_signal)
        importlib.reload(strategy_termination)

        # Now import functions/classes
        from sp_create_signal import execute_signal_procedure
        from strategy_termination import StrategyTerminationService

        print("[IMPORT] Modules reloaded successfully")
        return execute_signal_procedure, StrategyTerminationService

    except Exception as e:
        print(f"[IMPORT] Reload failed: {e}")
        # Fallback to normal import
        from sp_create_signal import execute_signal_procedure
        from strategy_termination import StrategyTerminationService
        return execute_signal_procedure, StrategyTerminationService


# Import modules with reload
execute_signal_procedure, StrategyTerminationService = safe_import_modules()


class MTFRSIEMAStrategy(StrategyBase):
    """
    MTF RSI EMA Strategy class
    Loads configuration from database and operates according to Technical Specification
    """

    def __init__(self, configuration_id: int):
        # Clean cache again at strategy instance creation
        clean_pycache()

        print(f"[STRATEGY] Starting strategy for config_id: {configuration_id}")
        print(f"[STRATEGY] Python executable: {sys.executable}")
        print(f"[STRATEGY] Working directory: {os.getcwd()}")

        self.configuration_id = configuration_id
        # Вызов родительского конструктора с временным timeframe_id=1
        # timeframe_id будет обновлён в _setup_parameters
        super().__init__(configuration_id, timeframe_id=1, timer_interval=0.5)

        self.last_signal_bar_time = None
        self.last_confirmation_bar_time = None
        self.last_trend_bar_time = None
        self.last_heartbeat_time = None

        try:
            self.config = self._load_configuration_from_db()
            self._setup_parameters()

            # Используем self.db из родительского класса StrategyBase
            init_conn = self.db.get_connection()
            try:
                self._update_tracker_state(init_conn, 'start')
            finally:
                self.db.return_connection(init_conn)

            # Получаем строку подключения для termination service
            connection_string = self.connection_provider.connection_string
            self.termination_service = StrategyTerminationService(connection_string)

            print(f"[CONFIG] Strategy interval set to {self.strategy_interval_seconds} seconds")

        except Exception as e:
            print(f"Error: {e}")
            raise

    def _get_connection_string_from_provider(self):
        """
        Get connection string from ANFramework provider
        """
        return self.connection_provider.connection_string

    def _load_configuration_from_db(self):
        """
        Load configuration from database using algo.fn_GetStrategyConfiguration function
        Returns dict with configuration data
        Raises ValueError if configuration not found
        """
        try:
            conn = self.db_helper.get_connection()
            cursor = conn.cursor()

            cursor.execute("SELECT * FROM algo.fn_GetStrategyConfiguration(?)",
                           self.configuration_id)

            row = cursor.fetchone()
            cursor.close()

            if not row:
                raise ValueError(f"Configuration ID {self.configuration_id} not found")

            return {
                'config_id': row.config_id,
                'ticker': row.ticker,
                'ticker_jid': row.ticker_jid,
                'timeframe_signal_id': row.timeframe_signal_id,
                'timeframe_confirmation_id': row.timeframe_confirmation_id,
                'timeframe_trend_id': row.timeframe_trend_id,
                'open_volume': float(row.open_volume) if row.open_volume else 0.0,
                'trading_close_utc': row.trading_close_utc,
                'trading_start_utc': row.trading_start_utc,
                'broker_id': row.broker_id,
                'platform_id': row.platform_id,
                'max_position_checks': row.max_position_checks,
                'check_interval_seconds': row.check_interval_seconds
            }

        finally:
            self.db_helper.return_connection(conn)

    def _setup_parameters(self):
        """
        Setup parameters from loaded configuration
        """
        self.symbol = self.config['ticker']
        self.ticker_jid = self.config['ticker_jid']
        self.timeframe_signal_id = self.config['timeframe_signal_id']
        self.timeframe_confirmation_id = self.config['timeframe_confirmation_id']
        self.timeframe_trend_id = self.config['timeframe_trend_id']
        self.open_volume = self.config['open_volume']
        self.trading_close_utc = self.config['trading_close_utc']
        self.trading_start_utc = self.config['trading_start_utc']
        self.broker_id = self.config['broker_id']
        self.platform_id = self.config['platform_id']

        # Обновляем timeframe_id в родительском классе
        self.timeframe_id = self.timeframe_signal_id

        print(f"Parameters setup complete:")
        print(f"  Symbol: {self.symbol}")
        print(f"  Ticker JID: {self.ticker_jid}")
        print(f"  Signal TF ID: {self.timeframe_signal_id}")
        print(f"  Confirmation TF ID: {self.timeframe_confirmation_id}")
        print(f"  Trend TF ID: {self.timeframe_trend_id}")
        print(f"  Volume: {self.open_volume}")
        print(f"  Trading hours: {self.trading_start_utc} to {self.trading_close_utc}")

    def get_current_signals(self):
        """
        Get current trading signal from SQL function
        Returns: 'buy', 'sell', or None
        """
        try:
            conn = self.db_helper.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                SELECT trading_signal
                FROM algo.fn_GetCurrentSignals(?, ?, ?, ?)
            """, (self.ticker_jid, self.timeframe_signal_id,
                  self.timeframe_confirmation_id, self.timeframe_trend_id))

            row = cursor.fetchone()
            cursor.close()

            if row and row.trading_signal:
                return row.trading_signal.lower()  # 'buy' or 'sell'
            return None

        finally:
            self.db_helper.return_connection(conn)

    def log_strategy_execution(self, connection, config_id, signal_type, volume, price=None, trade_uuid=None):
        try:
            cursor = connection.cursor()
            cursor.execute("EXEC logs.sp_LogStrategyExecution @configID=?, @signalType=?, @volume=?, @price=?, @trade_uuid=?",
                           (config_id, signal_type, volume, price, trade_uuid))
            row = cursor.fetchone()

            connection.commit()
            cursor.close()

            execution_id = row.executionID if row else None
            return execution_id

        except Exception as e:
            print(f"Error logging strategy execution: {e}")
            return None

    def get_open_positions(self, connection):
        """
        Returns list of open positions for current strategy using function
        """
        positions = []
        try:
            cursor = connection.cursor()

            # Call scalar function that returns JSON array
            cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", self.configuration_id)

            row = cursor.fetchone()

            if row and row[0]:
                try:
                    # Parse JSON array
                    import json
                    positions_data = json.loads(row[0])

                    # Check if it's a list
                    if isinstance(positions_data, list):
                        for pos_data in positions_data:
                            positions.append({
                                'id': pos_data.get('id'),
                                'direction': pos_data.get('direction', '').strip(),
                                'volume': float(pos_data.get('volume', 0)) if pos_data.get('volume') else 0.0,
                                'orderUUID': pos_data.get('orderUUID'),
                                'ticker': pos_data.get('ticker')
                            })

                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON: {e}, Raw: {row[0]}")
                except Exception as e:
                    print(f"Error processing positions: {e}")

            cursor.close()

        except Exception as e:
            print(f"Error getting positions: {e}")

        return positions

    def get_market_info(self, connection, ticker, ticker_jid, close_time_utc):
        """
        Gets market information for display
        """
        info = {
            'price': 'N/A',
            'price_time': None,
            'positions_count': 0,
            'position_direction': 'NONE',
            'position_id': 'NONE',
            'signal_signal': 'NO_SIGNAL',
            'confirmation_signal': 'NO_SIGNAL',
            'trend': 'NO_DATA',
            'time_to_close': 'N/A'
        }

        try:
            current_utc = datetime.now(pytz.UTC)

            # Get current price
            price_info = self.get_current_price(connection, ticker_jid, 1)
            if price_info:
                info['price'] = f"{price_info['price']:.2f}"
                info['price_time'] = price_info['time']

            # Get positions
            positions = self.get_open_positions(connection)
            if positions:
                info['positions_count'] = len(positions)
                if len(positions) > 0:
                    info['position_direction'] = positions[0]['direction']
                    info['position_id'] = str(positions[0]['id'])

            # Calculate time until force close
            current_time = current_utc.time()
            if close_time_utc and current_time < close_time_utc:
                current_dt = current_utc
                close_dt = current_utc.replace(hour=close_time_utc.hour, minute=close_time_utc.minute, second=0)
                if close_dt < current_dt:
                    close_dt = close_dt.replace(day=close_dt.day + 1)

                time_diff = close_dt - current_dt
                hours, remainder = divmod(time_diff.seconds, 3600)
                minutes, seconds = divmod(remainder, 60)
                info['time_to_close'] = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            elif close_time_utc:
                info['time_to_close'] = "TIME_PASSED"

        except Exception as e:
            print(f"Error getting market info: {e}")

        return info

    def ensure_single_position(self, connection, ticker, broker_id, platform_id, strategy_configuration_id):
        """
        Ensures only one position exists for the ticker
        """
        positions = self.get_open_positions(connection)

        if len(positions) > 1:
            print(f"WARNING: Multiple positions found ({len(positions)})!")
            # Keep only the latest position, close others
            latest_position = max(positions, key=lambda x: x['id'])

            for pos in positions:
                if pos['id'] != latest_position['id']:
                    print(f"Closing duplicate position ID={pos['id']}")
                    self.close_position(connection, pos['id'])
                    time.sleep(1)  # Wait for close

            return [latest_position]

        return positions

    def wait_for_position_confirmation(self, connection, ticker, expected_direction='Buy', max_checks=10, check_interval_seconds=2):
        """
        Waits for position to appear in the database after opening
        """
        print(f"Waiting for position confirmation...")

        for check in range(max_checks):
            time.sleep(check_interval_seconds)

            positions = self.get_open_positions(connection)
            if positions:
                pos = positions[0]
                print(f"Position confirmed: ID={pos['id']}, Direction={pos['direction']}")
                return positions[0]

            # print(f"  Check {check + 1}/{max_checks}: Position not yet confirmed...")

        print("Warning: Position not confirmed after maximum checks")
        return None

    def open_initial_position(self, connection, ticker, open_volume, broker_id, platform_id, strategy_configuration_id):
        print(f"\nOpening initial BUY position for {ticker}")
        print(f"Volume: {open_volume} lots")

        # 1. Send open signal
        execute_signal_procedure(
            connection=connection,
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

        # ===== TEST: Check position directly =====
        print("\n[TEST] Checking position directly...")
        cursor = connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM trd.trades_v WHERE ticker = ?", ticker)
        count = cursor.fetchone()[0]
        print(f"[TEST] Total positions for {ticker}: {count}")

        cursor.execute("SELECT TOP 5 ID, orderUUID, ticker, direction, volume FROM trd.trades_v WHERE ticker = ? ORDER BY ID DESC", ticker)
        rows = cursor.fetchall()
        for row in rows:
            print(f"[TEST] Position: ID={row.ID}, UUID={row.orderUUID}, Dir={row.direction}, Vol={row.volume}")

        cursor.close()
        print("[TEST] End direct check\n")
        # ===== END TEST =====

        # 2. LOG IMMEDIATELY (before waiting for confirmation)
        current_time = datetime.now(pytz.UTC)
        print(f"[DEBUG] Logging strategy execution at {current_time.strftime('%H:%M:%S.%f')}")

        execution_id = self.log_strategy_execution(
            connection=connection,
            config_id=strategy_configuration_id,
            signal_type='buy',
            volume=open_volume,
            price=None,
            trade_uuid=None
        )

        if execution_id:
            print(f"Strategy execution logged: ID={execution_id}")

        # 3. Use existing method but with FAST parameters
        position = self.wait_for_position_confirmation(
            connection=connection,
            ticker=ticker,
            expected_direction='buy',
            max_checks=30,
            check_interval_seconds=0.1
        )

        if position:
            print(f"Initial position opened successfully")
            print(f"  Position ID: {position['id']}")

            # 4. Update log with UUID if we have log_id
            if execution_id:
                cursor = connection.cursor()
                cursor.execute("""
                    UPDATE logs.strategyExecution 
                    SET trade_uuid = ? 
                    WHERE ID = ?
                """, (position['orderUUID'], execution_id))
                connection.commit()
                cursor.close()
                print(f"DEBUG: Updated log ID={execution_id} with UUID={position['orderUUID']}")

            return position
        else:
            print("Failed to open initial position")
            return None

    def execute_reversal(self, connection, current_position, new_direction):
        try:
            print(f"\n  === EXECUTING REVERSAL ===")
            print(f"  Current: {current_position['direction']}, New: {new_direction.upper()}")

            # Close current position
            print(f"  Closing position ID={current_position['id']}")
            self.close_position(connection, current_position['id'])

            # LOG: Drop signal IMMEDIATELY
            drop_log_id = self.log_strategy_execution(
                connection=connection,
                config_id=self.configuration_id,
                signal_type='drop',
                volume=current_position['volume'],
                price=None,
                trade_uuid=current_position['orderUUID']
            )

            # Open new position
            print(f"  Opening {new_direction.upper()} position")
            execute_signal_procedure(
                connection=connection,
                ticker=self.symbol,
                direction=new_direction,
                volume=self.open_volume,
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=self.broker_id,
                platform_id=self.platform_id,
                trade_id=None,
                trade_type=None,
                strategy_configuration_id=self.configuration_id
            )

            # LOG: New position signal IMMEDIATELY
            new_log_id = self.log_strategy_execution(
                connection=connection,
                config_id=self.configuration_id,
                signal_type=new_direction,
                volume=self.open_volume,
                price=None,
                trade_uuid=None  # Will be None initially
            )

            # Fast wait for new position
            time.sleep(0.5)
            positions = self.get_open_positions(connection)
            new_position_uuid = positions[0]['orderUUID'] if positions else None

            # Update new position log with UUID
            if new_log_id and new_position_uuid:
                cursor = connection.cursor()
                cursor.execute("""
                    UPDATE logs.strategyExecution 
                    SET trade_uuid = ? 
                    WHERE ID = ?
                """, (new_position_uuid, new_log_id))
                connection.commit()
                cursor.close()

            return True

        except Exception as e:
            print(f"Error executing reversal: {e}")
            return False

    def check_force_close(self, connection, ticker, close_time_utc, broker_id, platform_id, strategy_configuration_id):
        """
        Checks and executes forced close at specified UTC time
        """
        if close_time_utc is None or close_time_utc == time_type(0, 0, 0):
            return False

        current_utc = datetime.now(pytz.UTC)
        current_time = current_utc.time()

        if current_time >= close_time_utc:
            positions = self.get_open_positions(connection)

            if positions:
                pos = positions[0]
                print(f"\n=== FORCE CLOSE at {current_time} ===")
                print(f"Closing position ID={pos['id']}")

                self.close_position(connection, pos['id'])

                # Wait for close confirmation
                time.sleep(1)

                # Verify position closed
                positions_after = self.get_open_positions(connection)
                if not positions_after:
                    print(" Position successfully closed")
                else:
                    print(" Position still open, trying again...")

                return True

        return False

    def send_heartbeat(self, connection, config_id):
        """
        Send heartbeat if 60 seconds have passed
        """
        current_utc = datetime.now(pytz.UTC)

        # Если прошло 60 секунд с последнего heartbeat
        if (self.last_heartbeat_time is None or
                (current_utc - self.last_heartbeat_time).total_seconds() >= 60):
            self._update_tracker_state(connection, 'heartbeat')  # Нужно обновить этот метод тоже
            self.last_heartbeat_time = current_utc
            return True

        return False

    def check_trading_hours(self, connection_string, ticker):
        """
        Checks if current time is within trading hours
        """
        current_utc = datetime.now(pytz.UTC)
        current_time = current_utc.time()

        # If both times are None or 00:00:00, trading is 24/7
        if (self.trading_start_utc is None and self.trading_close_utc is None) or \
                (self.trading_start_utc == self.trading_close_utc):
            return True

        # Normal time check
        if self.trading_start_utc <= self.trading_close_utc:
            # Same day window (e.g., 00:00 to 22:00)
            return self.trading_start_utc <= current_time <= self.trading_close_utc
        else:
            # Overnight window (e.g., 22:00 to 01:00)
            return current_time >= self.trading_start_utc or current_time <= self.trading_close_utc

    def close_position(self, connection, trade_id):
        try:
            # First get position UUID before closing
            cursor = connection.cursor()
            cursor.execute("""
                SELECT volume, orderUUID 
                FROM trd.trades_v 
                WHERE ID = ? AND tradeType = 'POSITION'
            """, trade_id)

            row = cursor.fetchone()
            if not row:
                print(f"Error: Position {trade_id} not found")
                return False

            volume = float(row[0]) if row[0] else 0.0
            position_uuid = row[1] if row[1] else None
            cursor.close()

            print(f"[DEBUG] Closing position ID={trade_id}, UUID={position_uuid}, Volume={volume}")

            # Close position
            execute_signal_procedure(
                connection=connection,
                ticker=self.symbol,
                direction='drop',
                volume=volume,
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=self.broker_id,
                platform_id=self.platform_id,
                trade_id=trade_id,
                trade_type='POSITION',
                strategy_configuration_id=self.configuration_id
            )

            # LOG: Drop signal WITH POSITION UUID
            log_id = self.log_strategy_execution(
                connection=connection,
                config_id=self.configuration_id,
                signal_type='drop',
                volume=volume,
                price=None,
                trade_uuid=position_uuid  # Use actual position UUID
            )

            print(f"[DEBUG] Drop logged with ID={log_id}, UUID={position_uuid}")

            # Явный коммит после обеих операций
            connection.commit()

            return True

        except Exception as e:
            print(f"Error closing position {trade_id}: {e}")
            connection.rollback()
            return False

    def process_trading_signal(self, connection, ticker, open_volume, broker_id, platform_id, strategy_configuration_id,
                               signal_signal, confirmation_signal, trend, positions):
        """
        Process trading signal if conditions are met
        """
        # Determine final signal
        final_signal = None

        if signal_signal and confirmation_signal:
            if signal_signal == confirmation_signal:
                final_signal = signal_signal
        elif signal_signal:
            final_signal = signal_signal

        if not final_signal:
            return False

        # Filter signal by trend if available
        if trend and trend != 'cached':
            if (trend == 'bullish' and final_signal != 'buy') or (trend == 'bearish' and final_signal != 'sell'):
                return False

        # Position management
        if not positions:
            return False

        pos = positions[0]
        current_dir = 'buy' if pos['direction'] == 'Buy' else 'sell'

        if current_dir != final_signal:
            # Execute reversal
            print(f"\n  === EXECUTING REVERSAL ===")
            print(f"  Current: {current_dir.upper()}, New: {final_signal.upper()}")

            # Close current position
            print(f"  Closing position ID={pos['id']}")
            self.close_position(connection, pos['id'])

            # Wait for close confirmation
            time.sleep(1)

            # Open new position
            print(f"  Opening {final_signal.upper()} position")
            execute_signal_procedure(
                connection=connection,
                ticker=ticker,
                direction=final_signal,
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

    def run_strategy(self, connection):
        """
        Main strategy logic using SQL function
        Returns: True if force close executed, False otherwise
        """
        # 1. Check force close time
        if self.check_force_close(connection, self.symbol,
                                  self.trading_close_utc, self.broker_id,
                                  self.platform_id, self.configuration_id):
            return True

        # 2. Get market info for display
        market_info = self.get_market_info(connection, self.symbol,
                                           self.ticker_jid, self.trading_close_utc)

        # 3. Get current trading signal from SQL function
        trading_signal = self.get_current_signals()

        # 4. Get trend for display (отдельно для отображения)
        trend_display = self.get_trend_for_display() if hasattr(self, 'get_trend_for_display') else None

        # 5. Show info
        self.show_minute_info(self.symbol, market_info,
                              trading_signal if trading_signal else 'NO_SIGNAL',
                              'CONFIRMED' if trading_signal else 'NO_CONFIRMATION',
                              trend_display if trend_display else 'NO_DATA')

        # 6. Ensure single position
        positions = self.ensure_single_position(connection, self.symbol,
                                                self.broker_id, self.platform_id,
                                                self.configuration_id)

        # 7. Process trading signal if we have a position
        if positions and len(positions) > 0 and trading_signal:
            pos = positions[0]
            current_dir = 'buy' if pos['direction'] == 'Buy' else 'sell'

            if current_dir != trading_signal:
                # Execute reversal
                if self.execute_reversal(connection, pos, trading_signal):
                    # After trading, show updated info
                    time.sleep(1)
                    updated_info = self.get_market_info(connection, self.symbol,
                                                        self.ticker_jid, self.trading_close_utc)
                    self.show_minute_info(self.symbol, updated_info,
                                          'TRADED', 'TRADED',
                                          trend_display if trend_display else 'NO_DATA')

        return False

    def run(self):
        """
        Main strategy execution loop with fast termination checking
        """
        print(f"Strategy {self.configuration_id} running for {self.symbol}")
        print("=" * 70)
        print(f"Config ID: {self.configuration_id}")
        print(f"Ticker: {self.symbol}")
        print(f"Volume: {self.open_volume} lots")
        print(f"Strategy interval: {self.strategy_interval_seconds} seconds")

        if self.trading_close_utc and self.trading_close_utc != time_type(0, 0, 0):
            print(f"Daily Close: {self.trading_close_utc} UTC")
        else:
            print("Daily Close: DISABLED (24/7 trading)")

        print("Press Ctrl+C to stop")
        print("=" * 70)

        # Initial connection for setup
        init_conn = self.db_helper.get_connection()
        try:
            # Check existing positions
            positions = self.get_open_positions(init_conn)

            if not positions:
                print("\nNo existing position found.")
                print("Opening initial position...")
                position = self.open_initial_position(
                    connection=init_conn,
                    ticker=self.symbol,
                    open_volume=self.open_volume,
                    broker_id=self.broker_id,
                    platform_id=self.platform_id,
                    strategy_configuration_id=self.configuration_id
                )

                if not position:
                    print("Failed to open initial position. Exiting.")
                    return
            else:
                print(f"\nExisting position found:")
                for pos in positions:
                    print(f" position ID: {pos['id']} ")

                if len(positions) > 1:
                    print("Cleaning up duplicate positions...")
                    positions = self.ensure_single_position(
                        connection=init_conn,
                        ticker=self.symbol,
                        broker_id=self.broker_id,
                        platform_id=self.platform_id,
                        strategy_configuration_id=self.configuration_id
                    )
        except Exception as e:
            print(f"Initialization error: {e}")
            return
        finally:
            self.db_helper.return_connection(init_conn)

        print("\n" + "=" * 70)
        print(f"Strategy monitoring started (30-second cycle)")
        print("=" * 70)

        last_strategy_run = None
        last_heartbeat_sent = None

        try:
            while True:
                # ===== FAST TERMINATION CHECK (every 100ms) =====
                termination = self.termination_service.check_my_termination(self.configuration_id)
                if termination:
                    # Close all open positions
                    term_conn = self.db_helper.get_connection()
                    try:
                        positions = self.get_open_positions(term_conn)
                        if positions:
                            print(f"[Termination] Closing {len(positions)} open position(s)...")
                            for pos in positions:
                                print(f"  Closing position ID={pos['id']} (Direction: {pos['direction']})")
                                self.close_position(connection=term_conn, trade_id=pos['id'])

                        # Update tracker state with termination connection
                        self._update_tracker_state(term_conn, 'terminated')
                    finally:
                        self.db_helper.return_connection(term_conn)

                    self.termination_service.mark_completed(termination['termination_id'])
                    self.termination_service.clear_cache()

                    print(f"\n{'=' * 70}")
                    print(f"[Termination] Strategy {self.configuration_id} terminated successfully")
                    print(f"Exiting program...")
                    print(f"{'=' * 70}")
                    break

                now = datetime.now(pytz.UTC)

                # ===== STRATEGY LOGIC (every 30 seconds) =====
                if last_strategy_run is None or (now - last_strategy_run).total_seconds() >= self.strategy_interval_seconds:
                    try:
                        print(f"[CYCLE] Strategy execution at {now.strftime('%H:%M:%S')} UTC")

                        # Create connection for strategy cycle
                        strategy_conn = self.db_helper.get_connection()
                        try:
                            should_terminate = self.run_strategy(strategy_conn)

                            if should_terminate:
                                print(f"\n{'=' * 70}")
                                print(f"Strategy {self.configuration_id} completed (force close executed)")
                                print(f"{'=' * 70}")
                                self._update_tracker_state(strategy_conn, 'terminated')
                                break

                            last_strategy_run = now

                            # Log next execution time
                            next_run = now + timedelta(seconds=self.strategy_interval_seconds)
                            print(f"[CYCLE] Next execution at {next_run.strftime('%H:%M:%S')} UTC")

                        finally:
                            self.db_helper.return_connection(strategy_conn)

                    except Exception as e:
                        print(f"Error in strategy execution: {e}")
                        # Wait a bit before retry
                        time.sleep(5)

                # ===== HEARTBEAT (every 60 seconds) =====
                if last_heartbeat_sent is None or (now - last_heartbeat_sent).total_seconds() >= 60:
                    heartbeat_conn = self.db_helper.get_connection()
                    try:
                        self.send_heartbeat(heartbeat_conn, self.configuration_id)
                        last_heartbeat_sent = now
                    finally:
                        self.db_helper.return_connection(heartbeat_conn)

                # ===== SHORT PAUSE FOR FAST TERMINATION =====
                time.sleep(0.1)

        except KeyboardInterrupt:
            print("\n\n" + "=" * 70)
            print("Strategy stopped by user")
            print("=" * 70)

            # Final position status and update tracker
            final_conn = self.db_helper.get_connection()
            try:
                positions = self.get_open_positions(final_conn)
                if positions:
                    print(f"\nFinal position status:")
                    for pos in positions:
                        print(f"  ID: {pos['id']}, Direction: {pos['direction']}, Volume: {pos['volume']}")
                else:
                    print("\nNo open positions")

                # Update tracker state with final connection
                self._update_tracker_state(final_conn, 'stop')
            finally:
                self.db_helper.return_connection(final_conn)

            print("\nExiting...")

        except Exception as e:
            print(f"\nUnexpected error: {e}")
            raise

    def _update_tracker_state(self, connection, state: str):
        """
        Update strategy state in algo.strategyTracker table
        """
        try:
            cursor = connection.cursor()  # Используем переданное соединение

            cursor.execute("""
                EXEC algo.sp_UpdateStrategyState @configID = ?, @currentState = ?
            """, (self.configuration_id, state))
            connection.commit()
            cursor.close()
        except Exception as e:
            print(f"Error updating tracker state: {e}")

    def show_minute_info(self, ticker, market_info, signal_signal, confirmation_signal, trend):
        """
        Shows information every minute
        """
        try:
            current_utc = datetime.now(pytz.UTC)

            # Format signals
            signal_signal_str = 'NO_SIGNAL' if signal_signal is None else signal_signal.upper()
            confirmation_signal_str = 'NO_SIGNAL' if confirmation_signal is None else confirmation_signal.upper()
            trend_str = 'NO_DATA' if trend is None else trend.upper()

            # Format position info
            if market_info['positions_count'] > 0:
                pos_str = f"ID:{market_info['position_id']} {market_info['position_direction']}"
            else:
                pos_str = "NO_POSITION"

            # Print formatted line
            print(f"[{current_utc.strftime('%H:%M:%S')}] {ticker}: {market_info['price']} | "
                  f"Pos: {pos_str} | "
                  f"Signal: {signal_signal_str} | Confirmation: {confirmation_signal_str} | Trend: {trend_str} | "
                  f"Close: {market_info['time_to_close']}")

        except Exception as e:
            print(f"Error showing info: {e}")

    def get_current_price(self, connection, ticker_jid, timeframe_id=1):
        """
        Gets current price from latest bar using scalar function
        """
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT tms.fn_GetCurrentPrice(?, ?)",
                           (ticker_jid, timeframe_id))

            row = cursor.fetchone()
            cursor.close()

            if row and row[0] is not None:
                return {
                    'price': float(row[0]),
                    'time': None  # Скалярная функция не возвращает время
                }
            return None

        except Exception as e:
            print(f"Error getting price: {e}")
            return None


if __name__ == "__main__":
    # Clean cache at main entry point
    clean_pycache()

    print(f"[MAIN] Script started at: {datetime.now()}")
    print(f"[MAIN] Command line args: {sys.argv}")

    parser = argparse.ArgumentParser(description='MTF RSI EMA Trading Strategy')
    parser.add_argument('--config-id', type=int, required=True, help='Configuration ID from database')
    args = parser.parse_args()

    try:
        strategy = MTFRSIEMAStrategy(args.config_id)
        strategy.run()
    except Exception as e:
        print(f"Error: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)