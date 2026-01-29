import requests
from bs4 import BeautifulSoup
import pandas as pd
from datetime import datetime
import time
import random
import json


def get_forex_factory_calendar(date='today'):
    """
    Парсинг экономического календаря Forex Factory
    date: 'today', 'tomorrow', или конкретная дата 'Dec15.2024'
    """

    # Определяем URL в зависимости от даты
    if date == 'today':
        url = "https://www.forexfactory.com/calendar?day=today"
    elif date == 'tomorrow':
        url = "https://www.forexfactory.com/calendar?day=tomorrow"
    else:
        url = f"https://www.forexfactory.com/calendar?day={date}"

    print(f"🌐 Загружаю календарь: {url}")

    # Современные заголовки браузера
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'en-US,en;q=0.9,ru;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
        'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
    }

    # Случайная задержка
    time.sleep(random.uniform(2, 4))

    try:
        response = requests.get(url, headers=headers, timeout=15)
        print(f"✅ HTTP статус: {response.status_code}")

        if response.status_code != 200:
            print(f"❌ Ошибка загрузки: {response.status_code}")
            return pd.DataFrame()

        # Парсим HTML
        soup = BeautifulSoup(response.text, 'html.parser')

        # ВАРИАНТ 1: Ищем по структуре таблицы
        events = []

        # Находим все строки календаря
        rows = soup.find_all('tr', class_='calendar_row')

        # Если не нашли, пробуем другие классы
        if not rows:
            rows = soup.find_all('tr', class_='calendar__row')

        if not rows:
            # Пробуем найти по родительскому контейнеру
            calendar_div = soup.find('div', class_='calendar')
            if calendar_div:
                rows = calendar_div.find_all('tr')[1:]  # Пропускаем заголовок

        print(f"📊 Найдено строк: {len(rows)}")

        for i, row in enumerate(rows):
            try:
                # Получаем все ячейки в строке
                cells = row.find_all('td')
                if len(cells) < 6:
                    continue

                # Парсим каждую ячейку
                # Ячейка времени (обычно первая)
                time_cell = cells[0]
                event_time = time_cell.get_text(strip=True)

                # Ячейка валюты
                currency_cell = cells[1]
                currency = currency_cell.get_text(strip=True)

                # Ячейка важности
                impact_cell = cells[2]
                impact_span = impact_cell.find('span')
                if impact_span:
                    impact = impact_span.get('title', '')
                else:
                    impact = impact_cell.get_text(strip=True)

                # Ячейка события
                event_cell = cells[3]
                event_name = event_cell.get_text(separator=' ', strip=True)

                # Ячейка фактического значения
                actual_cell = cells[4]
                actual = actual_cell.get_text(strip=True)

                # Ячейка прогноза
                forecast_cell = cells[5]
                forecast = forecast_cell.get_text(strip=True)

                # Ячейка предыдущего значения
                previous_cell = cells[6] if len(cells) > 6 else None
                previous = previous_cell.get_text(strip=True) if previous_cell else ''

                event_data = {
                    'time': event_time,
                    'currency': currency,
                    'impact': impact,
                    'event': event_name,
                    'actual': actual,
                    'forecast': forecast,
                    'previous': previous
                }

                events.append(event_data)

                # Выводим первые 3 события для проверки
                if i < 3:
                    print(f"\n📝 Пример события {i + 1}:")
                    print(f"  Время: {event_time}")
                    print(f"  Валюта: {currency}")
                    print(f"  Важность: {impact}")
                    print(f"  Событие: {event_name[:50]}...")

            except Exception as e:
                print(f"⚠️ Ошибка обработки строки {i}: {e}")
                continue

        print(f"\n🎯 Всего извлечено событий: {len(events)}")

        if events:
            df = pd.DataFrame(events)

            # Фильтруем пустые события
            df = df[df['event'].str.len() > 0]

            # Фильтруем по важности
            high_impact = df[df['impact'].str.contains('High|Высокая', case=False, na=False)]
            medium_impact = df[df['impact'].str.contains('Medium|Средняя', case=False, na=False)]

            print(f"🔴 Высокая важность: {len(high_impact)}")
            print(f"🟡 Средняя важность: {len(medium_impact)}")
            print(f"🟢 Низкая важность: {len(df) - len(high_impact) - len(medium_impact)}")

            # Сохраняем в файл для проверки
            df.to_csv('forexfactory_events.csv', index=False, encoding='utf-8-sig')
            print("💾 Данные сохранены в forexfactory_events.csv")

            return df
        else:
            print("❌ Не удалось извлечь события")
            return pd.DataFrame()

    except requests.exceptions.RequestException as e:
        print(f"❌ Ошибка сети: {e}")
        return pd.DataFrame()
    except Exception as e:
        print(f"❌ Общая ошибка: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame()


# АЛЬТЕРНАТИВНЫЙ МЕТОД - более простой
def get_calendar_simple():
    """Упрощенный метод для тестирования"""

    url = "https://www.forexfactory.com/calendar.php?day=today"

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }

    try:
        response = requests.get(url, headers=headers)
        print(f"Статус: {response.status_code}")

        # Быстрая проверка на наличие данных
        if 'calendar' in response.text.lower():
            print("✅ Календарь найден в HTML")

            # Ищем временные метки
            import re
            time_pattern = r'(\d{1,2}:\d{2}[ap]m)'
            times = re.findall(time_pattern, response.text)
            print(f"Найдено временных меток: {len(times)}")

            # Ищем названия событий
            event_pattern = r'event">([^<]+)</td>'
            events = re.findall(event_pattern, response.text)
            print(f"Найдено событий: {len(events)}")

            # Сохраняем сырой HTML для анализа
            with open('debug_raw.html', 'w', encoding='utf-8') as f:
                f.write(response.text[:5000])  # Первые 5000 символов

            return True
        else:
            print("❌ Календарь не найден в ответе")
            return False

    except Exception as e:
        print(f"Ошибка: {e}")
        return False


