import pytz
from datetime import datetime
import os
from abc import ABC, abstractmethod
import pyodbc
from dotenv import load_dotenv


class EnvironmentConfig:
    """Environment configuration loader"""

    @staticmethod
    def load():
        """Load environment variables from .env file"""
        load_dotenv()

    @staticmethod
    def get_connection_string():
        """Get connection string from environment variables"""
        EnvironmentConfig.load()

        server = os.getenv('ANFUND_DB_SERVER')
        database = os.getenv('ANFUND_DB_NAME')
        username = os.getenv('ANFUND_DB_USER')
        password = os.getenv('ANFUND_DB_PASSWORD')

        if not all([server, database, username, password]):
            raise ValueError("Missing database credentials in environment variables")

        return (
            'DRIVER={ODBC Driver 17 for SQL Server};'
            f'SERVER={server};'
            f'DATABASE={database};'
            f'UID={username};'
            f'PWD={password};'
        )


class ConnectionProvider(ABC):
    """Abstract base class for connection providers"""

    @abstractmethod
    def get_connection(self, autocommit=False):
        """Get database connection"""
        pass

    @abstractmethod
    def close_all_connections(self):
        """Close all connections"""
        pass


class LocalConnectionProvider(ConnectionProvider):
    """Local connection provider with connection pool"""

    def __init__(self, pool_size=20, max_overflow=10):
        """
        Args:
            pool_size: Number of persistent connections
            max_overflow: Additional connections if pool exhausted
        """
        self.connection_string = EnvironmentConfig.get_connection_string()
        self.pool_size = pool_size
        self.max_overflow = max_overflow
        self.pool = []  # Available connections
        self.active = []  # Active connections
        self.total_created = 0
        print(f"Connection pool initialized (size: {pool_size}, max: {pool_size + max_overflow})")

    def get_connection(self, autocommit=False):
        """Get connection from pool"""
        # 1. Try to get from pool
        if self.pool:
            conn = self.pool.pop()
        # 2. Create new if within limit
        elif self.total_created < self.pool_size + self.max_overflow:
            conn = pyodbc.connect(self.connection_string)
            self.total_created += 1
        # 3. Pool exhausted
        else:
            raise RuntimeError(f"Connection pool exhausted. Active: {len(self.active)}, Pool: {len(self.pool)}, Total: {self.total_created}")

        if autocommit:
            conn.autocommit = True

        self.active.append(conn)
        return conn

    def return_connection(self, conn):
        """Return connection to pool"""
        if conn in self.active:
            self.active.remove(conn)
            # Reset connection state
            try:
                conn.rollback()
            except:
                pass
            # Return to pool if not full
            if len(self.pool) < self.pool_size:
                self.pool.append(conn)
            else:
                conn.close()
                self.total_created -= 1

    def close_all_connections(self):
        """Close all connections"""
        for conn in self.active + self.pool:
            try:
                conn.close()
            except:
                pass
        self.active = []
        self.pool = []
        self.total_created = 0

    def get_stats(self):
        """Get pool statistics"""
        return {
            'pool': len(self.pool),
            'active': len(self.active),
            'total': self.total_created,
            'limit': self.pool_size + self.max_overflow
        }

    def __del__(self):
        """Destructor"""
        self.close_all_connections()


