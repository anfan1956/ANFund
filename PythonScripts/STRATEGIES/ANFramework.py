import pyodbc
from dotenv import load_dotenv
import os
from abc import ABC, abstractmethod
import pytz
from datetime import datetime, time as time_type
import time


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

    def __init__(self, configuration_id: int, timeframe_id: int,
                 connection_provider=None, timer_interval=0.5):
        """
        Args:
            configuration_id: Strategy configuration ID from database
            timeframe_id: Minimum timeframe ID for bar checking (e.g., 1 for M1)
            connection_provider: ConnectionProvider instance (optional)
            timer_interval: Timer interval in seconds (default 0.5s = 500ms)
        """
        self.configuration_id = configuration_id
        self.timeframe_id = timeframe_id
        self.timer_interval = timer_interval

        # Calculate n (number of timer intervals per timeframe)
        timeframe_seconds = self.TIMEFRAME_MAP.get(timeframe_id)
        if not timeframe_seconds:
            raise ValueError(f"Unknown timeframe_id: {timeframe_id}")

        self.n = int(timeframe_seconds / timer_interval)
        self.current_cycle = 0

        print(f"Strategy {configuration_id} initialized: "
              f"timeframe={timeframe_id}, interval={timer_interval}s, n={self.n}")

        # Initialize connection provider
        if connection_provider is None:
            self.connection_provider = LocalConnectionProvider()
        else:
            self.connection_provider = connection_provider

        # Initialize helpers
        self.db = DatabaseHelper(self.connection_provider)
        self.position_manager = PositionManager(self)

        # Register strategy and load configuration
        self._register_and_load_configuration()

    def _register_and_load_configuration(self):
        """Register strategy in database and load configuration"""
        conn = self.db.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("EXEC algo.sp_strategyRegister @configID = ?",
                           self.configuration_id)

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
            else:
                raise ValueError(f"Failed to register strategy {self.configuration_id}")

        finally:
            self.db.return_connection(conn)

    def get_connection(self, autocommit=False):
        """Get database connection"""
        return self.db.get_connection(autocommit)

    def return_connection(self, connection):
        """Return connection to pool"""
        self.db.return_connection(connection)

    # Остальные методы пока заглушки
    def get_open_positions(self, connection):
        """Get open positions for strategy - TO BE IMPLEMENTED"""
        raise NotImplementedError

    def log_strategy_execution(self, connection, config_id, signal_type, volume, price=None, trade_uuid=None):
        """Log strategy execution - TO BE IMPLEMENTED"""
        raise NotImplementedError

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