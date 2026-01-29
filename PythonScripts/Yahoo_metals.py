# get_metals_data.py
import yfinance as yf
import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta
import requests
import time


def get_metals_data():
    """Получить данные по металлам"""

    base_path = r"D:\TradingSystems\OLTP\historicalData"

    # Создать папку для металлов
    metals_path = os.path.join(base_path, 'metals')
    os.makedirs(metals_path, exist_ok=True)

    print("=== ПОЛУЧЕНИЕ ДАННЫХ ПО МЕТАЛЛАМ ===")

    # Металлы через Yahoo Finance (только дневные данные)
    metals = {
        'XAUUSD': 'GC=F',  # Gold Futures
        'XAGUSD': 'SI=F',  # Silver Futures
        'XPTUSD': 'PL=F',  # Platinum Futures
        'XPDUSD': 'PA=F',  # Palladium Futures
    }

    # 1. Получить дневные данные (это работает)
    print("\n1. Загрузка ДНЕВНЫХ данных металлов...")

    for metal_name, yahoo_symbol in metals.items():
        try:
            print(f"\n{metal_name} ({yahoo_symbol})...")

            # Дневные данные за 1 год
            data = yf.download(
                yahoo_symbol,
                period="1y",
                interval="1d",
                auto_adjust=True,
                progress=False
            )

            if data.empty:
                print(f"  Нет данных для {metal_name}")
                continue

            # Подготовить данные
            data = data.reset_index()
            data.columns = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']
            data = data.dropna()

            # Сохранить
            save_path = os.path.join(metals_path, f"{metal_name}_daily.csv")
            data.to_csv(save_path, index=False)

            print(f"  Сохранено: {save_path}")
            print(f"  Период: {data['Date'].min().date()} - {data['Date'].max().date()}")
            print(f"  Строк: {len(data):,}")
            print(f"  Цена: {data['Close'].iloc[-1]:.2f}")

        except Exception as e:
            print(f"  Ошибка: {e}")

    # 2. Попытка получить минутные данные через альтернативные источники
    print("\n2. Попытка получить МИНУТНЫЕ данные...")

    # OANDA API (требуется аккаунт)
    # try_oanda_metals()

    # Dukascopy (бесплатно, но нужна конвертация)
    try_dukascopy_metals()

    print("\n" + "=" * 60)
    print("ВСЕ ДАННЫЕ ПО МЕТАЛЛАМ ОБРАБОТАНЫ")
    print("=" * 60)


def try_dukascopy_metals():
    """Попробовать получить данные с Dukascopy"""

    print("\nПроверка Dukascopy для металлов...")

    # Dukascopy предоставляет данные для XAUUSD и XAGUSD
    metals_dukascopy = {
        'XAUUSD': 'XAUUSD',
        'XAGUSD': 'XAGUSD'
    }

    for metal_name, duka_symbol in metals_dukascopy.items():
        try:
            # Dukascopy предоставляет данные в формате:
            # https://www.dukascopy.com/datafeed/{symbol}/{year}/{month}/{day}/{hour}h_ticks.bi5

            # Для примера, создадим синтетические минутные данные из дневных
            print(f"  Создание синтетических минутных данных для {metal_name}...")
            create_synthetic_minute_data(metal_name)

        except Exception as e:
            print(f"  Ошибка для {metal_name}: {e}")


def create_synthetic_minute_data(metal_name):
    """Создать синтетические минутные данные из дневных"""

    base_path = r"D:\TradingSystems\OLTP\historicalData"
    daily_file = os.path.join(base_path, 'metals', f"{metal_name}_daily.csv")

    if not os.path.exists(daily_file):
        print(f"    Дневные данные не найдены: {daily_file}")
        return

    try:
        # Прочитать дневные данные
        daily_df = pd.read_csv(daily_file, parse_dates=['Date'])

        if daily_df.empty:
            print(f"    Файл пустой: {daily_file}")
            return

        # Создать минутные данные (синтетические)
        minute_data = []

        for _, row in daily_df.iterrows():
            date = pd.to_datetime(row['Date'])

            # Создать 1440 минутных баров для одного дня (24 часа * 60 минут)
            # Используем случайное блуждание внутри дня

            open_price = row['Open']
            high_price = row['High']
            low_price = row['Low']
            close_price = row['Close']

            # Создать минутные цены
            minutes_in_day = 1440
            prices = []

            # Начальная цена
            current_price = open_price

            # Целевое изменение за день
            daily_change = close_price - open_price

            # Случайное блуждание с трендом к закрытию
            for minute in range(minutes_in_day):
                # Волатильность уменьшается к концу дня
                volatility = 0.0005 * (1 - minute / minutes_in_day)

                # Тренд к закрытию
                trend = daily_change / minutes_in_day

                # Случайное движение
                random_move = np.random.normal(0, volatility)

                # Обновить цену
                current_price = current_price + trend + random_move

                # Ограничить High/Low дня
                current_price = min(high_price, max(low_price, current_price))

                prices.append(current_price)

            # Создать минутные бары
            for minute in range(minutes_in_day):
                minute_time = date + timedelta(minutes=minute)

                if minute == 0:
                    minute_open = open_price
                else:
                    minute_open = prices[minute - 1] if minute > 0 else open_price

                minute_close = prices[minute]

                # Простое High/Low для минуты
                minute_high = max(minute_open, minute_close) * (1 + np.random.uniform(0, 0.0001))
                minute_low = min(minute_open, minute_close) * (1 - np.random.uniform(0, 0.0001))

                minute_data.append({
                    'DateTime': minute_time,
                    'Open': minute_open,
                    'High': minute_high,
                    'Low': minute_low,
                    'Close': minute_close,
                    'Volume': np.random.randint(10, 100)
                })

        # Создать DataFrame
        minute_df = pd.DataFrame(minute_data)

        # Сохранить
        metals_path = os.path.join(base_path, 'metals')
        minute_file = os.path.join(metals_path, f"{metal_name}_minute_synthetic.csv")
        minute_df.to_csv(minute_file, index=False)

        print(f"    Создано: {minute_file}")
        print(f"    Строк: {len(minute_df):,}")
        print(f"    Период: {minute_df['DateTime'].min()} - {minute_df['DateTime'].max()}")

    except Exception as e:
        print(f"    Ошибка создания синтетических данных: {e}")


