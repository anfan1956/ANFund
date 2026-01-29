Понял. Вот структура в запрошенном формате:

```
1. IMPORTS SECTION
   import json                                                      -- Standard library imports
   import time                                                      -- Standard library imports  
   import sys                                                       -- Standard library imports
   import argparse                                                  -- Standard library imports
   from datetime import datetime, time as time_type                 -- Standard library imports
   
   import pyodbc                                                    -- Third-party imports (pyodbc, pytz, etc.)
   import pytz                                                      -- Third-party imports (pyodbc, pytz, etc.)
   
   from sp_create_signal import execute_signal_procedure            -- Local module imports (sp_create_signal, strategy_termination)
   from strategy_termination import StrategyTerminationService      -- Local module imports (sp_create_signal, strategy_termination)

2. CONSTANTS SECTION
   CONNECTION_STRING = (                                            -- Connection string
       'DRIVER={ODBC Driver 17 for SQL Server};'
       'SERVER=62.181.56.230;'
       'DATABASE=cTrader;'
       'UID=anfan;'
       'PWD=Gisele12!;'
   )
   
   last_signal_bar_time = None                                      -- Other global constants
   last_confirmation_bar_time = None                                -- Other global constants  
   last_trend_bar_time = None                                       -- Other global constants
   last_heartbeat_time = None                                       -- Other global constants

3. class MTFRSIEMAStrategy:                                         -- MTFRSIEMAStrategy CLASS
   
   a. def __init__(self, configuration_id: int)                     -- __init__() method
   
   b. def _get_connection(self)                                     -- Database connection methods
   
   c. def _load_configuration(self)                                 -- Configuration loading methods
   
   d. def _setup_parameters(self)                                   -- Parameter setup methods
   
   e. def get_open_positions(self, connection_string, ticker)       -- Market data methods
      def get_current_price(self, connection_string, ticker_jid)    -- Market data methods
      def get_latest_bar_data(self, connection_string, ticker_jid, timeframe_id, timeframe_name) -- Market data methods
   
   f. def check_trend(self, connection_string, ticker_jid, timeframe_id) -- Signal checking methods
      def check_signal_signal_tf(self, connection_string, ticker_jid, timeframe_id) -- Signal checking methods
      def check_signal_confirmation_tf(self, connection_string, ticker_jid, timeframe_id) -- Signal checking methods
   
   g. def ensure_single_position(self, connection_string, ticker, broker_id, platform_id, strategy_configuration_id) -- Position management methods
      def wait_for_position_confirmation(self, connection_string, ticker, expected_direction, max_checks, check_interval_seconds) -- Position management methods
      def open_initial_position(self, connection_string, ticker, open_volume, broker_id, platform_id, strategy_configuration_id, max_checks, check_interval_seconds) -- Position management methods
   
   h. def check_force_close(self, connection_string, ticker, close_time_utc, broker_id, platform_id, strategy_configuration_id) -- Time management methods
      def check_trading_hours(self, connection_string, ticker)      -- Time management methods
      def send_heartbeat(self, config_id, connection_string)        -- Time management methods
   
   i. def process_trading_signal(self, connection_string, ticker, open_volume, broker_id, platform_id, strategy_configuration_id, signal_signal, confirmation_signal, trend, positions) -- Trading logic methods
   
   j. def run_strategy(self, connection_string, ticker, ticker_jid, open_volume, close_time_utc, broker_id, platform_id, strategy_configuration_id, timeframe_signal_id, timeframe_confirmation_id, timeframe_trend_id, max_position_checks, check_interval_seconds) -- Main strategy execution methods
      def run(self)                                                 -- Main strategy execution methods
   
   k. def _update_tracker_state(self, state: str)                   -- Utility/helper methods
      def show_minute_info(self, ticker, market_info, signal_signal, confirmation_signal, trend) -- Utility/helper methods
      def get_market_info(self, connection_string, ticker, ticker_jid, close_time_utc) -- Utility/helper methods

4. if __name__ == "__main__":                                       -- MAIN EXECUTION BLOCK
      parser = argparse.ArgumentParser(description='MTF RSI EMA Trading Strategy') -- Argument parsing
      parser.add_argument('--config-id', type=int, required=True, help='Configuration ID from database') -- Argument parsing
      args = parser.parse_args()                                    -- Argument parsing
      
      strategy = MTFRSIEMAStrategy(args.config_id)                  -- Strategy instantiation
      strategy.run()                                                -- Strategy execution
   except Exception as e:                                           -- Error handling
      print(f"Error: {e}")                                          -- Error handling
      sys.exit(1)                                                   -- Error handling
```