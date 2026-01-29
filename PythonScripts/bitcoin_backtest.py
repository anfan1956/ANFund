"""
Bitcoin EMA+RSI Scalping Strategy - Backtest
Fixed position size: 0.01 BTC
Close all positions at 23:59 UTC daily
"""

import pyodbc
import pandas as pd
from datetime import datetime, timedelta
import os
import sys


class BitcoinScalpingBacktest:
    def __init__(self):
        """Initialize database connection and strategy parameters"""
        self.connection_string = (
            'DRIVER={ODBC Driver 17 for SQL Server};'
            'SERVER=62.181.56.230;'
            'DATABASE=cTrader;'
            'UID=anfan;'
            'PWD=Gisele12!;'
        )
        self.conn = None
        self.cursor = None

        # Strategy parameters
        self.ticker_jid = 56  # Bitcoin
        self.timeframe_id = 1  # 1-minute
        self.start_date = '2026-01-10 00:00:00'

        # Trading parameters
        self.initial_capital = 10000.0
        self.capital = self.initial_capital
        self.position_size_btc = 0.01  # Fixed position size: 0.01 BTC
        self.position = None  # Current position
        self.trades = []  # Trade history
        self.daily_results = []  # Results for each day

        # Display settings
        self.current_day_trades = []  # Trades for current day

    def connect(self):
        """Connect to SQL Server database"""
        try:
            self.conn = pyodbc.connect(self.connection_string)
            self.cursor = self.conn.cursor()
            print("Connected to database successfully")
            return True
        except Exception as e:
            print(f"Connection error: {e}")
            return False

    def load_historical_data(self):
        """Load historical bars with EMA and RSI indicators"""
        print(f"Loading Bitcoin data from {self.start_date}...")

        # Сначала проверим базовые данные
        print("\n" + "=" * 70)
        print("TESTING DATA QUALITY")
        print("=" * 70)

        # Запрос 1: Получим чистые данные цен
        query_prices = """
        SELECT TOP 100
            BarTime,
            OpenValue,
            HighValue,
            LowValue,
            CloseValue as Price
        FROM tms.Bars 
        WHERE TickerJID = ?
            AND TimeFrameID = ?
            AND BarTime >= ?
        ORDER BY BarTime ASC
        """

        try:
            self.cursor.execute(query_prices, self.ticker_jid, self.timeframe_id, self.start_date)
            rows = self.cursor.fetchall()

            print(f"\nFirst 5 price records:")
            print("-"*50)
            for i, row in enumerate(rows[:5]):
                print(f"{i+1}. Time: {row[0]}, Price: ${row[4]:,.2f}")
            print("-"*50)

            # Запрос 2: Проверим EMA данные
            query_ema = """
            SELECT TOP 10
                e.BarTime,
                e.EMA_5_SHORT,
                e.EMA_20_SHORT,
                b.CloseValue as Price
            FROM tms.EMA e
            INNER JOIN tms.Bars b ON e.BarTime = b.BarTime 
                AND e.TickerJID = b.TickerJID 
                AND e.TimeFrameID = b.TimeFrameID
            WHERE e.TickerJID = ?
                AND e.TimeFrameID = ?
                AND e.BarTime >= ?
            ORDER BY e.BarTime ASC
            """

            self.cursor.execute(query_ema, self.ticker_jid, self.timeframe_id, self.start_date)
            ema_rows = self.cursor.fetchall()

            print(f"\nFirst 5 EMA records:")
            print("-" * 50)
            for i, row in enumerate(ema_rows[:5]):
                print(f"{i + 1}. Time: {row[0]}, Price: ${row[3]:,.2f}, EMA5: ${row[1]:,.2f}, EMA20: ${row[2]:,.2f}")
                # Проверим расхождение
                price = row[3]
                ema5 = row[1]
                ema20 = row[2]

                if ema5 is not None:
                    diff5 = abs((price - ema5) / price * 100)
                    print(f"   EMA5 diff: {diff5:.2f}%")
                if ema20 is not None:
                    diff20 = abs((price - ema20) / price * 100)
                    print(f"   EMA20 diff: {diff20:.2f}%")
            print("-" * 50)

            # Теперь основной запрос
            print(f"\nLoading full dataset...")

            main_query = """
            SELECT 
                b.BarTime,
                b.CloseValue as Price,
                ema.EMA_5_SHORT as EMA_5,
                ema.EMA_20_SHORT as EMA_20,
                mom.RSI_14
            FROM tms.Bars b
            LEFT JOIN tms.EMA ema ON b.BarTime = ema.BarTime 
                AND b.TickerJID = ema.TickerJID 
                AND b.TimeFrameID = ema.TimeFrameID
            LEFT JOIN tms.Indicators_Momentum mom ON b.BarTime = mom.BarTime 
                AND b.TickerJID = mom.TickerJID 
                AND b.TimeFrameID = mom.TimeFrameID
            WHERE b.TickerJID = ?
                AND b.TimeFrameID = ?
                AND b.BarTime >= ?
            ORDER BY b.BarTime ASC
            """

            self.cursor.execute(main_query, self.ticker_jid, self.timeframe_id, self.start_date)
            rows = self.cursor.fetchall()

            columns = ['BarTime', 'Price', 'EMA_5', 'EMA_20', 'RSI_14']
            df = pd.DataFrame.from_records(rows, columns=columns)

            # Проверим качество данных
            print(f"\n" + "=" * 70)
            print("DATA QUALITY REPORT")
            print("=" * 70)
            print(f"Total rows loaded: {len(df)}")
            print(f"Rows with missing EMA_5: {df['EMA_5'].isna().sum()}")
            print(f"Rows with missing EMA_20: {df['EMA_20'].isna().sum()}")
            print(f"Rows with missing RSI_14: {df['RSI_14'].isna().sum()}")

            # Проверим несколько строк на аномалии
            anomalous_rows = []
            for idx, row in df.iterrows():
                if not pd.isna(row['EMA_5']) and not pd.isna(row['Price']):
                    diff = abs((row['Price'] - row['EMA_5']) / row['Price'] * 100)
                    if diff > 50:  # Если разница более 50%
                        anomalous_rows.append((row['BarTime'], row['Price'], row['EMA_5'], diff))
                        if len(anomalous_rows) >= 5:
                            break

            if anomalous_rows:
                print(f"\nWARNING: Found {len(anomalous_rows)} anomalous EMA values (>50% difference from price)")
                for time, price, ema5, diff in anomalous_rows[:5]:
                    print(f"  {time}: Price=${price:,.2f}, EMA5=${ema5:,.2f}, Diff={diff:.1f}%")

            # Если EMA некорректные, будем рассчитывать их сами
            if df['EMA_5'].isna().sum() > len(df) * 0.5 or (anomalous_rows and len(anomalous_rows) > 10):
                print(f"\n\033[91mWARNING: EMA data appears to be incorrect or missing\033[0m")
                print("Will calculate EMA indicators locally...")
                df = self.calculate_local_indicators(df)
            else:
                print(f"\n\033[92mData quality OK\033[0m")

            print(f"\nLoaded {len(df)} 1-minute bars")
            return df

        except Exception as e:
            print(f"Data loading error: {e}")
            return pd.DataFrame()

    def calculate_local_indicators(self, df):
        """Calculate EMA and RSI indicators locally"""
        print("Calculating local indicators...")

        # Calculate EMA_5
        df['EMA_5_local'] = df['Price'].ewm(span=5, adjust=False).mean()

        # Calculate EMA_20
        df['EMA_20_local'] = df['Price'].ewm(span=20, adjust=False).mean()

        # Calculate RSI_14
        delta = df['Price'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['RSI_14_local'] = 100 - (100 / (1 + rs))

        # Use local indicators if database ones are missing/incorrect
        df['EMA_5_final'] = df['EMA_5'].combine_first(df['EMA_5_local'])
        df['EMA_20_final'] = df['EMA_20'].combine_first(df['EMA_20_local'])
        df['RSI_14_final'] = df['RSI_14'].combine_first(df['RSI_14_local'])

        print(f"Local indicators calculated successfully")

        # Show comparison
        print(f"\nIndicator comparison (first 5 rows):")
        print("-" * 80)
        for i in range(min(5, len(df))):
            row = df.iloc[i]
            print(f"{i + 1}. Time: {row['BarTime'].strftime('%H:%M')}, Price: ${row['Price']:,.2f}")
            print(f"   DB EMA5: ${row['EMA_5']:,.2f} | Local EMA5: ${row['EMA_5_local']:,.2f} | Final: ${row['EMA_5_final']:,.2f}")
            print(f"   DB EMA20: ${row['EMA_20']:,.2f} | Local EMA20: ${row['EMA_20_local']:,.2f} | Final: ${row['EMA_20_final']:,.2f}")
            print(f"   DB RSI: {row['RSI_14']:.1f} | Local RSI: {row['RSI_14_local']:.1f} | Final: {row['RSI_14_final']:.1f}")
            print("-" * 40)

        return df

    def check_buy_signal(self, current, previous):
        """Check conditions for BUY signal"""
        # Используем финальные индикаторы
        ema_5 = current['EMA_5_final'] if 'EMA_5_final' in current else current['EMA_5']
        ema_20 = current['EMA_20_final'] if 'EMA_20_final' in current else current['EMA_20']
        rsi = current['RSI_14_final'] if 'RSI_14_final' in current else current['RSI_14']
        price = current['Price']

        if pd.isna(ema_5) or pd.isna(ema_20) or pd.isna(rsi):
            return False, []

        conditions = []

        # Price > EMA_20
        if price > ema_20:
            conditions.append(f"Price ${price:,.2f} > EMA20 ${ema_20:,.2f}")
        else:
            return False, []

        # EMA_5 > EMA_20
        if ema_5 > ema_20:
            conditions.append(f"EMA5 ${ema_5:,.2f} > EMA20 ${ema_20:,.2f}")
        else:
            return False, []

        # RSI_14 < 75 (aggressive)
        if rsi < 75:
            conditions.append(f"RSI_14={rsi:.1f} < 75")
        else:
            return False, []

        # RSI is rising
        if previous is not None:
            prev_rsi = previous['RSI_14_final'] if 'RSI_14_final' in previous else previous['RSI_14']
            if not pd.isna(prev_rsi) and rsi > prev_rsi:
                conditions.append(f"RSI rising: {prev_rsi:.1f} → {rsi:.1f}")
            else:
                return False, []

        return True, conditions

    def check_close_long_signal(self, current):
        """Check conditions to close LONG position"""
        if self.position and self.position['type'] == 'LONG':
            rsi = current['RSI_14_final'] if 'RSI_14_final' in current else current['RSI_14']

            # Close LONG if RSI > 75 (overbought)
            if rsi > 75:
                return True, [f"RSI_14={rsi:.1f} > 75 (overbought)"]

        return False, []

    def print_header(self, title, color_code="\033[96m"):
        """Print colored header"""
        print(f"\n{color_code}{'=' * 70}\033[0m")
        print(f"{color_code}{title:^70}\033[0m")
        print(f"{color_code}{'=' * 70}\033[0m")

    def execute_trade(self, signal_type, price, bar_time, conditions):
        """Execute trade with fixed 0.01 BTC position size"""
        if signal_type == 'BUY' and self.position is None:
            # Open LONG position
            self.position = {
                'type': 'LONG',
                'entry_price': price,
                'entry_time': bar_time,
                'entry_conditions': conditions,
                'volume_btc': self.position_size_btc
            }

            position_value_usd = price * self.position_size_btc

            self.print_header("BUY SIGNAL EXECUTED", "\033[92m")
            print(f"TIME:        {bar_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"ACTION:      \033[92mBUY {self.position_size_btc} BTC\033[0m")
            print(f"PRICE:       \033[92m${price:,.2f}\033[0m")
            print(f"POSITION:    ${position_value_usd:,.2f}")
            print(f"CAPITAL:     ${self.capital:,.2f}")
            print("CONDITIONS:")
            for i, cond in enumerate(conditions, 1):
                print(f"  {i}. \033[92m{cond}\033[0m")
            print(f"\033[92m{'=' * 70}\033[0m")

        elif signal_type == 'CLOSE_LONG' and self.position and self.position['type'] == 'LONG':
            # Close LONG position
            entry_price = self.position['entry_price']
            volume_btc = self.position['volume_btc']

            # Calculate P&L
            profit_usd = volume_btc * (price - entry_price)
            profit_pct = ((price - entry_price) / entry_price) * 100

            # Update capital
            self.capital += profit_usd

            trade_duration = bar_time - self.position['entry_time']
            duration_minutes = trade_duration.total_seconds() / 60

            trade = {
                'entry_time': self.position['entry_time'],
                'exit_time': bar_time,
                'entry_price': entry_price,
                'exit_price': price,
                'volume_btc': volume_btc,
                'profit_usd': profit_usd,
                'profit_pct': profit_pct,
                'duration_minutes': duration_minutes,
                'conditions': self.position['entry_conditions'] + conditions
            }
            self.trades.append(trade)
            self.current_day_trades.append(trade)

            # Determine color based on profit/loss
            if profit_usd >= 0:
                color = "\033[92m"  # Green for profit
                result = "PROFITABLE"
            else:
                color = "\033[91m"  # Red for loss
                result = "LOSS"

            # Display trade result
            self.print_header("TRADE CLOSED", color)
            print(f"TIME:           {bar_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"ACTION:         {color}SELL {volume_btc} BTC\033[0m")
            print(f"ENTRY PRICE:    ${entry_price:,.2f}")
            print(f"EXIT PRICE:     {color}${price:,.2f}\033[0m")
            print(f"POSITION SIZE:  {volume_btc} BTC (${price * volume_btc:,.2f})")
            print(f"TRADE DURATION: {duration_minutes:.1f} minutes")

            if profit_usd >= 0:
                print(f"PROFIT:         {color}+${profit_usd:,.2f} (+{profit_pct:.2f}%)\033[0m")
                print(f"RESULT:         {color}{result}\033[0m")
            else:
                print(f"LOSS:           {color}${profit_usd:,.2f} ({profit_pct:.2f}%)\033[0m")
                print(f"RESULT:         {color}{result}\033[0m")

            print(f"CAPITAL:        ${self.capital:,.2f}")
            print("CONDITIONS:")
            for i, cond in enumerate(conditions, 1):
                print(f"  {i}. {color}{cond}\033[0m")
            print(f"{color}{'=' * 70}\033[0m")

            # Reset position
            self.position = None

    def show_day_summary(self, day_date, day_trades, day_start_capital, day_end_capital):
        """Display summary for a trading day"""
        if not day_trades:
            print(f"\n\033[93mNo trades on {day_date}\033[0m")
            return

        self.print_header(f"DAY SUMMARY: {day_date}", "\033[95m")

        total_trades = len(day_trades)
        profitable_trades = len([t for t in day_trades if t['profit_usd'] > 0])
        losing_trades = len([t for t in day_trades if t['profit_usd'] < 0])

        total_profit = sum(t['profit_usd'] for t in day_trades)
        avg_profit = total_profit / total_trades if total_trades > 0 else 0
        win_rate = (profitable_trades / total_trades * 100) if total_trades > 0 else 0

        day_return = ((day_end_capital - day_start_capital) / day_start_capital * 100)

        print(f"TRADES TODAY:    {total_trades}")
        print(f"WIN RATE:        {win_rate:.1f}% ({profitable_trades}/{total_trades})")
        print(f"DAILY P&L:       \033[92m${total_profit:,.2f}\033[0m")
        print(f"AVG P&L/TRADE:   \033[92m${avg_profit:,.2f}\033[0m")
        print(f"DAY RETURN:      \033[92m{day_return:.2f}%\033[0m")
        print(f"START CAPITAL:   ${day_start_capital:,.2f}")
        print(f"END CAPITAL:     ${day_end_capital:,.2f}")

        # Individual trades
        print(f"\n\033[96mINDIVIDUAL TRADES:\033[0m")
        for i, trade in enumerate(day_trades, 1):
            profit_sign = "+" if trade['profit_usd'] >= 0 else ""
            color = "\033[92m" if trade['profit_usd'] > 0 else "\033[91m" if trade['profit_usd'] < 0 else "\033[93m"

            print(f"  Trade #{i}: {trade['entry_time'].strftime('%H:%M')} → {trade['exit_time'].strftime('%H:%M')} | "
                  f"{color}{profit_sign}${trade['profit_usd']:,.2f} ({profit_sign}{trade['profit_pct']:.2f}%)\033[0m")

        # Save daily result
        self.daily_results.append({
            'date': day_date,
            'trades': total_trades,
            'profitable': profitable_trades,
            'total_profit': total_profit,
            'start_capital': day_start_capital,
            'end_capital': day_end_capital,
            'return_pct': day_return
        })

    def ask_continue_next_day(self, next_day):
        """Ask user to continue to next day or skip"""
        print(f"\n\033[93m{'=' * 70}")
        print(f"END OF TRADING DAY")
        print(f"{'=' * 70}\033[0m")

        print(f"\nNext trading day: \033[96m{next_day}\033[0m")
        print(f"Current capital:  \033[92m${self.capital:,.2f}\033[0m")

        print("\nOptions:")
        print("1. Continue to next day")
        print("2. Skip this day (no trading)")
        print("3. Show detailed statistics")
        print("4. Exit backtest")

        while True:
            choice = input("\nEnter choice (1-4): ").strip()
            if choice in ['1', '2', '3', '4']:
                return choice
            print("Invalid choice. Please enter 1, 2, 3 or 4.")

    def show_statistics(self):
        """Display overall trading statistics"""
        if not self.trades:
            print("\nNo completed trades")
            return

        self.print_header("OVERALL TRADING STATISTICS", "\033[96m")

        total_trades = len(self.trades)
        profitable_trades = len([t for t in self.trades if t['profit_usd'] > 0])
        losing_trades = len([t for t in self.trades if t['profit_usd'] < 0])

        total_profit = sum(t['profit_usd'] for t in self.trades)
        total_wins = sum(t['profit_usd'] for t in self.trades if t['profit_usd'] > 0)
        total_losses = sum(t['profit_usd'] for t in self.trades if t['profit_usd'] < 0)

        avg_profit = total_profit / total_trades if total_trades > 0 else 0
        avg_win = total_wins / profitable_trades if profitable_trades > 0 else 0
        avg_loss = total_losses / losing_trades if losing_trades > 0 else 0

        win_rate = (profitable_trades / total_trades * 100) if total_trades > 0 else 0

        profit_factor = abs(total_wins / total_losses) if total_losses != 0 else float('inf')

        print(f"TOTAL TRADES:     {total_trades}")
        print(f"PROFITABLE:       {profitable_trades} (\033[92m{win_rate:.1f}%\033[0m)")
        print(f"LOSING:           {losing_trades}")
        print(f"TOTAL PROFIT:     \033[92m${total_profit:,.2f}\033[0m")
        print(f"AVG PROFIT/TRADE: \033[92m${avg_profit:,.2f}\033[0m")
        print(f"AVG WIN:          \033[92m${avg_win:,.2f}\033[0m")
        print(f"AVG LOSS:         \033[91m${avg_loss:,.2f}\033[0m")
        print(f"PROFIT FACTOR:    {profit_factor:.2f}")
        print(f"INITIAL CAPITAL:  ${self.initial_capital:,.2f}")
        print(f"FINAL CAPITAL:    \033[92m${self.capital:,.2f}\033[0m")
        print(f"TOTAL RETURN:     \033[92m{((self.capital - self.initial_capital) / self.initial_capital * 100):.2f}%\033[0m")

        # Show daily results summary
        if self.daily_results:
            print(f"\n\033[96mDAILY PERFORMANCE:\033[0m")
            for day in self.daily_results:
                color = "\033[92m" if day['total_profit'] > 0 else "\033[91m" if day['total_profit'] < 0 else "\033[93m"
                print(f"  {day['date']}: {day['trades']} trades, {color}${day['total_profit']:,.2f} ({day['return_pct']:.2f}%)\033[0m")

    def clear_screen(self):
        """Clear console screen"""
        os.system('cls' if os.name == 'nt' else 'clear')

    def run_backtest(self, mode='manual'):
        """Run backtest in specified mode"""
        if not self.connect():
            return

        df = self.load_historical_data()
        if df.empty:
            print("No data for backtest")
            return

        self.clear_screen()
        self.print_header(f"BITCOIN EMA+RSI SCALPING BACKTEST ({mode.upper()} MODE)", "\033[96m")
        print(f"Date Range: {df.iloc[0]['BarTime'].date()} to {df.iloc[-1]['BarTime'].date()}")
        print(f"Total Bars: {len(df)}")
        print(f"Position Size: {self.position_size_btc} BTC fixed")
        print(f"Initial Capital: ${self.initial_capital:,.2f}")
        print(f"\n\033[93mStarting backtest...\033[0m")
        input("\nPress Enter to begin...")

        previous_row = None
        current_day = None
        day_start_capital = self.capital

        # Group data by day for easier processing
        df['Date'] = df['BarTime'].dt.date
        unique_days = df['Date'].unique()

        for day_num, day_date in enumerate(unique_days, 1):
            self.clear_screen()
            print(f"\n\033[94m{'=' * 70}")
            print(f"DAY {day_num}: {day_date}")
            print(f"{'=' * 70}\033[0m")

            # Ask user what to do with this day
            if day_num > 1:  # Not the first day
                choice = self.ask_continue_next_day(day_date)

                if choice == '2':  # Skip day
                    print(f"\n\033[93mSkipping {day_date}...\033[0m")
                    continue
                elif choice == '3':  # Show stats
                    self.show_statistics()
                    input("\nPress Enter to continue... ")
                    continue
                elif choice == '4':  # Exit
                    print(f"\n\033[93mBacktest terminated by user.\033[0m")
                    break

            # Reset daily trades
            self.current_day_trades = []
            day_start_capital = self.capital

            # Get data for current day
            day_data = df[df['Date'] == day_date]

            print(f"\n\033[93mTrading day {day_date} started. {len(day_data)} bars to process.\033[0m")
            input("\nPress Enter to start trading...")

            for idx, row in day_data.iterrows():
                bar_time = row['BarTime']
                price = row['Price']

                # Get correct indicator values
                if 'EMA_5_final' in row:
                    ema_5 = row['EMA_5_final']
                    ema_20 = row['EMA_20_final']
                    rsi = row['RSI_14_final']
                else:
                    ema_5 = row['EMA_5']
                    ema_20 = row['EMA_20']
                    rsi = row['RSI_14']

                # Skip bars without indicators
                if pd.isna(ema_5) or pd.isna(ema_20) or pd.isna(rsi):
                    continue

                # Check for end of day close (23:59 UTC)
                if bar_time.hour == 23 and bar_time.minute == 59:
                    if self.position:
                        self.print_header(f"END OF TRADING DAY: {bar_time.strftime('%Y-%m-%d %H:%M:%S')}", "\033[93m")
                        print("FORCED CLOSE at end of day")

                        if mode == 'manual':
                            input("Press Enter to close position... ")

                        self.execute_trade('CLOSE_LONG', price, bar_time, ["End of trading day (23:59 UTC)"])
                    continue

                # Display bar info
                if self.position:
                    entry_price = self.position['entry_price']
                    current_pnl_usd = self.position_size_btc * (price - entry_price)
                    current_pnl_pct = ((price - entry_price) / entry_price) * 100
                    pnl_sign = "+" if current_pnl_usd >= 0 else ""
                    pnl_color = "\033[92m" if current_pnl_usd >= 0 else "\033[91m"

                    print(f"[{bar_time.strftime('%H:%M:%S')}] Price: ${price:,.2f} | RSI: {rsi:.1f} | "
                          f"Position: {pnl_color}{pnl_sign}${abs(current_pnl_usd):,.2f} ({pnl_sign}{abs(current_pnl_pct):.2f}%)\033[0m")
                else:
                    print(f"[{bar_time.strftime('%H:%M:%S')}] Price: ${price:,.2f} | RSI: {rsi:.1f} | "
                          f"EMA5: ${ema_5:,.2f} | EMA20: ${ema_20:,.2f}")

                # Check trading signals
                buy_signal, buy_conditions = self.check_buy_signal(row, previous_row)
                close_signal, close_conditions = self.check_close_long_signal(row)

                # Process signals
                if buy_signal and self.position is None:
                    print(f"\n\033[92m{'=' * 60}")
                    print(f"BUY SIGNAL DETECTED!")
                    print(f"{'=' * 60}\033[0m")
                    print(f"   Time:  {bar_time.strftime('%H:%M:%S')}")
                    print(f"   Price: ${price:,.2f} | EMA_5: ${ema_5:,.2f} | EMA_20: ${ema_20:,.2f} | RSI: {rsi:.1f}")

                    if mode == 'manual':
                        input("\n\033[92mPress Enter to execute BUY...\033[0m ")

                    self.execute_trade('BUY', price, bar_time, buy_conditions)

                elif close_signal and self.position and self.position['type'] == 'LONG':
                    print(f"\n\033[91m{'=' * 60}")
                    print(f"CLOSE SIGNAL DETECTED!")
                    print(f"{'=' * 60}\033[0m")
                    print(f"   Time:  {bar_time.strftime('%H:%M:%S')}")
                    print(f"   Price: ${price:,.2f} | RSI: {rsi:.1f} (overbought)")

                    if mode == 'manual':
                        input("\n\033[91mPress Enter to execute SELL...\033[0m ")

                    self.execute_trade('CLOSE_LONG', price, bar_time, close_conditions)

                # Save previous row
                previous_row = row

            # Show day summary
            self.show_day_summary(day_date, self.current_day_trades, day_start_capital, self.capital)

            # Pause at end of day
            if day_num < len(unique_days):  # Not the last day
                input("\nPress Enter to see options for next day...")

        # Close any open position at the end
        if self.position:
            self.print_header("END OF BACKTEST", "\033[93m")
            print("FORCED CLOSE at end of backtest")
            last_price = df.iloc[-1]['Price']
            self.execute_trade('CLOSE_LONG', last_price, df.iloc[-1]['BarTime'],
                               ["End of backtest forced close"])

        # Close connection
        self.cursor.close()
        self.conn.close()

        # Show final statistics
        self.clear_screen()
        self.show_statistics()


def main():
    """Main function"""
    print("\033[96m" + "=" * 70)
    print("BITCOIN EMA+RSI SCALPING STRATEGY - BACKTEST")
    print("=" * 70 + "\033[0m")
    print(f"Position Size: 0.01 BTC fixed")
    print(f"Start Date: 2026-01-10")
    print(f"Timeframe: 1-minute")
    print("\033[96m" + "=" * 70 + "\033[0m")

    # Select mode
    print("\nSelect mode:")
    print("1. Manual (confirm each signal)")
    print("2. Automatic (execute all signals)")

    while True:
        choice = input("\nEnter 1 or 2: ").strip()
        if choice in ['1', '2']:
            break
        print("Invalid choice. Please enter 1 or 2.")

    mode = 'manual' if choice == '1' else 'auto'

    # Run backtest
    trader = BitcoinScalpingBacktest()
    trader.run_backtest(mode=mode)

    # Pause at end
    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()