# strategy_termination.py - ОРИГИНАЛЬНАЯ ВЕРСИЯ
import pyodbc
import time
import threading
from typing import Dict, Optional
from datetime import datetime


class StrategyTerminationService:
    """Shared termination service with cache"""

    _instance = None
    _lock = threading.Lock()

    def __new__(cls, connection_string: str):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance._initialized = False
                cls._instance.connection_string = connection_string
        return cls._instance

    def __init__(self, connection_string: str):
        if not self._initialized:
            self.cache: Dict[int, dict] = {}
            self.cache_time = None
            self.cache_ttl = 0.1  # 100 milliseconds
            self._lock = threading.Lock()
            self._initialized = True

    def get_terminations(self) -> Dict[int, dict]:
        """Get terminations with cache"""
        with self._lock:
            now = time.time()

            # Return cache if fresh
            if (self.cache_time and
                    (now - self.cache_time) < self.cache_ttl):
                return self.cache.copy()

            # Refresh cache
            self.cache = self._fetch_from_db()
            self.cache_time = now
            return self.cache.copy()

    def _fetch_from_db(self) -> Dict[int, dict]:
        """Fetch terminations from database using VIEW"""
        terminations = {}

        try:
            conn = pyodbc.connect(self.connection_string)
            cursor = conn.cursor()

            cursor.execute("SELECT * FROM algo.strategy_termination_queue_v")

            rows = cursor.fetchall()
            for row in rows:
                print(f"[Termination DB] Config {row.config_id}: ID {row.termination_id}, Requested {row.requested_at}")

                # Only keep latest for each config
                if row.config_id not in terminations:
                    terminations[row.config_id] = {
                        'termination_id': row.termination_id,
                        'requested_at': row.requested_at
                    }

            conn.close()

        except Exception as e:
            print(f"[Termination] Fetch error: {e}")

        return terminations

    def check_my_termination(self, config_id: int) -> Optional[dict]:
        """Check if my config has termination request"""
        if not isinstance(config_id, int) or config_id <= 0:
            print(f"[Termination Warning] Invalid config_id: {config_id}")
            return None

        terminations = self.get_terminations()

        if config_id in terminations:
            print(f"[Termination Service] Found termination for config_id: {config_id}")
            print(f"[Termination Service] Details: {terminations[config_id]}")

        return terminations.get(config_id)

    def mark_completed(self, termination_id: int):
        """Mark termination as completed using stored procedure"""
        try:
            conn = pyodbc.connect(self.connection_string)
            cursor = conn.cursor()

            cursor.execute("EXEC algo.sp_MarkTerminationCompleted ?", (termination_id,))

            conn.commit()
            conn.close()

            # Invalidate cache - CLEAR COMPLETELY
            with self._lock:
                self.cache = {}  # Clear cache dictionary
                self.cache_time = None
                print(f"[Termination] Cache cleared after marking completion")

        except Exception as e:
            print(f"[Termination] Mark error: {e}")

    def clear_cache(self):
        """Explicitly clear termination cache"""
        with self._lock:
            self.cache = {}
            self.cache_time = None
            print(f"[Termination] Cache explicitly cleared")