class StrategyBase:
    """Base class for all trading strategies"""

    # Timeframe mapping: timeframeID -> seconds
    TIMEFRAME_MAP = {
        1: 60,    # M1
        2: 300,   # M5
        3: 900,   # M15
        4: 1800,  # M30
        5: 3600,  # H1
        6: 14400, # H4
        7: 86400, # D1
        8: 604800,# W1
        9: 2592000 # MN1
    }

    def __init__(self, configid, timer_interval=0.5, timeframe_id=1):
        """
        Args:
            configid: Strategy configuration ID (required)
            timer_interval: Timer interval in seconds (default 0.5s = 500ms)
            timeframe_id: Default timeframe ID (default 1 = M1)
        """
        self._termination_error_printed = None
        if configid is None:
            raise ValueError("configid is required")

        self.configid = configid
        self.timer_interval = timer_interval
        self.current_cycle = 0
        self.timeframe_id = timeframe_id  # ← ДОБАВИТЬ ЭТУ СТРОКУ

        print(f"StrategyBase initialized for config {configid} with {timer_interval}s interval")

        # Initialize connection provider
        self.connection_provider = LocalConnectionProvider()
        self.db = DatabaseHelper(self.connection_provider)

        # Configuration storage
        self.configs = {}  # configid -> configuration data
        self.strategy_instances = {}  # configid -> strategy instance
        self.n = 120  # Default for M1 timeframe, will be updated per config

        # Position storage in memory
        self.positions = {}  # configid -> position_data

    def _register_and_load_configuration(self):
        """Register strategy in database and load configuration"""
        conn = self.db.get_connection(autocommit=True)
        try:
            cursor = conn.cursor()

            # 1. Регистрируем стратегию и получаем конфигурацию
            cursor.execute("EXEC algo.sp_strategyRegister @configID = ?",
                           self.configid)  # ← ИЗМЕНИТЬ

            result = cursor.fetchone()

            if result and result[0]:
                import json
                config = json.loads(result[0])

                # Store configuration
                self.config_data = config
                self.config_instance_guid = config['configInstanceGUID']

                # Update timeframe_id from actual configuration
                actual_timeframe_id = config['timeframe_signal_id']
                if actual_timeframe_id != self.timeframe_id:
                    print(f"  Updating timeframe: {self.timeframe_id} -> {actual_timeframe_id}")
                    self.timeframe_id = actual_timeframe_id
                    # Recalculate n with correct timeframe
                    timeframe_seconds = self.TIMEFRAME_MAP.get(self.timeframe_id)
                    if timeframe_seconds:
                        self.n = int(timeframe_seconds / self.timer_interval)
                        print(f"  Updated n={self.n}")

                print(f"Strategy registered: {self.config_instance_guid}")

                # 2. Логируем старт стратегии
                cursor.execute("""
                    EXEC logs.sp_LogStrategyExecution 
                        @configID = ?, 
                        @eventTypeName = 'start',
                        @volume = ?,
                        @price = NULL,
                        @trade_uuid = ?
                """, (self.configid, float(config['open_volume']), self.config_instance_guid))  # ← ИЗМЕНИТЬ

                print(f"Strategy start logged")

            else:
                raise ValueError(f"Failed to register strategy {self.configid}")  # ← ИЗМЕНИТЬ

            # Добавляем стратегию в пул активных стратегий фреймворка
            if not hasattr(self, '_framework_pool'):
                self._framework_pool = {}  # Локальный пул этого экземпляра

            self._framework_pool[self.configid] = self  # ← ИЗМЕНИТЬ
            print(f"[StrategyBase] Strategy {self.configid} added to framework pool")  # ← ИЗМЕНИТЬ

        finally:
            self.db.return_connection(conn)

    def get_connection(self, autocommit=False):
        """Get database connection"""
        return self.db.get_connection(autocommit)

    def return_connection(self, connection):
        """Return connection to pool"""
        self.db.return_connection(connection)

    def run(self):
        """
        Main strategy execution loop.
        """
        print(f"[StrategyBase] Starting execution loop for config {self.configid}")  # ← ИЗМЕНИТЬ

        try:
            while True:
                conn = self.get_connection()

                try:
                    if self.check_termination(conn):
                        print(f"[StrategyBase] Termination condition met. Stopping strategy.")
                        self.force_close(conn)
                        break

                    if self.check_suspend_trading(conn):  # ← ИЗМЕНИТЬ НАЗВАНИЕ
                        print(f"[StrategyBase] Trading suspend time reached.")  # ← ИЗМЕНИТЬ ТЕКСТ
                        self.force_close(conn)
                        break

                    # ← ВСТАВИТЬ ЗДЕСЬ ↓
                    self.process_bars_and_signals(conn, close_existing=True)
                    # ← ВСТАВИТЬ ЗДЕСЬ ↑

                finally:
                    self.return_connection(conn)

                import time
                time.sleep(self.timer_interval)

                self.current_cycle += 1
                if self.current_cycle >= self.n:
                    self.current_cycle = 0

        except KeyboardInterrupt:
            print(f"[StrategyBase] Interrupted by user")
        except Exception as e:
            print(f"[StrategyBase] Error in execution loop: {e}")
            import traceback
            traceback.print_exc()
        finally:
            print(f"[StrategyBase] Strategy {self.configid} stopped")  # ← ИЗМЕНИТЬ

    def check_termination(self, connection):
        """Check if strategy should terminate using database procedure"""
        try:
            cursor = connection.cursor()

            # Check if config_instance_guid exists
            if not hasattr(self, 'config_instance_guid'):
                return False

            # Call the termination procedure
            cursor.execute("""
                EXEC algo.sp_TerminateInstance ?
            """, self.config_instance_guid)

            result = cursor.fetchone()
            cursor.close()

            # Procedure returns 1 (True) if should terminate
            if result and result[0]:
                return bool(result[0])  # Convert to Python bool

            return False

        except Exception as e:
            # Print error only first time
            if not hasattr(self, '_termination_error_printed'):
                self._termination_error_printed = True
                print(f"[StrategyBase] Error checking termination: {e}")
            return False

    def check_suspend_trading(self, connection):
        """Check if trading should be suspended (time-based)"""
        try:
            if not hasattr(self, 'config_data'):
                return False

            close_utc = self.config_data.get('trading_close_utc')
            if not close_utc or str(close_utc) == '00:00:00':
                return False

            from datetime import time as dt_time
            if len(str(close_utc)) == 8 and str(close_utc).count(':') == 2:
                h, m, s = map(int, str(close_utc).split(':'))
                close_time = dt_time(h, m, s)
            else:
                return False

            current_utc = datetime.now(pytz.UTC).time()
            return current_utc >= close_time
        except Exception as e:
            print(f"[StrategyBase] Error checking suspend trading: {e}")
            return False

    def force_close(self, connection):
        """Force close all positions for this strategy"""
        print(f"[StrategyBase] Force closing positions for config {self.configid}")

        try:
            # Get positions from database
            cursor = connection.cursor()
            cursor.execute("SELECT algo.fn_GetInstancePositionIDs(?)", self.config_instance_guid)
            result = cursor.fetchone()

            if not result or not result[0]:
                print(f"[StrategyBase] No positions found")
                return True

            import json
            positions_data = json.loads(result[0])

            if len(positions_data) == 0:
                print(f"[StrategyBase] No positions to close")
                return True

            # Close each position
            for position in positions_data:
                position_id = position['id']
                print(f"[StrategyBase] Closing position ID {position_id}")

                execute_signal_procedure(
                    connection=connection,
                    ticker=position['ticker'],
                    direction='drop',
                    volume=0,
                    order_price=None,
                    stop_loss=None,
                    take_profit=None,
                    expiry=None,
                    broker_id=self.config_data.get('broker_id'),
                    platform_id=self.config_data.get('platform_id'),
                    trade_id=position_id,
                    trade_type='POSITION',
                    strategy_configuration_id=self.configid
                )

                # Log close
                self.log_strategy_execution(
                    connection=connection,
                    signal_type='force_close',
                    volume=0,
                    trade_uuid=str(position_id)
                )

            connection.commit()
            cursor.close()

            # Remove from memory
            if self.configid in self.positions:
                del self.positions[self.configid]

            print(f"[StrategyBase] Force close completed for {len(positions_data)} position(s)")
            return True

        except Exception as e:
            print(f"[StrategyBase] Error in force close: {e}")
            connection.rollback()
            return False

    def get_position(self, configid):
        """Get position from memory for specified configid"""
        return self.positions.get(configid)

    def close_position(self, configid, position_id):
        """Close specific position (command from strategy)"""
        if configid != self.configid:
            print(f"[StrategyBase] Warning: close_position called for config {configid} but instance is for config {self.configid}")
            return False

        try:
            print(f"[StrategyBase] Closing position {position_id} for config {configid}")

            # Get position details from memory or DB
            position = self.positions.get(configid)
            if not position:
                # Try to get from DB
                cursor = self.get_connection().cursor()
                cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", configid)
                result = cursor.fetchone()
                if result and result[0]:
                    import json
                    positions_data = json.loads(result[0])
                    if positions_data and len(positions_data) > 0:
                        position = positions_data[0]

            if not position:
                print(f"[StrategyBase] Position {position_id} not found")
                return False

            # Execute close
            conn = self.get_connection()
            execute_signal_procedure(
                connection=conn,
                ticker=position['ticker'],
                direction='drop',
                volume=0,
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=self.config_data.get('broker_id'),
                platform_id=self.config_data.get('platform_id'),
                trade_id=position_id,
                trade_type='POSITION',
                strategy_configuration_id=configid
            )

            # Log
            self.log_strategy_execution(
                connection=conn,
                signal_type='drop',
                volume=0,
                trade_uuid=str(position_id)
            )

            conn.commit()
            self.return_connection(conn)

            # Remove from memory
            if configid in self.positions:
                del self.positions[configid]

            print(f"[StrategyBase] Position {position_id} closed")
            return True

        except Exception as e:
            print(f"[StrategyBase] Error closing position: {e}")
            return False

    def open_position(self, configid, direction):
        """Open new position (command from strategy)"""
        if configid != self.configid:
            print(f"[StrategyBase] Warning: open_position called for config {configid} but instance is for config {self.configid}")
            return False

        try:
            if not hasattr(self, 'config_data'):
                print(f"[StrategyBase] No config data loaded")
                return False

            print(f"[StrategyBase] Opening {direction} position for config {configid}")

            conn = self.get_connection()

            # Execute open
            execute_signal_procedure(
                connection=conn,
                ticker=self.config_data['ticker'],
                direction=direction,
                volume=float(self.config_data['open_volume']),
                order_price=None,
                stop_loss=None,
                take_profit=None,
                expiry=None,
                broker_id=self.config_data.get('broker_id'),
                platform_id=self.config_data.get('platform_id'),
                trade_id=None,
                trade_type=None,
                strategy_configuration_id=configid
            )

            # Log
            self.log_strategy_execution(
                connection=conn,
                signal_type=direction,
                volume=float(self.config_data['open_volume']),
                price=None,
                trade_uuid=None
            )

            conn.commit()
            self.return_connection(conn)

            print(f"[StrategyBase] {direction} position opened for {self.config_data['ticker']}")
            return True

        except Exception as e:
            print(f"[StrategyBase] Error opening position: {e}")
            return False

    def log_strategy_execution(self, connection, signal_type, volume, price=None, trade_uuid=None):
        """Log strategy execution - общий метод"""
        try:
            cursor = connection.cursor()
            cursor.execute("""
                EXEC logs.sp_LogStrategyExecution 
                    @configID = ?, 
                    @signalType = ?,
                    @volume = ?,
                    @price = ?,
                    @trade_uuid = ?
            """, (self.configid, signal_type, volume, price, trade_uuid))  # ← ИЗМЕНИТЬ
            connection.commit()
            cursor.close()
            return True
        except Exception as e:
            print(f"[StrategyBase] Error logging execution: {e}")
            return False

    def _cleanup(self):
        """Cleanup resources"""
        self.connection_provider.close_all_connections()

    def __del__(self):
        """Destructor"""
        self._cleanup()



