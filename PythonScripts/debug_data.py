from duka.app import Downloader
from datetime import datetime
import os
import pandas as pd
import pyodbc

# Database connection details
server = r"SERVER\MSSQL2022MD"  # Replace with your SQL Server instance
database = "MarketData"
connection_string = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};Trusted_Connection=yes;"

# Define the instrument and date range
instrument = "EURUSD"  # Replace with the desired currency pair
start_date = datetime(2023, 1, 1)  # Start date
end_date = datetime(2023, 1, 2)    # End date

# Define the output folder for downloaded data
output_folder = "./tick_data"

# Download tick data using duka
def download_tick_data_duka(instrument, start_date, end_date, output_folder):
    print(f"Downloading tick data for {instrument} from {start_date} to {end_date}...")
    Downloader(
        instruments=[instrument],
        start=start_date,
        end=end_date,
        folder=output_folder
    ).run()
    print(f"Tick data for {instrument} saved to {output_folder}")

# Insert tick data into SQL Server
def insert_tick_data_to_sql(file_path, instrument):
    try:
        # Read the CSV file into a DataFrame
        print(f"Reading tick data from {file_path}...")
        df = pd.read_csv(file_path)

        # Rename columns to match the database schema
        df.rename(columns={
            "time": "TickTime",
            "bid": "BidPrice",
            "ask": "AskPrice",
            "volume": "Volume"
        }, inplace=True)

        # Convert timestamp to datetime
        df["TickTime"] = pd.to_datetime(df["TickTime"])

        # Add the Symbol column
        df["Symbol"] = instrument

        # Connect to the database
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        # Insert data into the TickData table
        print(f"Inserting tick data for {instrument} into the database...")
        for _, row in df.iterrows():
            cursor.execute("""
                INSERT INTO dbo.TickData (Symbol, TickTime, BidPrice, AskPrice, Volume)
                VALUES (?, ?, ?, ?, ?)
            """, row["Symbol"], row["TickTime"], row["BidPrice"], row["AskPrice"], row.get("Volume", None))

        # Commit the transaction
        conn.commit()
        print(f"Successfully inserted {len(df)} ticks for {instrument} into the database.")

    except Exception as e:
        print(f"Error inserting data into the database: {e}")
    finally:
        # Close the connection
        conn.close()

# Main function
def main():
    # Download tick data
    download_tick_data_duka(instrument, start_date, end_date, output_folder)

    # Get the downloaded file path
    file_path = os.path.join(output_folder, f"{instrument}_{start_date.strftime('%Y-%m-%d')}_{end_date.strftime('%Y-%m-%d')}.csv")

    # Insert tick data into the database
    insert_tick_data_to_sql(file_path, instrument)

if __name__ == "__main__":
    main()
