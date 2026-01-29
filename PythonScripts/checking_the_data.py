# check_data.py
import pandas as pd
import os

base_path = r"D:\TradingSystems\OLTP\historicalData"

print("=== ПРОВЕРКА ЗАГРУЖЕННЫХ ДАННЫХ ===")

for folder in ['forex', 'stocks']:
    folder_path = os.path.join(base_path, folder)

    # Проверяем, существует ли папка
    if not os.path.exists(folder_path):
        print(f"\nПапка не существует: {folder_path}")
        continue

    files = os.listdir(folder_path)

    # Проверяем, есть ли файлы
    if not files:
        print(f"\n--- {folder.upper()} ---")
        print("  Файлы не найдены")
        continue

    print(f"\n--- {folder.upper()} ---")
    for file in files:
        if file.endswith('.csv'):
            file_path = os.path.join(folder_path, file)

            try:
                df = pd.read_csv(file_path)

                # Проверяем, есть ли данные
                if df.empty:
                    print(f"\n{file}:")
                    print(f"  Файл пустой!")
                    continue

                print(f"\n{file}:")
                print(f"  Строк: {len(df):,}")

                # Проверяем наличие колонки Date
                if 'Date' in df.columns:
                    print(f"  Дата от: {df['Date'].iloc[0]} до {df['Date'].iloc[-1]}")
                else:
                    print(f"  Колонка 'Date' не найдена. Доступные колонки: {list(df.columns)}")

                print(f"  Колонки: {', '.join(df.columns)}")

                # Проверяем наличие колонки Close
                if 'Close' in df.columns:
                    if len(df) > 0:
                        change_pct = (df['Close'].iloc[-1] / df['Close'].iloc[0] - 1) * 100
                        print(f"  Цена: {df['Close'].iloc[-1]:.4f} (изменение: {change_pct:.1f}%)")
                    else:
                        print(f"  Нет данных для расчета цены")
                else:
                    print(f"  Колонка 'Close' не найдена")

            except Exception as e:
                print(f"\n{file}:")
                print(f"  Ошибка чтения файла: {e}")

# Проверить пропуски
print("\n=== ПРОВЕРКА НА ПРОПУСКИ ===")
forex_path = os.path.join(base_path, 'forex')

if os.path.exists(forex_path):
    for file in os.listdir(forex_path):
        if file.endswith('.csv'):
            file_path = os.path.join(forex_path, file)
            try:
                df = pd.read_csv(file_path)
                missing = df.isnull().sum()
                if missing.any() and missing.sum() > 0:
                    print(f"\n{file}: Есть пропуски!")
                    # Показываем только колонки с пропусками
                    missing_cols = missing[missing > 0]
                    for col, count in missing_cols.items():
                        print(f"  {col}: {count} пропусков ({count / len(df) * 100:.1f}%)")
                else:
                    print(f"{file}: Пропусков нет")
            except Exception as e:
                print(f"{file}: Ошибка проверки пропусков: {e}")
else:
    print("Папка forex не существует")

print("\n=== СВОДНАЯ ИНФОРМАЦИЯ ===")
total_files = 0
total_rows = 0

for folder in ['forex', 'stocks']:
    folder_path = os.path.join(base_path, folder)
    if os.path.exists(folder_path):
        csv_files = [f for f in os.listdir(folder_path) if f.endswith('.csv')]
        if csv_files:
            print(f"\n{folder.upper()}: {len(csv_files)} файлов")
            total_files += len(csv_files)

            for file in csv_files:
                file_path = os.path.join(folder_path, file)
                try:
                    df = pd.read_csv(file_path)
                    total_rows += len(df)
                    print(f"  {file}: {len(df):,} строк")
                except:
                    print(f"  {file}: ошибка чтения")

print(f"\nИтого: {total_files} файлов, {total_rows:,} строк данных")

# Дополнительная проверка структуры данных
print("\n=== ПРОВЕРКА СТРУКТУРЫ ДАННЫХ ===")
sample_file = None

# Найти первый CSV файл для проверки
for folder in ['forex', 'stocks']:
    folder_path = os.path.join(base_path, folder)
    if os.path.exists(folder_path):
        csv_files = [f for f in os.listdir(folder_path) if f.endswith('.csv')]
        if csv_files:
            sample_file = os.path.join(folder_path, csv_files[0])
            break

if sample_file:
    print(f"\nПример структуры файла: {os.path.basename(sample_file)}")
    try:
        df = pd.read_csv(sample_file)
        print(f"Размер: {len(df)} строк × {len(df.columns)} колонок")
        print("\nПервые 5 строк:")
        print(df.head())
        print("\nИнформация о типах данных:")
        print(df.dtypes)
        print("\nСтатистика:")
        print(df.describe())
    except Exception as e:
        print(f"Ошибка при анализе структуры: {e}")
else:
    print("Не найден ни один CSV файл для анализа структуры")