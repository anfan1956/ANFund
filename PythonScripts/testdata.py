# fix_and_download.py
import yfinance as yf
import pandas as pd
import os
from datetime import datetime


def download_and_fix_data():
    """Скачать и правильно сохранить данные"""

    base_path = r"D:\TradingSystems\OLTP\historicalData"

    symbols = {
        'forex': ['EURUSD=X', 'GBPUSD=X', 'USDJPY=X'],
        'stocks': ['AAPL', 'SPY']
    }

    for asset_type, symbol_list in symbols.items():
        print(f"\n=== ЗАГРУЗКА {asset_type.upper()} ===")

        for symbol in symbol_list:
            try:
                print(f"\nСкачивание {symbol}...")

                # Скачать данные
                data = yf.download(
                    symbol,
                    period="1y",  # 1 год данных
                    interval="1d",  # дневные данные
                    auto_adjust=True,  # автоматическая корректировка
                    progress=False  # не показывать прогресс-бар
                )

                # Проверить, что данные не пустые
                if data.empty:
                    print(f"  Предупреждение: {symbol} - нет данных")
                    continue

                # Сбросить индекс (дата станет колонкой)
                data = data.reset_index()

                # Переименовать колонки для единообразия
                data.columns = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']

                # Удалить строки с пропусками
                data = data.dropna()

                # Преобразовать типы данных
                numeric_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
                for col in numeric_cols:
                    if col in data.columns:
                        data[col] = pd.to_numeric(data[col], errors='coerce')

                # Сохранить
                if asset_type == 'forex':
                    symbol_clean = symbol.replace('=X', '')
                else:
                    symbol_clean = symbol

                save_path = os.path.join(base_path, asset_type, f"{symbol_clean}.csv")
                data.to_csv(save_path, index=False)

                print(f"  Сохранено: {save_path}")
                print(f"  Период: {data['Date'].min().date()} - {data['Date'].max().date()}")
                print(f"  Строк: {len(data):,}")
                print(f"  Цена (последняя): {data['Close'].iloc[-1]:.4f}")

            except Exception as e:
                print(f"  Ошибка при загрузке {symbol}: {e}")

    print("\n" + "=" * 50)
    print("ВСЕ ДАННЫЕ ЗАГРУЖЕНЫ И ОБРАБОТАНЫ")
    print("=" * 50)


def fix_existing_files():
    """Исправить уже загруженные файлы"""

    base_path = r"D:\TradingSystems\OLTP\historicalData"

    for asset_type in ['forex', 'stocks']:
        folder_path = os.path.join(base_path, asset_type)

        if not os.path.exists(folder_path):
            continue

        for file in os.listdir(folder_path):
            if file.endswith('.csv'):
                file_path = os.path.join(folder_path, file)

                try:
                    print(f"\nИсправление файла: {file}")

                    # Прочитать файл
                    df = pd.read_csv(file_path)

                    # Если в первой строке "Ticker" - это неправильный формат
                    if not df.empty and df.iloc[0, 0] == 'Ticker':
                        print("  Обнаружен неправильный формат, исправляю...")

                        # Найти строку с меткой "Date"
                        date_row_idx = None
                        for i in range(min(10, len(df))):
                            if df.iloc[i, 0] == 'Date':
                                date_row_idx = i
                                break

                        if date_row_idx is not None:
                            # Использовать следующую строку как заголовки
                            new_header = df.iloc[date_row_idx + 1]
                            df = df[date_row_idx + 2:]  # Данные начинаются со следующей строки
                            df.columns = new_header

                            # Сбросить индекс
                            df = df.reset_index(drop=True)

                            # Переименовать колонки
                            if 'Date' not in df.columns and len(df.columns) > 0:
                                df = df.rename(columns={df.columns[0]: 'Date'})

                            # Преобразовать типы данных
                            for col in df.columns:
                                if col != 'Date':
                                    df[col] = pd.to_numeric(df[col], errors='coerce')

                            # Сохранить исправленный файл
                            df.to_csv(file_path, index=False)
                            print(f"  Файл исправлен: {len(df)} строк")
                        else:
                            print("  Не могу найти строку с датами, удаляю файл...")
                            os.remove(file_path)

                    else:
                        print("  Файл уже в правильном формате")

                except Exception as e:
                    print(f"  Ошибка при исправлении {file}: {e}")


# Основная функция
if __name__ == "__main__":
    print("ИСПРАВЛЕНИЕ И ПОВТОРНАЯ ЗАГРУЗКА ДАННЫХ")
    print("=" * 60)

    # 1. Исправить существующие файлы
    print("\n1. Исправление существующих файлов...")
    fix_existing_files()

    # 2. Загрузить новые данные
    print("\n2. Загрузка новых данных...")
    download_and_fix_data()

    # 3. Проверить результат
    print("\n3. Проверка результата...")

    # Запустить проверочный скрипт
    check_script = r"D:\TradingSystems\PythonScripts\checking_the_data.py"
    if os.path.exists(check_script):
        print(f"\nЗапуск проверки: {check_script}")
        os.system(f'python "{check_script}"')
    else:
        print("\nБыстрая проверка вручную:")
        base_path = r"D:\TradingSystems\OLTP\historicalData"

        for asset_type in ['forex', 'stocks']:
            folder_path = os.path.join(base_path, asset_type)
            if os.path.exists(folder_path):
                files = [f for f in os.listdir(folder_path) if f.endswith('.csv')]
                if files:
                    sample_file = os.path.join(folder_path, files[0])
                    df = pd.read_csv(sample_file)
                    print(f"\n{asset_type.upper()} - {files[0]}:")
                    print(f"  Колонки: {list(df.columns)}")
                    print(f"  Типы: {df.dtypes.to_dict()}")
                    print(f"  Размер: {len(df)} строк")
                    if 'Close' in df.columns:
                        print(f"  Close тип: {type(df['Close'].iloc[0])}")