class PositionManager:
    """Position management utilities"""

    def __init__(self, strategy=None):
        self.strategy = strategy

    def ensure_single_position(self, connection, ticker, broker_id, platform_id, strategy_configuration_id):
        """Ensure only one position exists - TO BE IMPLEMENTED"""
        raise NotImplementedError

    def wait_for_position_confirmation(self, connection, ticker, expected_direction='Buy', max_checks=10, check_interval_seconds=2):
        """Wait for position confirmation - TO BE IMPLEMENTED"""
        raise NotImplementedError

    # ... другие методы управления позициями


class DatabaseHelper:
    """Database connection and utilities"""

    def __init__(self, connection_provider=None):
        """
        Args:
            connection_provider: ConnectionProvider instance (optional)
        """
        if connection_provider is None:
            # Default to LocalConnectionProvider
            self.connection_provider = LocalConnectionProvider()
        else:
            self.connection_provider = connection_provider

    def get_connection(self, autocommit=False):
        """Get database connection from provider"""
        return self.connection_provider.get_connection(autocommit)

    def return_connection(self, connection):
        """Return connection to provider's pool"""
        if hasattr(self.connection_provider, 'return_connection'):
            self.connection_provider.return_connection(connection)
        else:
            connection.close()

    def execute_query(self, query, params=None):
        """Execute SQL query with automatic connection management"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            return cursor
        finally:
            self.return_connection(conn)

    def get_stats(self):
        """Get connection pool statistics"""
        if hasattr(self.connection_provider, 'get_stats'):
            return self.connection_provider.get_stats()
        return {}


# Заглушки для будущих модулей
class RiskManager:
    """Risk management - PLACEHOLDER FOR FUTURE"""
    pass


class PerformanceAnalyzer:
    """Strategy performance analysis - PLACEHOLDER"""
    pass


class SignalValidator:
    """Signal validation - PLACEHOLDER"""
    pass


# ===== SIGNAL EXECUTION FUNCTION =====
def execute_signal_procedure(connection, ticker, direction, volume, order_price=None,
                             stop_loss=None, take_profit=None, expiry=None,
                             broker_id=None, platform_id=None, trade_id=None,
                             trade_type=None, strategy_configuration_id=None):
    """
    Execute trading signal procedure
    Based on sp_create_signal.py logic
    """
    try:
        cursor = connection.cursor()

        # Prepare parameters
        params = [
            ticker,
            direction,
            volume,
            order_price if order_price is not None else None,
            stop_loss if stop_loss is not None else None,
            take_profit if take_profit is not None else None,
            expiry,
            broker_id if broker_id is not None else None,
            platform_id if platform_id is not None else None,
            trade_id,
            trade_type,
            strategy_configuration_id
        ]

        # Call stored procedure
        cursor.execute("EXEC trd.sp_CreateSignal ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?", params)
        connection.commit()
        cursor.close()

        print(f"[Signal] {ticker} {direction} volume={volume}")
        return True

    except Exception as e:
        print(f"[Signal Error] {e}")
        connection.rollback()
        return False
