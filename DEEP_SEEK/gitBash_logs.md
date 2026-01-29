Sasha@SERVER MINGW64 /d/TradingSystems/PythonScripts
$ python mtf_rsi_ema_strategy.py --config-id 3
Parameters setup complete:
  Symbol: BTCUSD
  Ticker JID: 56
  Signal TF ID: 1
  Confirmation TF ID: 3
  Trend TF ID: 5
  Volume: 0.02
  Trading hours: 00:00:00 to 00:00:00
Strategy 3 running for BTCUSD
======================================================================
Config ID: 3
Ticker: BTCUSD
Volume: 0.02 lots
Daily Close: 00:00:00 UTC
Press Ctrl+C to stop
======================================================================

No existing position found.
Opening initial position...

Opening initial BUY position for BTCUSD
Volume: 0.02 lots
[2026-01-24 21:53:14] Signal SENT: BTCUSD buy volume=0.02, Trade ID: None, Type: None
Waiting for position confirmation...
  Check 1/20: Position not yet confirmed...
Position confirmed: ID=5858, Direction=Buy
Initial position opened successfully
  Position ID: 5858

======================================================================
Strategy monitoring started
======================================================================
[Termination DB] Found 0 pending termination(s)
[Termination Service] No termination for config_id: 3
DEBUG: Running strategy iteration 1
[18:54:14] BTCUSD: 89275.42 | Pos: ID:5858 Buy | Signal: NO_SIGNAL | Confirmation: NO_SIGNAL | Trend: NO_DATA | Close: TIME_PASSED
[Termination DB] Found 0 pending termination(s)
[Termination Service] No termination for config_id: 3
DEBUG: Running strategy iteration 2
[18:55:00] BTCUSD: 89275.42 | Pos: ID:5858 Buy | Signal: NO_SIGNAL | Confirmation: NO_SIGNAL | Trend: BULLISH | Close: TIME_PASSED
[Termination DB] Found 0 pending termination(s)
[Termination Service] No termination for config_id: 3
DEBUG: Running strategy iteration 3
[18:56:00] BTCUSD: 89257.99 | Pos: ID:5858 Buy | Signal: NO_SIGNAL | Confirmation: NO_SIGNAL | Trend: NO_DATA | Close: TIME_PASSED
[Termination DB] Found 0 pending termination(s)
[Termination Service] No termination for config_id: 3
DEBUG: Running strategy iteration 4
[18:57:00] BTCUSD: 89255.46 | Pos: ID:5858 Buy | Signal: NO_SIGNAL | Confirmation: NO_SIGNAL | Trend: NO_DATA | Close: TIME_PASSED
[Termination DB] Found 1 pending termination(s)
[Termination DB] Config 3: ID 14, Requested 2026-01-24 18:57:03.673000
[Termination Service] Found termination for config_id: 3
[Termination Service] Details: {'termination_id': 14, 'requested_at': datetime.datetime(2026, 1, 24, 18, 57, 3, 673000)}

[Termination] Strategy 3 termination requested at 2026-01-24 18:57:03.673000
[Termination] Termination ID: 14
Error updating tracker state: ('42000', '[42000] [Microsoft][ODBC Driver 17 for SQL Server][SQL Server]Invalid state (50000) (SQLExecDirectW)')
[Termination] Closing 1 open position(s)...
  Closing position ID=5858 (Direction: Buy)
[2026-01-24 21:58:00] Signal SENT: BTCUSD drop volume=0.02, Trade ID: 5858, Type: POSITION

======================================================================
[Termination] Strategy 3 terminated successfully
Exiting program...
======================================================================

Sasha@SERVER MINGW64 /d/TradingSystems/PythonScripts
$
