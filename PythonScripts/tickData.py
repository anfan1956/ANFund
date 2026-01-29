#!/usr/bin/env python3
"""
TickData.com Downloader & Organizer
Downloads historical tick data and saves to structured CSV format
"""

import os
import pandas as pd
import numpy as np
import requests
import zipfile
import io
import gzip
import json
from datetime import datetime, timedelta
import time
from typing import List, Dict, Optional
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TickDataDownloader:
    """Download and organize tick data from TickData.com"""

    def __init__(self, api_key: str = None, base_path: str = None):
        """
        Initialize the downloader

        Args:
            api_key: Your TickData.com API key (optional for manual download)
            base_path: Base directory to save data
        """
        self.api_key = api_key or os.getenv('TICKDATA_API_KEY')
        self.base_path = base_path or r'D:\TradingSystems\OLTP\historicalData'

        # Create directory structure
        self.create_directory_structure()

        # API endpoints (hypothetical - check actual TickData.com API)
        self.api_base = "https://api.tickdata.com/v1"

        # Common symbol mappings
        self.symbol_mappings = {
            'EURUSD': 'EUR/USD',
            'GBPUSD': 'GBP/USD',
            'USDJPY': 'USD/JPY',
            'XAUUSD': 'XAU/USD',
            'SPX': 'SPX500',
            # Add more as needed
        }

    def create_directory_structure(self):
        """Create organized directory structure"""
        directories = [
            self.base_path,
            os.path.join(self.base_path, 'forex'),
            os.path.join(self.base_path, 'forex', 'tick'),
            os.path.join(self.base_path, 'forex', 'minute'),
            os.path.join(self.base_path, 'forex', 'daily'),
            os.path.join(self.base_path, 'stocks'),
            os.path.join(self.base_path, 'stocks', 'tick'),
            os.path.join(self.base_path, 'futures'),
            os.path.join(self.base_path, 'futures', 'tick'),
            os.path.join(self.base_path, 'indices'),
            os.path.join(self.base_path, 'indices', 'tick'),
            os.path.join(self.base_path, 'raw'),
            os.path.join(self.base_path, 'processed'),
            os.path.join(self.base_path, 'metadata'),
        ]

        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            logger.info(f"Created directory: {directory}")

    def download_via_api(self, symbol: str, start_date: str, end_date: str,
                         data_type: str = 'tick') -> Optional[pd.DataFrame]:
        """
        Download data via TickData.com API

        Args:
            symbol: Trading symbol (e.g., 'EURUSD')
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            data_type: 'tick', 'minute', or 'daily'

        Returns:
            DataFrame with the downloaded data
        """
        if not self.api_key:
            logger.error("API key not provided. Use manual download instead.")
            return None

        headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

        params = {
            'symbol': self.symbol_mappings.get(symbol, symbol),
            'start_date': start_date,
            'end_date': end_date,
            'data_type': data_type,
            'format': 'csv'
        }

        try:
            logger.info(f"Downloading {symbol} {data_type} data from {start_date} to {end_date}")

            response = requests.get(
                f"{self.api_base}/download",
                headers=headers,
                params=params,
                timeout=30
            )

            if response.status_code == 200:
                # Parse CSV response
                df = pd.read_csv(io.StringIO(response.text))
                logger.info(f"Downloaded {len(df)} records")
                return df
            else:
                logger.error(f"API request failed: {response.status_code}")
                return None

        except Exception as e:
            logger.error(f"Error downloading via API: {e}")
            return None

    def download_manual_file(self, file_path: str, symbol: str = None) -> Optional[pd.DataFrame]:
        """
        Process manually downloaded TickData.com files

        Args:
            file_path: Path to downloaded file (CSV, ZIP, TXT)
            symbol: Symbol name (if not in filename)

        Returns:
            DataFrame with parsed data
        """
        try:
            # Determine file type and read accordingly
            if file_path.endswith('.zip'):
                return self._read_zip_file(file_path, symbol)
            elif file_path.endswith('.csv'):
                return self._read_csv_file(file_path, symbol)
            elif file_path.endswith('.txt'):
                return self._read_text_file(file_path, symbol)
            elif file_path.endswith('.gz'):
                return self._read_gzip_file(file_path, symbol)
            else:
                logger.error(f"Unsupported file format: {file_path}")
                return None

        except Exception as e:
            logger.error(f"Error reading file {file_path}: {e}")
            return None

    def _read_zip_file(self, file_path: str, symbol: str) -> pd.DataFrame:
        """Read data from ZIP file"""
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            # Assume single CSV file inside
            for file_name in zip_ref.namelist():
                if file_name.endswith('.csv'):
                    with zip_ref.open(file_name) as f:
                        df = pd.read_csv(f)
                        return self._parse_tickdata_format(df, symbol)
        return pd.DataFrame()

    def _read_csv_file(self, file_path: str, symbol: str) -> pd.DataFrame:
        """Read data from CSV file"""
        df = pd.read_csv(file_path)
        return self._parse_tickdata_format(df, symbol)

    def _read_text_file(self, file_path: str, symbol: str) -> pd.DataFrame:
        """Read data from text file"""
        # TickData.com text files often have specific formats
        df = pd.read_csv(file_path, sep='\t|,|;', engine='python')
        return self._parse_tickdata_format(df, symbol)

    def _read_gzip_file(self, file_path: str, symbol: str) -> pd.DataFrame:
        """Read data from gzip file"""
        with gzip.open(file_path, 'rt') as f:
            df = pd.read_csv(f)
            return self._parse_tickdata_format(df, symbol)

    def _parse_tickdata_format(self, df: pd.DataFrame, symbol: str) -> pd.DataFrame:
        """
        Parse TickData.com specific format

        Common TickData.com formats:
        1. DateTime, Bid, Ask, Volume
        2. Date, Time, Bid, Ask, Volume
        3. Epoch, Bid, Ask, Volume
        """
        # Standardize column names
        column_mapping = {
            'datetime': 'timestamp',
            'date': 'date',
            'time': 'time',
            'bid': 'bid',
            'ask': 'ask',
            'volume': 'volume',
            'epoch': 'timestamp',
            'close': 'bid',  # Sometimes close is used for bid
            'open': 'bid',
            'high': 'bid',
            'low': 'bid'
        }

        df.columns = [column_mapping.get(col.lower(), col) for col in df.columns]

        # Create unified timestamp if separate date/time columns
        if 'date' in df.columns and 'time' in df.columns:
            df['timestamp'] = pd.to_datetime(df['date'] + ' ' + df['time'])
            df.drop(['date', 'time'], axis=1, inplace=True)

        # Convert timestamp if it exists
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'])

        # Add symbol column
        df['symbol'] = symbol

        # Reorder columns
        columns = ['timestamp', 'symbol', 'bid', 'ask', 'volume']
        df = df[[col for col in columns if col in df.columns]]

        return df

    def save_to_csv(self, df: pd.DataFrame, symbol: str, data_type: str = 'tick'):
        """
        Save DataFrame to organized CSV structure

        Args:
            df: DataFrame with tick data
            symbol: Trading symbol
            data_type: 'tick', 'minute', or 'daily'
        """
        if df.empty:
            logger.warning(f"No data to save for {symbol}")
            return

        # Determine asset class
        asset_class = self._get_asset_class(symbol)

        # Create filename
        start_date = df['timestamp'].min().strftime('%Y%m%d')
        end_date = df['timestamp'].max().strftime('%Y%m%d')

        filename = f"{symbol}_{data_type}_{start_date}_{end_date}.csv"

        # Determine save path
        if asset_class == 'forex':
            save_dir = os.path.join(self.base_path, 'forex', data_type)
        elif asset_class == 'stock':
            save_dir = os.path.join(self.base_path, 'stocks', data_type)
        elif asset_class == 'future':
            save_dir = os.path.join(self.base_path, 'futures', data_type)
        else:
            save_dir = os.path.join(self.base_path, 'indices', data_type)

        os.makedirs(save_dir, exist_ok=True)
        save_path = os.path.join(save_dir, filename)

        # Save to CSV
        df.to_csv(save_path, index=False)
        logger.info(f"Saved {len(df)} records to {save_path}")

        # Also save to raw directory for backup
        raw_path = os.path.join(self.base_path, 'raw', filename)
        df.to_csv(raw_path, index=False)

        # Update metadata
        self._update_metadata(df, symbol, data_type, save_path)

    def _get_asset_class(self, symbol: str) -> str:
        """Determine asset class from symbol"""
        symbol = symbol.upper()

        # Forex pairs (3-6 letters ending with USD, EUR, etc.)
        forex_pairs = ['EUR', 'GBP', 'JPY', 'CHF', 'AUD', 'CAD', 'NZD', 'XAU', 'XAG']
        if any(symbol.endswith(curr) for curr in forex_pairs) or '/' in symbol:
            return 'forex'

        # Stocks (typically 1-5 letters)
        elif len(symbol) <= 5 and symbol.isalpha():
            return 'stock'

        # Futures (often contain numbers or specific patterns)
        elif any(x in symbol for x in ['F', 'G', 'H', 'J', 'K', 'M', 'N', 'Q', 'U', 'V', 'X', 'Z']):
            return 'future'

        # Indices
        elif any(x in symbol for x in ['SPX', 'NDX', 'DJI', 'RUT', 'DAX', 'FTSE', 'NIKKEI']):
            return 'index'

        else:
            return 'unknown'

    def _update_metadata(self, df: pd.DataFrame, symbol: str, data_type: str, file_path: str):
        """Update metadata JSON file"""
        metadata_file = os.path.join(self.base_path, 'metadata', 'data_catalog.json')

        # Load existing metadata or create new
        if os.path.exists(metadata_file):
            with open(metadata_file, 'r') as f:
                metadata = json.load(f)
        else:
            metadata = {}

        # Create entry
        entry_key = f"{symbol}_{data_type}"

        metadata[entry_key] = {
            'symbol': symbol,
            'data_type': data_type,
            'file_path': file_path,
            'records': len(df),
            'start_date': df['timestamp'].min().isoformat(),
            'end_date': df['timestamp'].max().isoformat(),
            'bid_range': {
                'min': float(df['bid'].min()),
                'max': float(df['bid'].max()),
                'mean': float(df['bid'].mean())
            },
            'ask_range': {
                'min': float(df['ask'].min()),
                'max': float(df['ask'].max()),
                'mean': float(df['ask'].mean())
            },
            'added_date': datetime.now().isoformat()
        }

        # Save metadata
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)

        logger.info(f"Updated metadata for {symbol}")

    def aggregate_to_minute(self, tick_df: pd.DataFrame) -> pd.DataFrame:
        """Aggregate tick data to 1-minute bars"""
        if tick_df.empty:
            return pd.DataFrame()

        # Resample to 1-minute bars
        tick_df.set_index('timestamp', inplace=True)

        minute_df = tick_df.resample('1T').agg({
            'bid': ['first', 'max', 'min', 'last'],
            'ask': ['first', 'max', 'min', 'last'],
            'volume': 'sum'
        })

        # Flatten column multi-index
        minute_df.columns = ['_'.join(col).strip() for col in minute_df.columns.values]

        # Rename columns to standard OHLCV
        column_mapping = {
            'bid_first': 'bid_open',
            'bid_max': 'bid_high',
            'bid_min': 'bid_low',
            'bid_last': 'bid_close',
            'ask_first': 'ask_open',
            'ask_max': 'ask_high',
            'ask_min': 'ask_low',
            'ask_last': 'ask_close',
            'volume_sum': 'volume'
        }

        minute_df.rename(columns=column_mapping, inplace=True)
        minute_df.reset_index(inplace=True)
        minute_df['symbol'] = tick_df['symbol'].iloc[0] if 'symbol' in tick_df.columns else ''

        return minute_df

    def batch_process_directory(self, source_dir: str, data_type: str = 'tick'):
        """
        Process all files in a directory

        Args:
            source_dir: Directory containing downloaded files
            data_type: Type of data in files
        """
        if not os.path.exists(source_dir):
            logger.error(f"Source directory does not exist: {source_dir}")
            return

        processed_count = 0
        failed_files = []

        for filename in os.listdir(source_dir):
            file_path = os.path.join(source_dir, filename)

            if os.path.isfile(file_path):
                # Try to extract symbol from filename
                symbol = self._extract_symbol_from_filename(filename)

                logger.info(f"Processing {filename} as {symbol}")

                try:
                    # Read file
                    df = self.download_manual_file(file_path, symbol)

                    if df is not None and not df.empty:
                        # Save tick data
                        self.save_to_csv(df, symbol, data_type)

                        # Also create minute bars if tick data
                        if data_type == 'tick':
                            minute_df = self.aggregate_to_minute(df)
                            if not minute_df.empty:
                                self.save_to_csv(minute_df, symbol, 'minute')

                        processed_count += 1
                    else:
                        failed_files.append(filename)

                except Exception as e:
                    logger.error(f"Failed to process {filename}: {e}")
                    failed_files.append(filename)

        logger.info(f"Processing complete. Successful: {processed_count}, Failed: {len(failed_files)}")

        if failed_files:
            logger.warning("Failed files:")
            for f in failed_files:
                logger.warning(f"  - {f}")

    def _extract_symbol_from_filename(self, filename: str) -> str:
        """Extract symbol from filename using common patterns"""
        # Remove extensions
        name = os.path.splitext(filename)[0]

        # Common patterns in TickData.com filenames
        patterns = [
            r'([A-Z]{6})_',  # Forex like EURUSD_
            r'([A-Z]{1,5})_',  # Stocks like AAPL_
            r'([A-Z]{2,6}\d{0,2}[FGHJKMNQUVXZ]?)_',  # Futures
            r'([A-Z]{3,10}\.?)'  # General symbol
        ]

        import re
        for pattern in patterns:
            match = re.search(pattern, name)
            if match:
                return match.group(1)

        # Fallback: use first part before underscore
        if '_' in name:
            return name.split('_')[0]

        return name


