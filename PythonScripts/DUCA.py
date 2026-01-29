# metals_data_fixed.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os
import yfinance as yf


def create_metals_dataset_fixed():
    """Создать полный датасет по металлам (исправленная версия)"""

    base_path = r"D:\TradingSystems\OLTP\historicalData\metals"
    os.makedirs(base_path, exist_ok=True)

    print("СОЗДАНИЕ КОМПЛЕКТНОГО ДАТАСЕТА ПО МЕТАЛЛАМ")
    print("=" * 60)

    metals = ['XAUUSD', 'XAGUSD', 'XPTUSD', 'XPDUSD']

    for metal in metals:
        print(f"\n{metal}:")

        # 1. Создать дневные данные (реальные из Yahoo)
        create_daily_data_fixed(metal, base_path)

        # 2. Создать минутные данные (синтетические)
        create_synthetic_minute_data_fixed(metal, base_path)

        # 3. Создать тиковые данные (симуляция)
        create_tick_data_fixed(metal, base_path)


def create_daily_data_fixed(metal, base_path):
    """Создать дневные данные"""

    print("  Дневные данные...")

    # Использовать соответствующие символы Yahoo Finance
    symbol_map = {
        'XAUUSD': 'GC=F',
        'XAGUSD': 'SI=F',
        'XPTUSD': 'PL=F',
        'XPDUSD': 'PA=F'
    }

    if metal in symbol_map:
        try:
            data = yf.download(
                symbol_map[metal],
                period="2y",  # 2 года истории
                interval="1d",
                auto_adjust=True,
                progress=False
            )

            if not data.empty:
                data = data.reset_index()
                data.columns = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']

                file_path = os.path.join(base_path, f"{metal}_daily.csv")
                data.to_csv(file_path, index=False)

                print(f"    Сохранено: {len(data):,} строк")
                print(f"    Цена: {data['Close'].iloc[-1]:.2f}")
                print(f"    Изменение: {(data['Close'].iloc[-1] / data['Close'].iloc[0] - 1) * 100:.1f}%")
            else:
                print("    Нет данных")

        except Exception as e:
            print(f"    Ошибка: {e}")


def create_synthetic_minute_data_fixed(metal, base_path):
    """Создать синтетические минутные данные из дневных"""

    print("  Минутные данные (синтетические)...")

    daily_file = os.path.join(base_path, f"{metal}_daily.csv")

    if not os.path.exists(daily_file):
        print("    Дневные данные не найдены")
        return

    try:
        daily_df = pd.read_csv(daily_file, parse_dates=['Date'])

        if daily_df.empty:
            print("    Дневные данные пустые")
            return

        # Создать минутные данные для каждого дня
        all_minute_data = []

        for idx, row in daily_df.iterrows():
            date = pd.to_datetime(row['Date'])
            open_price = float(row['Open'])
            high_price = float(row['High'])
            low_price = float(row['Low'])
            close_price = float(row['Close'])

            # Количество минут в торговый день (24 часа для forex)
            minutes_per_day = 1440

            # Создать минутные цены
            minute_prices = []
            current_price = open_price

            # Тренд за день
            daily_trend = (close_price - open_price) / minutes_per_day

            # Волатильность
            daily_range = high_price - low_price
            if open_price > 0:
                volatility = daily_range / open_price / minutes_per_day * np.random.uniform(0.5, 1.5)
            else:
                volatility = 0.0001

            for minute in range(minutes_per_day):
                # Случайное движение + тренд
                random_move = np.random.normal(0, volatility * current_price)
                current_price += daily_trend + random_move

                # Ограничить дневными экстремумами
                current_price = max(low_price * 0.999, min(high_price * 1.001, current_price))

                minute_prices.append(current_price)

            # Создать OHLC для каждой минуты
            for minute in range(minutes_per_day):
                dt = date + timedelta(minutes=minute)

                if minute == 0:
                    minute_open = open_price
                else:
                    minute_open = minute_prices[minute - 1]

                minute_close = minute_prices[minute]

                # Случайный спред для High/Low
                spread = minute_close * 0.0001 * np.random.uniform(0.5, 1.5)
                minute_high = max(minute_open, minute_close) + spread
                minute_low = min(minute_open, minute_close) - spread

                # Объем (случайный)
                volume = np.random.randint(50, 500)

                all_minute_data.append({
                    'DateTime': dt,
                    'Open': round(minute_open, 4),
                    'High': round(minute_high, 4),
                    'Low': round(minute_low, 4),
                    'Close': round(minute_close, 4),
                    'Volume': volume
                })

        # Сохранить минутные данные
        minute_df = pd.DataFrame(all_minute_data)
        minute_file = os.path.join(base_path, f"{metal}_1min.csv")
        minute_df.to_csv(minute_file, index=False)

        print(f"    Сохранено: {len(minute_df):,} строк")
        print(f"    Пример: {minute_df['DateTime'].iloc[0]} - {minute_df['DateTime'].iloc[-1]}")

        # Создать агрегированные таймфреймы
        create_aggregated_timeframes(minute_df, metal, base_path)

    except Exception as e:
        print(f"    Ошибка: {e}")