# МЕТОД с использованием Selenium (если сайт использует JavaScript)
def get_calendar_selenium():
    """Использование Selenium для динамических страниц"""
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.common.by import By
        from selenium.webdriver.support.ui import WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC

        print("🚀 Запуск Selenium...")

        # Настройки Chrome
        options = Options()
        options.add_argument('--headless')  # Без GUI
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--window-size=1920,1080')
        options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')

        driver = webdriver.Chrome(options=options)

        try:
            driver.get("https://www.forexfactory.com/calendar")

            # Ждем загрузки календаря
            wait = WebDriverWait(driver, 10)
            wait.until(EC.presence_of_element_located((By.CLASS_NAME, "calendar")))

            # Получаем HTML после загрузки JS
            html = driver.page_source

            # Сохраняем для анализа
            with open('selenium_output.html', 'w', encoding='utf-8') as f:
                f.write(html)

            print("✅ Страница загружена через Selenium")
            print(f"Длина HTML: {len(html)} символов")

            # Парсим BeautifulSoup
            soup = BeautifulSoup(html, 'html.parser')

            # Поиск событий
            events = []
            rows = soup.find_all('tr', class_='calendar_row')

            for row in rows:
                try:
                    cells = row.find_all('td')
                    if len(cells) >= 5:
                        event_data = {
                            'time': cells[0].get_text(strip=True),
                            'currency': cells[1].get_text(strip=True),
                            'impact': cells[2].get_text(strip=True),
                            'event': cells[3].get_text(strip=True),
                            'actual': cells[4].get_text(strip=True) if len(cells) > 4 else '',
                            'forecast': cells[5].get_text(strip=True) if len(cells) > 5 else '',
                            'previous': cells[6].get_text(strip=True) if len(cells) > 6 else ''
                        }
                        events.append(event_data)
                except:
                    continue

            print(f"📊 Найдено событий через Selenium: {len(events)}")

            if events:
                df = pd.DataFrame(events)
                df.to_csv('selenium_events.csv', index=False)
                return df
            else:
                return pd.DataFrame()

        finally:
            driver.quit()

    except ImportError:
        print("❌ Selenium не установлен. Установите: pip install selenium")
        return pd.DataFrame()
    except Exception as e:
        print(f"❌ Ошибка Selenium: {e}")
        return pd.DataFrame()


