import requests
import pandas as pd
from datetime import datetime, timedelta
import struct
import gzip
import time
import os
import pyodbc

# Settings
SYMBOLS = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "XAGUSD"]
START_DATE = datetime(2023, 12, 1)  # December 2023
END_DATE = datetime(2023, 12, 31)  # 31 days
OUTPUT_FOLDER = "D:/MarketData/Month_2023_12"

# SQL Server connection
SERVER = "localhost\\MSSQL2022MD"
DATABASE = "MarketData"


def get_sql_connection():
    """Create connection to SQL Server"""
    conn_str = f"DRIVER={{SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"
    return pyodbc.connect(conn_str)


def create_tables_if_not_exist():
    """Create tables if they don't exist"""
    conn = get_sql_connection()
    cursor = conn.cursor()

    # Таблица для тиковых данных
    cursor.execute("""
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TickData')
    BEGIN
        CREATE TABLE dbo.TickData (
            TickID BIGINT IDENTITY(1,1) PRIMARY KEY,
            Symbol NVARCHAR(20) NOT NULL,
            TickTime DATETIME2(7) NOT NULL,
            BidPrice DECIMAL(18,6) NOT NULL,
            AskPrice DECIMAL(18,6) NOT NULL,
            Volume BIGINT NULL
        )

        CREATE INDEX IX_TickData_Symbol_Time ON dbo.TickData (Symbol, TickTime)
        CREATE INDEX IX_TickData_Time ON dbo.TickData (TickTime)
    END
    """)

    # Таблица для минутных баров
    cursor.execute("""
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MinuteBars')
    BEGIN
        CREATE TABLE dbo.MinuteBars (
            BarID BIGINT IDENTITY(1,1) PRIMARY KEY,
            Symbol NVARCHAR(20) NOT NULL,
            BarTime DATETIME2(0) NOT NULL,
            OpenPrice DECIMAL(18,6) NOT NULL,
            HighPrice DECIMAL(18,6) NOT NULL,
            LowPrice DECIMAL(18,6) NOT NULL,
            ClosePrice DECIMAL(18,6) NOT NULL,
            Volume BIGINT NULL
        )

        CREATE UNIQUE INDEX UQ_MinuteBars_Symbol_Time ON dbo.MinuteBars (Symbol, BarTime)
        CREATE INDEX IX_MinuteBars_Symbol ON dbo.MinuteBars (Symbol)
        CREATE INDEX IX_MinuteBars_Time ON dbo.MinuteBars (BarTime)
    END
    """)

    conn.commit()
    conn.close()
    print("Tables checked/created successfully")


