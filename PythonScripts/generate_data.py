import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import pyodbc


def generate_test_data():
    """Генерация тестовых рыночных данных"""
    symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD']
    all_data = []

    for symbol in symbols:
        # 7 дней данных
        base_date = datetime(2024, 1, 1)

        for day in range(7):
            for hour in range(24):
                # 1-минутные бары
                for minute in range(0, 60, 1):
                    bar_time = base_date + \
                        timedelta(days=day, hours=hour, minutes=minute)

                    # Генерация цен
                    if symbol == 'EURUSD':
                        base_price = 1.08 + np.random.random() * 0.04
                    elif symbol == 'XAUUSD':
                        base_price = 2150 + np.random.random() * 100
                    else:
                        base_price = 1.0 + np.random.random() * 0.5

                    open_price = round(base_price, 5)
                    close_price = round(
                        open_price * (1 + np.random.uniform(-0.001, 0.001)), 5)
                    high_price = round(
                        max(open_price, close_price) * (1 + np.random.uniform(0, 0.002)), 5)
                    low_price = round(min(open_price, close_price)
                                      * (1 - np.random.uniform(0, 0.002)), 5)
                    volume = np.random.randint(1000000, 10000000)

                    all_data.append({
                        'Symbol': symbol,
                        'BarTime': bar_time,
                        'OpenPrice': open_price,
                        'HighPrice': high_price,
                        'LowPrice': low_price,
                        'ClosePrice': close_price,
                        'Volume': volume
                    })

    return pd.DataFrame(all_data)


# Запуск
print("Генерация тестовых данных...")
df = generate_test_data()
print(f"Сгенерировано {len(df)} записей")

# Сохраняем в CSV
df.to_csv('test_market_data.csv', index=False)
print("✅ Данные сохранены в test_market_data.csv")
