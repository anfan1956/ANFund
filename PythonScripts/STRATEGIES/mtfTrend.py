"""
MTF Trend Strategy - новая реализация на ANFramework
"""

import sys
from ANFramework import StrategyBase
import pytz
from datetime import datetime
from ANFramework import StrategyBase, execute_signal_procedure  # ← Импорт из ANFramework


class MTFTrendStrategy(StrategyBase):
    """Multi-Timeframe Trend Following Strategy"""

    def __init__(self, configuration_id: int):
        print(f"[MTF Trend] Initializing strategy for config_id: {configuration_id}")

        # timeframe_id=1 временно, будет обновлён в родительском классе
        super().__init__(configuration_id, timeframe_id=1, timer_interval=0.5)

        # Параметры уже загружены в self.config_data
        self._setup_parameters()  # ← ДОБАВЬ ЭТУ СТРОКУ

        print(f"[MTF Trend] Strategy {configuration_id} ready")

    def _setup_parameters(self):
        """Setup strategy parameters from loaded configuration"""
        config = self.config_data

        # Основные параметры
        self.symbol = config['ticker']
        self.ticker_jid = config['ticker_jid']
        self.timeframe_signal_id = config['timeframe_signal_id']
        self.timeframe_confirmation_id = config['timeframe_confirmation_id']
        self.timeframe_trend_id = config['timeframe_trend_id']
        self.open_volume = float(config['open_volume'])
        self.trading_close_utc = config['trading_close_utc']
        self.trading_start_utc = config['trading_start_utc']
        self.broker_id = config['broker_id']
        self.platform_id = config['platform_id']

        # Для удобства
        self.timeframe_id = self.timeframe_signal_id  # минимальный таймфрейм

        print(f"[MTF Trend] Parameters loaded for {self.symbol}:")
        print(f"  Ticker JID: {self.ticker_jid}")
        print(f"  Timeframes: signal={self.timeframe_signal_id}, "
              f"confirmation={self.timeframe_confirmation_id}, trend={self.timeframe_trend_id}")
        print(f"  Volume: {self.open_volume}")
        print(f"  Trading hours: {self.trading_start_utc} to {self.trading_close_utc}")
        print(f"  Broker: {self.broker_id}, Platform: {self.platform_id}")

    def get_current_signals(self, connection):
        """
        Get trading signal from DB or return 'buy' on first run.
        Returns: 'buy', 'sell', or None
        """
        try:
            # First run - return 'buy' for initial position
            if not hasattr(self, '_first_signal_sent'):
                self._first_signal_sent = True
                return 'buy'

            # TODO: Implement actual strategy logic here
            # For now - return None (no signal)
            return None

        except Exception as e:
            print(f"[MTF Trend] Error in get_current_signals: {e}")
            return None

    def _open_position(self, connection, direction):
        """Open position in specified direction"""
        print(f"[MTF Trend] Opening {direction} position for {self.symbol}")

        execute_signal_procedure(
            connection=connection,
            ticker=self.symbol,
            direction=direction,
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

        # Log
        cursor = connection.cursor()
        cursor.execute("""
            EXEC logs.sp_LogStrategyExecution 
                @configID = ?, 
                @signalType = ?,
                @volume = ?,
                @price = NULL,
                @trade_uuid = NULL
        """, (self.configuration_id, direction, self.open_volume))
        connection.commit()
        cursor.close()

        # Set pending confirmation
        self.pending_confirmation = {
            'action': 'open',
            'direction': direction,
            'volume': self.open_volume,
            'symbol': self.symbol,
            'time_opened': datetime.now(pytz.UTC)
        }

        print(f"[MTF Trend] {direction.upper()} signal sent, waiting confirmation")

    def has_pending_confirmations(self):
        """Check if there are pending position confirmations"""
        return hasattr(self, 'pending_confirmation') and self.pending_confirmation is not None

    def check_position_confirmations(self, connection):
        """Check pending position confirmations"""
        if not self.has_pending_confirmations():
            return None

        pending = self.pending_confirmation
        action = pending.get('action')

        if action == 'open':
            # Existing logic for open confirmation
            cursor = connection.cursor()
            cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", self.configuration_id)
            result = cursor.fetchone()
            cursor.close()

            if result and result[0]:
                import json
                positions_data = json.loads(result[0])
                if positions_data and len(positions_data) > 0:
                    position = positions_data[0]
                    print(f"[MTF Trend] Position confirmed: ID={position['id']}")
                    self.pending_confirmation = None
                    return position

        elif action == 'close_before_open':
            # Check if position is closed
            position_id = pending.get('position_id')
            cursor = connection.cursor()
            cursor.execute("""
                SELECT id FROM trd.trades_v 
                WHERE id = ? AND closeTime IS NOT NULL
            """, position_id)
            result = cursor.fetchone()
            cursor.close()

            if result:
                # Position closed, now open new one
                new_signal = pending.get('new_signal')
                print(f"[MTF Trend] Position {position_id} closed, opening {new_signal} position")
                self.pending_confirmation = None  # Clear before opening new
                self._open_position(connection, new_signal)
                return {'action': 'closed_and_opening', 'new_signal': new_signal}

            # Alternative check: position no longer in open positions
            cursor = connection.cursor()
            cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", self.configuration_id)
            result = cursor.fetchone()
            cursor.close()

            if result and result[0]:
                import json
                positions_data = json.loads(result[0])
                if not positions_data or len(positions_data) == 0:
                    new_signal = pending.get('new_signal')
                    print(f"[MTF Trend] Position closed (no open positions), opening {new_signal}")
                    self.pending_confirmation = None
                    self._open_position(connection, new_signal)
                    return {'action': 'closed_and_opening', 'new_signal': new_signal}

        return None

    def process_bars_and_signals(self, connection, close_existing=True):
        """Process bars and trading signals

        Args:
            close_existing: True - close existing position and execute signal
                           False - check signal direction vs existing position
        """
        try:
            # 1. Get trading signal
            signal = self.get_current_signals(connection)
            if not signal:
                return  # No signal

            print(f"[MTF Trend] Signal received: {signal} (close_existing={close_existing})")

            # 2. Check if we have pending confirmations
            if self.has_pending_confirmations():
                return

            # 3. Check current position
            cursor = connection.cursor()
            cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", self.configuration_id)
            result = cursor.fetchone()
            cursor.close()

            has_position = False
            current_position = None

            if result and result[0]:
                import json
                positions_data = json.loads(result[0])
                has_position = len(positions_data) > 0
                if has_position:
                    current_position = positions_data[0]

            # 4. Handle signal based on close_existing parameter
            if has_position and current_position:
                current_direction = current_position['direction'].lower()

                # If close_existing=True OR directions don't match - close and open
                if close_existing or current_direction != signal:
                    print(f"[MTF Trend] Closing position {current_position['id']} ({current_direction}) before opening {signal}")

                    # Close position
                    execute_signal_procedure(
                        connection=connection,
                        ticker=self.symbol,
                        direction='drop',
                        volume=0,
                        order_price=None,
                        stop_loss=None,
                        take_profit=None,
                        expiry=None,
                        broker_id=self.broker_id,
                        platform_id=self.platform_id,
                        trade_id=current_position['id'],
                        trade_type='POSITION',
                        strategy_configuration_id=self.configuration_id
                    )

                    # Log close
                    cursor = connection.cursor()
                    cursor.execute("""
                        EXEC logs.sp_LogStrategyExecution 
                            @configID = ?, 
                            @signalType = 'drop',
                            @volume = ?,
                            @price = NULL,
                            @trade_uuid = ?
                    """, (self.configuration_id, 0, str(current_position['id'])))
                    connection.commit()
                    cursor.close()

                    # Set pending confirmation for close
                    self.pending_confirmation = {
                        'action': 'close_before_open',
                        'position_id': current_position['id'],
                        'new_signal': signal,
                        'time_initiated': datetime.now(pytz.UTC)
                    }
                    print(f"[MTF Trend] Waiting for close confirmation before opening {signal}")

                else:
                    # Same direction and close_existing=False - do nothing
                    print(f"[MTF Trend] Signal matches current position ({signal}), no action")

            else:
                # No position - open new
                print(f"[MTF Trend] Opening new {signal} position")
                self._open_position(connection, signal)

        except Exception as e:
            print(f"[MTF Trend] Error in process_bars_and_signals: {e}")

    def execute_force_close(self, connection):
        """
        Execute force close of all open positions.
        Called when check_force_close() returns True or on strategy termination.
        """
        print(f"[MTF Trend] Executing force close for {self.symbol}")

        try:
            # Get all open positions
            cursor = connection.cursor()
            cursor.execute("SELECT algo.fn_GetStrategyPositionIDs(?)", self.configuration_id)
            result = cursor.fetchone()

            if not result or not result[0]:
                print(f"[MTF Trend] No open positions found for force close")
                return True

            import json
            positions_data = json.loads(result[0])

            if len(positions_data) == 0:
                print(f"[MTF Trend] No open positions to close")
                return True

            # Close each position
            for position in positions_data:
                position_id = position['id']

                print(f"[MTF Trend] Closing position ID {position_id}")

                execute_signal_procedure(
                    connection=connection,
                    ticker=self.symbol,
                    direction='drop',
                    volume=0,
                    order_price=None,
                    stop_loss=None,
                    take_profit=None,
                    expiry=None,
                    broker_id=self.broker_id,
                    platform_id=self.platform_id,
                    trade_id=position_id,
                    trade_type='POSITION',
                    strategy_configuration_id=self.configuration_id
                )

                # Log close
                cursor.execute("""
                    EXEC logs.sp_LogStrategyExecution 
                        @configID = ?, 
                        @signalType = 'force_close',
                        @volume = ?,
                        @price = NULL,
                        @trade_uuid = ?
                """, (self.configuration_id, 0, str(position_id)))

            connection.commit()
            cursor.close()

            print(f"[MTF Trend] Force close completed for {len(positions_data)} position(s)")
            return True

        except Exception as e:
            print(f"[MTF Trend] Error in force close: {e}")
            return False

    def check_termination(self, connection):
        """Check if strategy should terminate"""
        # Пока всегда возвращаем False
        # TODO: Добавить проверку таблицы терминаций
        return False

    def check_force_close(self, connection):
        """Check if force close time has arrived"""
        try:
            if self.trading_close_utc is None:
                return False

            close_str = str(self.trading_close_utc).strip()

            if close_str == '00:00:00' or close_str == '':
                return False

            from datetime import time as dt_time

            if len(close_str) == 8 and close_str.count(':') == 2:
                h, m, s = map(int, close_str.split(':'))
                close_time = dt_time(h, m, s)
            else:
                print(f"[MTF Trend] Invalid time format: {close_str}")
                return False

            current_utc = datetime.now(pytz.UTC).time()

            return current_utc >= close_time

        except Exception as e:
            print(f"[MTF Trend] Error in check_force_close: {e}")
            return False


def main():
    import argparse
    parser = argparse.ArgumentParser(description='MTF Trend Strategy')
    parser.add_argument('--configID', type=int, required=True, dest='config_id',
                        help='Configuration ID from database')
    args = parser.parse_args()

    try:
        strategy = MTFTrendStrategy(args.config_id)
        print("Strategy created successfully")

        # ЗАПУСКАЕМ СТРАТЕГИЮ
        strategy.run()  # ← ДОБАВЬ ЭТУ СТРОКУ

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()