def create_aggregated_timeframes(minute_df, metal, base_path):
    """Создать агрегированные таймфреймы из минутных данных"""

    print("    Создание агрегированных таймфреймов...")

    # Преобразовать DateTime
    minute_df['DateTime'] = pd.to_datetime(minute_df['DateTime'])
    minute_df.set_index('DateTime', inplace=True)

    timeframes = {
        '5min': '5min',
        '15min': '15min',
        '30min': '30min',
        '1h': '1H',
        '4h': '4H',
        '1d': '1D'
    }

    for tf_name, tf_freq in timeframes.items():
        try:
            # Агрегировать данные
            aggregated = minute_df.resample(tf_freq).agg({
                'Open': 'first',
                'High': 'max',
                'Low': 'min',
                'Close': 'last',
                'Volume': 'sum'
            }).dropna()

            if not aggregated.empty:
                aggregated.reset_index(inplace=True)
                file_path = os.path.join(base_path, f"{metal}_{tf_name}.csv")
                aggregated.to_csv(file_path, index=False)
                print(f"      {tf_name}: {len(aggregated):,} строк")
        except Exception as e:
            print(f"      Ошибка создания {tf_name}: {e}")


def create_tick_data_fixed(metal, base_path):
    """Создать синтетические тиковые данные"""

    print("  Тиковые данные (синтетические)...")

    minute_file = os.path.join(base_path, f"{metal}_1min.csv")

    if not os.path.exists(minute_file):
        print("    Минутные данные не найдены")
        return

    try:
        minute_df = pd.read_csv(minute_file, parse_dates=['DateTime'])

        if minute_df.empty:
            print("    Минутные данные пустые")
            return

        # Создать тиковые данные (10 тиков в минуту)
        all_ticks = []
        ticks_per_minute = 10

        for _, row in minute_df.iterrows():
            dt = row['DateTime']
            open_price = row['Open']
            close_price = row['Close']
            high_price = row['High']
            low_price = row['Low']

            # Создать тики внутри минуты
            for tick_num in range(ticks_per_minute):
                tick_time = dt + timedelta(seconds=tick_num * 6)  # 6 секунд между тиками

                # Интерполировать цену между Open и Close
                progress = tick_num / (ticks_per_minute - 1) if ticks_per_minute > 1 else 0.5
                price = open_price + (close_price - open_price) * progress

                # Добавить небольшой шум
                noise = price * 0.00005 * np.random.randn()
                price += noise

                # Ограничить High/Low минуты
                price = max(low_price * 0.9999, min(high_price * 1.0001, price))

                # Bid/Ask спред
                spread = price * 0.0001
                bid = price - spread / 2
                ask = price + spread / 2

                # Объем
                volume = np.random.randint(1, 10)

                all_ticks.append({
                    'DateTime': tick_time,
                    'Bid': round(bid, 5),
                    'Ask': round(ask, 5),
                    'Volume': volume
                })

        # Сохранить тиковые данные
        tick_df = pd.DataFrame(all_ticks)
        tick_file = os.path.join(base_path, f"{metal}_tick.csv")

        # Сохранить только первые 100,000 строк чтобы файл не был слишком большим
        max_ticks = 100000
        if len(tick_df) > max_ticks:
            tick_df = tick_df.iloc[:max_ticks]

        tick_df.to_csv(tick_file, index=False)

        print(f"    Сохранено: {len(tick_df):,} тиков")
        print(f"    Пример: {tick_df['DateTime'].iloc[0]} - {tick_df['DateTime'].iloc[-1]}")

    except Exception as e:
        print(f"    Ошибка: {e}")