def save_to_sql(data, table_name):
    """Save DataFrame to SQL Server"""
    if data.empty:
        return 0

    conn = get_sql_connection()
    cursor = conn.cursor()

    inserted = 0

    if table_name == "TickData":
        for _, row in data.iterrows():
            try:
                cursor.execute("""
                    INSERT INTO dbo.TickData (Symbol, TickTime, BidPrice, AskPrice, Volume)
                    VALUES (?, ?, ?, ?, ?)
                """, row['Symbol'], row['TickTime'], row['BidPrice'],
                               row['AskPrice'], row['Volume'])
                inserted += 1
            except pyodbc.IntegrityError:
                # Пропускаем дубликаты
                pass
            except Exception as e:
                print(f"Error inserting tick: {e}")

    elif table_name == "MinuteBars":
        for _, row in data.iterrows():
            try:
                cursor.execute("""
                    INSERT INTO dbo.MinuteBars (Symbol, BarTime, OpenPrice, HighPrice, LowPrice, ClosePrice, Volume)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, row['Symbol'], row['BarTime'], row['OpenPrice'],
                               row['HighPrice'], row['LowPrice'], row['ClosePrice'], row['Volume'])
                inserted += 1
            except pyodbc.IntegrityError:
                # Пропускаем дубликаты (уникальный индекс)
                pass
            except Exception as e:
                print(f"Error inserting bar: {e}")

    conn.commit()
    conn.close()
    return inserted


def parse_bi5_data(bi5_data, year, month, day, hour, symbol):
    """Parse BI5 binary format (months are 0-based: 0=January, 11=December)"""
    if not bi5_data:
        return []

    ticks = []
    try:
        # BI5 файлы сжаты gzip
        try:
            decompressed = gzip.decompress(bi5_data)
        except:
            decompressed = bi5_data

        tick_size = 20

        for i in range(0, len(decompressed), tick_size):
            if i + tick_size > len(decompressed):
                break

            chunk = decompressed[i:i + tick_size]

            try:
                tick = struct.unpack('>IffII', chunk)
                time_delta = tick[0]
                ask = tick[1]
                bid = tick[2]
                ask_vol = tick[3]
                bid_vol = tick[4]

                actual_month = month + 1
                if actual_month > 12:
                    actual_month = 1
                    year += 1

                base_time = datetime(year, actual_month, day, hour, 0, 0)
                tick_time = base_time + timedelta(milliseconds=time_delta)

                ticks.append({
                    'Symbol': symbol,
                    'TickTime': tick_time,
                    'BidPrice': bid,
                    'AskPrice': ask,
                    'Volume': bid_vol + ask_vol
                })
            except struct.error:
                break

    except Exception as e:
        print(f"Parse error: {e}")

    return ticks


def convert_to_minute_bars(ticks_df):
    """Convert ticks to minute bars"""
    if ticks_df.empty:
        return pd.DataFrame()

    ticks_df['BarTime'] = ticks_df['TickTime'].dt.floor('T')

    grouped = ticks_df.groupby(['Symbol', 'BarTime'])

    bars = grouped.agg({
        'BidPrice': ['first', 'max', 'min', 'last'],
        'AskPrice': ['first', 'max', 'min', 'last'],
        'Volume': 'sum'
    }).reset_index()

    bars.columns = ['Symbol', 'BarTime',
                    'BidOpen', 'BidHigh', 'BidLow', 'BidClose',
                    'AskOpen', 'AskHigh', 'AskLow', 'AskClose',
                    'Volume']

    bars['OpenPrice'] = (bars['BidOpen'] + bars['AskOpen']) / 2
    bars['HighPrice'] = (bars['BidHigh'] + bars['AskHigh']) / 2
    bars['LowPrice'] = (bars['BidLow'] + bars['AskLow']) / 2
    bars['ClosePrice'] = (bars['BidClose'] + bars['AskClose']) / 2

    return bars[['Symbol', 'BarTime', 'OpenPrice', 'HighPrice', 'LowPrice', 'ClosePrice', 'Volume']]


def download_day(symbol, date):
    """Download data for one day"""
    year = date.year
    month = date.month - 1  # Dukascopy: 0=January
    day = date.day

    daily_ticks = []

    for hour in range(24):
        url = f"https://datafeed.dukascopy.com/datafeed/{symbol}/{year}/{month:02d}/{day:02d}/{hour:02d}h_ticks.bi5"

        try:
            response = requests.get(url, timeout=15)
            if response.status_code == 200:
                ticks = parse_bi5_data(response.content, year, month, day, hour, symbol)
                daily_ticks.extend(ticks)
        except:
            continue

        time.sleep(0.03)

    return daily_ticks


def main():
    print("=" * 60)
    print("DOWNLOAD DATA FROM DUKASCOPY TO SQL SERVER")
    print("=" * 60)
    print(f"Instruments: {', '.join(SYMBOLS)}")
    print(f"Period: {START_DATE.date()} - {END_DATE.date()}")
    print(f"SQL Server: {SERVER}")
    print(f"Database: {DATABASE}")
    print("=" * 60)

    # Create tables
    print("\nChecking/Creating tables...")
    create_tables_if_not_exist()

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    total_ticks = 0
    total_bars = 0

    for symbol in SYMBOLS:
        print(f"\n{symbol}")
        print("-" * 40)

        all_ticks = []
        current_date = START_DATE
        days_processed = 0

        while current_date <= END_DATE:
            if current_date.weekday() >= 5:
                current_date += timedelta(days=1)
                continue

            print(f"  Day {days_processed + 1}: {current_date.date()}", end=" ")

            daily_ticks = download_day(symbol, current_date)

            if daily_ticks:
                all_ticks.extend(daily_ticks)
                print(f"OK {len(daily_ticks):,} ticks")
            else:
                print("No data")

            days_processed += 1
            current_date += timedelta(days=1)

        if all_ticks:
            df_ticks = pd.DataFrame(all_ticks)

            # Save ticks to SQL
            ticks_inserted = save_to_sql(df_ticks, "TickData")
            total_ticks += ticks_inserted
            print(f"  Ticks inserted to SQL: {ticks_inserted:,}")

            # Convert to minute bars
            df_bars = convert_to_minute_bars(df_ticks)

            if not df_bars.empty:
                # Save bars to SQL
                bars_inserted = save_to_sql(df_bars, "MinuteBars")
                total_bars += bars_inserted
                print(f"  Minute bars inserted: {bars_inserted:,}")

        time.sleep(1)

    print("\n" + "=" * 60)
    print("DOWNLOAD COMPLETED")
    print("=" * 60)
    print(f"Total ticks inserted: {total_ticks:,}")
    print(f"Total minute bars inserted: {total_bars:,}")
    print(f"\nCheck your SQL Server:")
    print(f"  Database: {DATABASE}")
    print(f"  Tables: TickData, MinuteBars")


if __name__ == "__main__":
    main()