def main():
    """Main function demonstrating usage"""

    # Initialize downloader
    downloader = TickDataDownloader(
        api_key=None,  # Set your API key here or use environment variable
        base_path=r'D:\TradingSystems\OLTP\historicalData'
    )

    # Option 1: Download via API (if you have API access)
    # df = downloader.download_via_api(
    #     symbol='EURUSD',
    #     start_date='2024-01-01',
    #     end_date='2024-01-31',
    #     data_type='tick'
    # )
    # if df is not None:
    #     downloader.save_to_csv(df, 'EURUSD', 'tick')

    # Option 2: Process manually downloaded files
    # Put your downloaded TickData.com files in this directory
    manual_files_dir = r'D:\TradingSystems\OLTP\raw_downloads'

    if os.path.exists(manual_files_dir):
        logger.info(f"Processing files from {manual_files_dir}")
        downloader.batch_process_directory(manual_files_dir, data_type='tick')
    else:
        logger.warning(f"Manual files directory not found: {manual_files_dir}")

        # Create example structure with sample data
        create_sample_structure(downloader.base_path)


def create_sample_structure(base_path: str):
    """Create sample directory structure with dummy data for testing"""
    sample_dir = os.path.join(base_path, 'sample_data')
    os.makedirs(sample_dir, exist_ok=True)

    # Create sample CSV file
    dates = pd.date_range('2024-01-01', '2024-01-05', freq='1s')
    n_samples = len(dates)

    sample_data = pd.DataFrame({
        'timestamp': dates,
        'bid': 1.1000 + np.random.randn(n_samples) * 0.0005,
        'ask': 1.1002 + np.random.randn(n_samples) * 0.0005,
        'volume': np.random.randint(1, 100, n_samples)
    })

    sample_file = os.path.join(sample_dir, 'EURUSD_tick_20240101_20240105.csv')
    sample_data.to_csv(sample_file, index=False)

    logger.info(f"Created sample file: {sample_file}")
    logger.info(f"Sample directory structure created at {base_path}")


if __name__ == "__main__":
    main()