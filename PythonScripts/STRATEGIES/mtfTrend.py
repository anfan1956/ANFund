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

    def __init__(self, configid):
        print(f"[MTF Trend] Initializing strategy for config: {configid}")

        super().__init__(configid=configid, timer_interval=0.5, timeframe_id=1)

        # Параметры БУДУТ загружены после _register_and_load_configuration()
        self.config_data = None

        print(f"[MTF Trend] Strategy {configid} initialized (config not loaded yet)")

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

        # Параметры торговых часов (могут отсутствовать)
        self.trading_close_utc = config.get('trading_close_utc')
        self.trading_start_utc = config.get('trading_start_utc')

        self.broker_id = config['broker_id']
        self.platform_id = config['platform_id']

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
            if not hasattr(self, '_strategy_started'):
                self._strategy_started = True
                return 'buy'

            # TODO: Implement actual strategy logic here
            # For now - return None (no signal)
            return None

        except Exception as e:
            print(f"[MTF Trend] Error in get_current_signals: {e}")
            return None

    def process_bars_and_signals(self, connection, close_existing=True):
        """Process bars and trading signals"""
        try:
            # 1. Get trading signal
            signal = self.get_current_signals(connection)
            if not signal:
                return  # No signal

            print(f"[MTF Trend] Signal received: {signal} (close_existing={close_existing})")

            # 2. Check current position from framework memory
            position = self.get_position(self.configid)

            has_position = position is not None
            current_direction = position['direction'].lower() if position else None

            # 3. Handle signal based on close_existing parameter
            if has_position:
                # If close_existing=True OR directions don't match - close and open
                if close_existing or current_direction != signal:
                    print(f"[MTF Trend] Closing position {position['id']} ({current_direction}) before opening {signal}")
                    self.close_position(self.configid, position['id'])
                    # Framework will handle confirmation and opening new position
                else:
                    # Same direction and close_existing=False - do nothing
                    print(f"[MTF Trend] Signal matches current position ({signal}), no action")
            else:
                # No position - open new
                print(f"[MTF Trend] Opening new {signal} position")
                self.open_position(self.configid, signal)

        except Exception as e:
            print(f"[MTF Trend] Error in process_bars_and_signals: {e}")


def main():
    import argparse
    parser = argparse.ArgumentParser(description='MTF Trend Strategy')
    parser.add_argument('--configID', type=int, required=True, dest='config_id',
                        help='Configuration ID from database')
    args = parser.parse_args()

    try:
        strategy = MTFTrendStrategy(args.config_id)
        print("Strategy object created")

        # Register strategy and load configuration
        strategy._register_and_load_configuration()

        # NOW setup parameters from loaded config
        strategy._setup_parameters()

        print("Configuration loaded successfully")

        # ЗАПУСКАЕМ СТРАТЕГИЮ
        strategy.run()

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()