# РЕКОМЕНДУЕМЫЙ МЕТОД - используйте сторонний API
def get_economic_calendar_api():
    """Использование бесплатного API вместо парсинга"""

    # Вариант 1: Financial Modeling Prep (бесплатный ключ)
    def get_fmp_calendar():
        try:
            # Получите бесплатный ключ на https://site.financialmodelingprep.com/developer/docs
            API_KEY = "demo"  # Замените на свой ключ

            url = f"https://financialmodelingprep.com/api/v3/economic_calendar"
            params = {
                'from': datetime.now().strftime('%Y-%m-%d'),
                'to': datetime.now().strftime('%Y-%m-%d'),
                'apikey': API_KEY
            }

            response = requests.get(url, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()
                df = pd.DataFrame(data)
                print(f"✅ Получено {len(df)} событий от FMP API")
                return df
            else:
                print(f"❌ Ошибка API: {response.status_code}")
                return pd.DataFrame()

        except Exception as e:
            print(f"❌ Ошибка FMP API: {e}")
            return pd.DataFrame()

    # Вариант 2: Twelve Data (бесплатный тариф)
    def get_twelve_data():
        try:
            API_KEY = "demo"  # Замените на свой ключ

            url = "https://api.twelvedata.com/economic_calendar"
            params = {
                'country': 'all',
                'date': datetime.now().strftime('%Y-%m-%d'),
                'apikey': API_KEY
            }

            response = requests.get(url, params=params)
            data = response.json()

            if 'data' in data:
                df = pd.DataFrame(data['data'])
                print(f"✅ Получено {len(df)} событий от Twelve Data")
                return df
            else:
                print("❌ Нет данных в ответе")
                return pd.DataFrame()

        except Exception as e:
            print(f"❌ Ошибка Twelve Data: {e}")
            return pd.DataFrame()

    # Пробуем оба API
    print("\n🔄 Пробую получить данные через API...")

    # Сначала FMP
    df_fmp = get_fmp_calendar()
    if not df_fmp.empty:
        return df_fmp

    # Затем Twelve Data
    df_twelve = get_twelve_data()
    if not df_twelve.empty:
        return df_twelve

    print("❌ Не удалось получить данные через API")
    return pd.DataFrame()


# ГЛАВНАЯ ФУНКЦИЯ
def main():
    """Основная функция с выбором метода"""

    print("=" * 60)
    print("📊 ПАРСЕР ЭКОНОМИЧЕСКОГО КАЛЕНДАРЯ")
    print("=" * 60)

    print("\nВыберите метод получения данных:")
    print("1. Парсинг Forex Factory (может не работать)")
    print("2. Упрощенная проверка")
    print("3. Через Selenium (нужна установка)")
    print("4. Через сторонние API (рекомендуется)")
    print("5. Выход")

    choice = input("\nВаш выбор (1-5): ").strip()

    if choice == '1':
        print("\n" + "=" * 40)
        print("🔄 Метод 1: Парсинг Forex Factory")
        print("=" * 40)
        df = get_forex_factory_calendar()

        if not df.empty:
            print("\n📋 Результаты:")
            print(df[['time', 'currency', 'impact', 'event']].head(20))

            # Сохраняем все события
            df.to_excel('forex_factory_all.xlsx', index=False)
            print(f"\n💾 Все события сохранены в forex_factory_all.xlsx")

            # Сохраняем только важные
            high_impact = df[df['impact'].str.contains('high', case=False, na=False)]
            if not high_impact.empty:
                high_impact.to_excel('forex_factory_high_impact.xlsx', index=False)
                print(f"💾 События высокой важности сохранены в forex_factory_high_impact.xlsx")
        else:
            print("❌ Не удалось получить данные")

    elif choice == '2':
        print("\n" + "=" * 40)
        print("🧪 Метод 2: Упрощенная проверка")
        print("=" * 40)
        success = get_calendar_simple()
        if success:
            print("✅ Проверка пройдена")
        else:
            print("❌ Проверка не удалась")

    elif choice == '3':
        print("\n" + "=" * 40)
        print("🤖 Метод 3: Selenium")
        print("=" * 40)
        df = get_calendar_selenium()
        if not df.empty:
            print("\n📋 Результаты:")
            print(df.head())
        else:
            print("❌ Не удалось получить данные через Selenium")

    elif choice == '4':
        print("\n" + "=" * 40)
        print("🌐 Метод 4: Сторонние API")
        print("=" * 40)
        df = get_economic_calendar_api()
        if not df.empty:
            print("\n📋 Результаты:")

            # Показываем доступные колонки
            print(f"Доступные колонки: {list(df.columns)}")

            # Выбираем ключевые колонки
            if 'event' in df.columns and 'currency' in df.columns:
                display_cols = ['time' if 'time' in df.columns else 'date',
                                'currency', 'event', 'impact' if 'impact' in df.columns else 'importance']
                display_cols = [col for col in display_cols if col in df.columns]

                print(df[display_cols].head(20))

                # Сохраняем
                df.to_excel('api_economic_calendar.xlsx', index=False)
                print(f"\n💾 Данные сохранены в api_economic_calendar.xlsx")
            else:
                print(df.head())
        else:
            print("❌ Не удалось получить данные через API")

    elif choice == '5':
        print("👋 Выход...")
        return

    else:
        print("❌ Неверный выбор")

    print("\n" + "=" * 60)
    print("🎯 Для автоматизации торговли рекомендуются API:")
    print("1. Financial Modeling Prep - бесплатный тариф")
    print("2. Twelve Data - бесплатный тариф (ограничен)")
    print("3. Alpha Vantage - бесплатный тариф")
    print("=" * 60)


# Запуск программы
if __name__ == "__main__":
    main()