def quick_metals_minute_data():
    """Быстрое создание минутных данных металлов для тестирования"""

    base_path = r"D:\TradingSystems\OLTP\historicalData\metals"
    os.makedirs(base_path, exist_ok=True)

    print("БЫСТРОЕ СОЗДАНИЕ МИНУТНЫХ ДАННЫХ МЕТАЛЛОВ")
    print("=" * 60)

    # Параметры металлов (за 1 год)
    metals_config = {
        'XAUUSD': {
            'start_price': 2050.0,  # Золото
            'end_price': 2150.0,  # +100 за год
            'volatility': 0.0015,
            'volume_base': 100
        },
        'XAGUSD': {
            'start_price': 24.5,  # Серебро
            'end_price': 26.0,  # +1.5 за год
            'volatility': 0.0025,
            'volume_base': 500
        }
    }

    # Параметры данных
    days = 365  # 1 год
    minutes_per_day = 1440  # 24 часа * 60 минут

    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)

    for metal, config in metals_config.items():
        print(f"\n{metal}:")
        print(f"  Период: {start_date} - {end_date}")
        print(f"  Цена от: {config['start_price']:.2f} до {config['end_price']:.2f}")

        # Создать минутные интервалы
        total_minutes = days * minutes_per_day
        dates = pd.date_range(start=start_date, end=end_date, freq='1min')[:total_minutes]

        # Генерировать цены (случайное блуждание с трендом)
        np.random.seed(42)  # Для воспроизводимости

        # Ежедневный тренд
        daily_return = (config['end_price'] / config['start_price']) ** (1 / days) - 1
        minute_return = daily_return / minutes_per_day

        # Волатильность
        minute_volatility = config['volatility'] / np.sqrt(minutes_per_day)

        returns = np.random.normal(minute_return, minute_volatility, len(dates))
        prices = config['start_price'] * np.exp(np.cumsum(returns))

        # Создать OHLC данные
        data = []

        for i in range(len(dates)):
            if i == 0:
                open_price = prices[i]
            else:
                open_price = data[i - 1]['Close']

            close_price = prices[i]

            # High/Low с небольшим спредом
            spread_pct = 0.0002  # 0.02%
            high_price = max(open_price, close_price) * (1 + spread_pct * np.random.random())
            low_price = min(open_price, close_price) * (1 - spread_pct * np.random.random())

            # Объем (случайный)
            volume = int(config['volume_base'] * (1 + np.random.uniform(-0.3, 0.3)))

            data.append({
                'DateTime': dates[i],
                'Open': round(open_price, 4),
                'High': round(high_price, 4),
                'Low': round(low_price, 4),
                'Close': round(close_price, 4),
                'Volume': volume
            })

        # Сохранить
        df = pd.DataFrame(data)
        file_path = os.path.join(base_path, f"{metal}_1min.csv")
        df.to_csv(file_path, index=False)

        print(f"  Сохранено: {len(df):,} минутных баров")
        print(f"  Файл: {file_path}")

        # Создать агрегированные таймфреймы
        create_aggregated_timeframes(df, metal, base_path)

    print("\n" + "=" * 60)
    print("ДАННЫЕ ГОТОВЫ ДЛЯ ТЕСТИРОВАНИЯ")
    print("=" * 60)


# Основная функция
if __name__ == "__main__":
    print("ПОЛУЧЕНИЕ ДАННЫХ ПО МЕТАЛЛАМ")
    print("=" * 60)
    print("\nВыберите метод:")
    print("1. Быстрые синтетические минутные данные (рекомендуется для тестов)")
    print("2. Полный датасет из реальных дневных + синтетических минутных")

    choice = input("\nВведите 1 или 2: ").strip()

    if choice == "1":
        quick_metals_minute_data()
    else:
        create_metals_dataset_fixed()

    # Проверка результата
    print("\n" + "=" * 60)
    print("ПРОВЕРКА СОЗДАННЫХ ДАННЫХ")
    print("=" * 60)

    base_path = r"D:\TradingSystems\OLTP\historicalData\metals"

    if os.path.exists(base_path):
        import glob

        metals = ['XAUUSD', 'XAGUSD']

        for metal in metals:
            print(f"\n{metal}:")
            files = glob.glob(os.path.join(base_path, f"{metal}_*.csv"))

            if files:
                for file in sorted(files):
                    filename = os.path.basename(file)
                    try:
                        # Прочитать только первую строку для проверки
                        df = pd.read_csv(file, nrows=1)
                        # Получить общее количество строк
                        row_count = sum(1 for _ in open(file, 'r')) - 1  # минус заголовок
                        print(f"  {filename}: {row_count:,} строк")
                    except:
                        print(f"  {filename}: ошибка чтения")
            else:
                print(f"  Файлы не найдены")
    else:
        print("Папка metals не существует")