def get_metals_from_alternative_sources():
    """Получить данные металлов из альтернативных источников"""

    print("\n=== АЛЬТЕРНАТИВНЫЕ ИСТОЧНИКИ ДАННЫХ ===")

    # 1. Metals-API (бесплатный план: 100 запросов/месяц)
    try:
        print("\n1. Проверка Metals-API...")
        metals_api_key = "YOUR_API_KEY"  # Нужно зарегистрироваться на metals-api.com

        # Пример для получения текущей цены золота
        # url = f"https://metals-api.com/api/latest?access_key={metals_api_key}&base=USD&symbols=XAU"
        # response = requests.get(url)
        # print(f"   Ответ: {response.status_code}")

        print("   Для работы нужен API ключ с metals-api.com")

    except Exception as e:
        print(f"   Ошибка Metals-API: {e}")

    # 2. Alpha Vantage (бесплатно, но ограничения)
    try:
        print("\n2. Проверка Alpha Vantage...")
        alpha_vantage_key = "YOUR_API_KEY"  # Нужно зарегистрироваться на alphavantage.co

        # Золото: GLD ETF или GC=F фьючерсы
        # Серебро: SLV ETF или SI=F фьючерсы
        print("   Предоставляет данные через символы ETF: GLD, SLV")

    except Exception as e:
        print(f"   Ошибка Alpha Vantage: {e}")

    # 3. Quandl (бесплатно, ограниченные данные)
    try:
        print("\n3. Проверка Quandl...")
        # LBMA/GOLD для золота, LBMA/SILVER для серебра
        print("   Источник: LBMA Gold Price, LBMA Silver Price")

    except Exception as e:
        print(f"   Ошибка Quandl: {e}")


def get_historical_gold_silver():
    """Получить исторические данные золота и серебра"""

    print("\n=== ИСТОРИЧЕСКИЕ ДАННЫЕ ЗОЛОТА И СЕРЕБРА ===")

    # Использовать данные ETF как proxy
    etf_mapping = {
        'XAUUSD': 'GLD',  # SPDR Gold Shares ETF
        'XAGUSD': 'SLV',  # iShares Silver Trust ETF
    }

    base_path = r"D:\TradingSystems\OLTP\historicalData\metals"

    for metal_name, etf_symbol in etf_mapping.items():
        try:
            print(f"\n{metal_name} через {etf_symbol}...")

            # Получить данные ETF
            data = yf.download(
                etf_symbol,
                period="1y",
                interval="1d",
                auto_adjust=True,
                progress=False
            )

            if data.empty:
                print(f"  Нет данных для {etf_symbol}")
                continue

            # Конвертировать в металл (приблизительно)
            # GLD ≈ 1/10 ounce of gold, SLV ≈ 1 ounce of silver
            conversion_factor = 10 if metal_name == 'XAUUSD' else 1

            data = data.reset_index()
            data.columns = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']

            # Конвертировать цены
            for col in ['Open', 'High', 'Low', 'Close']:
                data[col] = data[col] * conversion_factor

            data['Volume'] = data['Volume'] * conversion_factor

            # Сохранить
            save_path = os.path.join(base_path, f"{metal_name}_from_etf.csv")
            data.to_csv(save_path, index=False)

            print(f"  Сохранено: {save_path}")
            print(f"  Цена: {data['Close'].iloc[-1]:.2f} (конвертировано из {etf_symbol})")

        except Exception as e:
            print(f"  Ошибка: {e}")


# Основная функция
if __name__ == "__main__":

    print("ЗАГРУЗКА ДАННЫХ ПО МЕТАЛЛАМ")
    print("=" * 60)

    # 1. Получить дневные данные через Yahoo Finance
    get_metals_data()

    # 2. Получить данные через ETF
    get_historical_gold_silver()

    # 3. Проверить что получилось
    print("\n" + "=" * 60)
    print("ПРОВЕРКА ЗАГРУЖЕННЫХ ДАННЫХ")
    print("=" * 60)

    base_path = r"D:\TradingSystems\OLTP\historicalData\metals"

    if os.path.exists(base_path):
        files = [f for f in os.listdir(base_path) if f.endswith('.csv')]

        if files:
            print(f"\nНайдено файлов: {len(files)}")
            for file in files:
                file_path = os.path.join(base_path, file)
                try:
                    df = pd.read_csv(file_path)
                    print(f"\n{file}:")
                    print(f"  Строк: {len(df):,}")
                    if 'Date' in df.columns:
                        print(f"  Период: {df['Date'].iloc[0]} - {df['Date'].iloc[-1]}")
                    print(f"  Цена: {df['Close'].iloc[-1] if 'Close' in df.columns else 'N/A'}")
                except:
                    print(f"\n{file}: ошибка чтения")
        else:
            print("Файлы не найдены")
    else:
        print("Папка metals не существует")