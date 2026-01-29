import requests

# Проверим USA500.IDX и другие возможные форматы
test_symbols = [
    "USA500.IDX",
    "USA500",
    "US500.IDX",
    "SP500.IDX",
    "SPX.IDX",
    "SPX500.IDX",
    "INDEX:USA500",
    "INDEX:SPX",
    "US.IDX/USD",
    "SPX/USD"
]

base_url = "https://datafeed.dukascopy.com/datafeed"

print("Проверка индексов с .IDX расширением...")
print("=" * 50)

for symbol in test_symbols:
    test_url = f"{base_url}/{symbol}/2024/01/01/00h_ticks.bi5"

    try:
        response = requests.head(test_url, timeout=5)
        if response.status_code == 200:
            print(f"✅ {symbol}: ДАННЫЕ ДОСТУПНЫ!")
            # Дополнительная проверка
            resp_get = requests.get(test_url, timeout=10)
            if resp_get.status_code == 200:
                print(f"   Размер: {len(resp_get.content)} байт")
                # Проверим если это реальные данные
                if len(resp_get.content) > 100:
                    print(f"   Вероятно реальные данные")
                else:
                    print(f"   Возможно пустой файл")
        elif response.status_code == 404:
            print(f"❌ {symbol}: не найдено")
        else:
            print(f"⚠ {symbol}: статус {response.status_code}")
    except Exception as e:
        print(f"✗ {symbol}: ошибка - {e}")
