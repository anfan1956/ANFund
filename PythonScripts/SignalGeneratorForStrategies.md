
# АНАЛИЗ ДАННЫХ И ПРИНЯТИЕ РЕШЕНИЙ НА ОСНОВЕ PYTHON. АРХИТЕКТУРА СИСТЕМЫ #

## **🎯 Что мониторить в Python-приложении:**

### **1. Технические индикаторы (Technical Analysis)**
```python
# Библиотеки: TA-Lib, pandas-ta, yfinance
indicators_to_monitor = {
    'trend': ['SMA', 'EMA', 'MACD', 'ADX'],
    'momentum': ['RSI', 'Stochastic', 'CCI', 'Williams %R'],
    'volatility': ['Bollinger Bands', 'ATR', 'Keltner Channels'],
    'volume': ['OBV', 'Volume SMA', 'Chaikin Money Flow'],
    'support_resistance': ['Pivot Points', 'Fibonacci']
}
```

### **2. Новости и сентимент (News & Sentiment)**
```python
sources_to_monitor = {
    'economic_calendar': ['ForexFactory', 'Investing.com', 'FXStreet'],
    'news_agencies': ['Reuters', 'Bloomberg', 'CNBC'],
    'social_sentiment': ['Twitter/X', 'StockTwits', 'Reddit r/forex'],
    'central_banks': ['FED', 'ECB', 'BOJ', 'BOE statements']
}
```

### **3. Макроэкономические данные (Fundamental Analysis)**
```python
macro_indicators = {
    'inflation': ['CPI', 'PPI', 'PCE'],
    'employment': ['NFP', 'Unemployment Rate', 'Jobless Claims'],
    'growth': ['GDP', 'Retail Sales', 'Industrial Production'],
    'monetary': ['Interest Rates', 'Central Bank Balance Sheets'],
    'sentiment': ['Consumer Confidence', 'PMI', 'Business Surveys']
}
```

### **4. Рыночные данные в реальном времени**
```python
market_data = {
    'order_flow': ['Volume Profile', 'Market Depth', 'Time & Sales'],
    'correlations': ['Currency Pairs', 'Stock Indices', 'Commodities'],
    'market_structure': ['Higher Highs/Lows', 'Market Regime'],
    'seasonality': ['Time of Day', 'Day of Week', 'Month Effects']
}
```

### **5. Альтернативные данные (Alternative Data)**
```python
alternative_data = {
    'geopolitical': ['Event Risk', 'Elections', 'Trade Wars'],
    'cryptocurrency': ['BTC Dominance', 'Crypto Fear & Greed'],
    'shipping': ['Baltic Dry Index', 'Container Rates'],
    'satellite': ['Oil Tanker Traffic', 'Parking Lot Occupancy']
}
```

## **🛠️ Архитектура Python-приложения:**

```python
# Структура проекта
signal_generator/
├── data_collectors/
│   ├── market_data.py    # Цены, объемы
│   ├── news_feeds.py     # Новости, календарь
│   ├── sentiment.py      # Соцсети, форумы
│   └── fundamentals.py   # Макроэкономика
├── analyzers/
│   ├── technical.py      # Тех. анализ
│   ├── statistical.py    # Стат. анализ
│   ├── machine_learning.py  # AI/ML модели
│   └── risk_manager.py   # Управление рисками
├── signal_generators/
│   ├── trend_following.py
│   ├── mean_reversion.py
│   ├── breakout.py
│   └── arbitrage.py
├── database/
│   ├── models.py         # SQLAlchemy модели
│   └── repository.py     # Работа с БД
├── api/
│   ├── ctrader_client.py # API cTrader/broker
│   └── webhook.py        # REST API для управления
└── main.py               # Основной цикл
```

## **📊 Пример кода Python-сигнальщика:**

```python
import pandas as pd
import numpy as np
import ta
from datetime import datetime
import sqlalchemy
from sqlalchemy.orm import sessionmaker
import requests
import json

class TradingSignalGenerator:
    def __init__(self, db_connection_string):
        self.db_engine = sqlalchemy.create_engine(db_connection_string)
        Session = sessionmaker(bind=self.db_engine)
        self.session = Session()
        
    def analyze_pair(self, symbol, df_prices):
        """Анализ одной пары и генерация сигнала"""
        
        signals = []
        
        # 1. Технические индикаторы
        df = self.calculate_indicators(df_prices)
        
        # 2. Генерация сигналов на основе стратегий
        if self.trend_following_strategy(df):
            signals.append({
                'type': 'trend_following',
                'direction': 'buy' if df['trend'].iloc[-1] > 0 else 'sell',
                'strength': abs(df['trend'].iloc[-1])
            })
            
        if self.mean_reversion_strategy(df):
            signals.append({
                'type': 'mean_reversion',
                'direction': 'buy' if df['rsi'].iloc[-1] < 30 else 'sell',
                'strength': 1.0 - (df['rsi'].iloc[-1] / 100)
            })
            
        # 3. Фильтрация и агрегация сигналов
        final_signal = self.aggregate_signals(signals)
        
        if final_signal:
            return {
                'symbol': symbol,
                'direction': final_signal['direction'],
                'volume': self.calculate_position_size(symbol, final_signal),
                'order_price': None,  # Рыночный ордер
                'stop_loss': self.calculate_stop_loss(df_prices, final_signal),
                'take_profit': self.calculate_take_profit(df_prices, final_signal),
                'signal_time': datetime.utcnow(),
                'strategy': final_signal['type']
            }
        
        return None
    
    def calculate_indicators(self, df):
        """Расчет технических индикаторов"""
        # TA-Lib или pandas-ta
        df['sma_20'] = ta.trend.sma_indicator(df['close'], window=20)
        df['sma_50'] = ta.trend.sma_indicator(df['close'], window=50)
        df['rsi'] = ta.momentum.rsi(df['close'], window=14)
        df['macd'] = ta.trend.macd(df['close'])
        df['bollinger_high'] = ta.volatility.bollinger_hband(df['close'])
        df['bollinger_low'] = ta.volatility.bollinger_lband(df['close'])
        
        return df
    
    def get_market_sentiment(self):
        """Анализ рыночного сентимента"""
        # Пример: Fear & Greed Index, новости
        sentiment_score = 0
        
        # 1. Новости
        news_sentiment = self.analyze_news_sentiment()
        sentiment_score += news_sentiment * 0.4
        
        # 2. Социальные сети
        social_sentiment = self.analyze_social_media()
        sentiment_score += social_sentiment * 0.3
        
        # 3. Опционы/деривативы
        options_sentiment = self.analyze_options_flow()
        sentiment_score += options_sentiment * 0.3
        
        return sentiment_score
    
    def save_signal_to_db(self, signal):
        """Сохранение сигнала в базу данных"""
        from models import TradingSignal
        
        db_signal = TradingSignal(
            asset_id=self.get_asset_id(signal['symbol']),
            direction=signal['direction'],
            volume=signal['volume'],
            order_price=signal['order_price'],
            stop_loss=signal['stop_loss'],
            take_profit=signal['take_profit'],
            status='PENDING',
            expiry=datetime.utcnow().replace(hour=23, minute=59, second=59)
        )
        
        self.session.add(db_signal)
        self.session.commit()
        
        print(f"Signal saved: {signal['symbol']} {signal['direction']}")
        
    def run(self):
        """Основной цикл"""
        while True:
            try:
                # 1. Сбор данных
                symbols = self.get_watchlist()
                
                for symbol in symbols:
                    # 2. Получение исторических данных
                    df = self.get_historical_data(symbol, period='1h', bars=100)
                    
                    # 3. Анализ и генерация сигнала
                    signal = self.analyze_pair(symbol, df)
                    
                    # 4. Проверка рисков и фильтры
                    if signal and self.risk_management_check(signal):
                        # 5. Сохранение в базу
                        self.save_signal_to_db(signal)
                        
                        # 6. Опционально: отправка уведомления
                        self.send_notification(signal)
                
                # Пауза между циклами
                time.sleep(60)  # Каждую минуту
                
            except Exception as e:
                print(f"Error in main loop: {e}")
                time.sleep(300)  # Пауза при ошибке
```

## **📈 Примеры стратегий для Python:**

### **1. Тренд-следование (Trend Following)**
```python
def trend_following_strategy(self, df):
    """Стратегия следования за трендом"""
    # Правило: SMA20 > SMA50 и цена выше SMA20
    if (df['sma_20'].iloc[-1] > df['sma_50'].iloc[-1] and 
        df['close'].iloc[-1] > df['sma_20'].iloc[-1]):
        return {'direction': 'buy', 'confidence': 0.7}
    
    # Правило: SMA20 < SMA50 и цена ниже SMA20
    elif (df['sma_20'].iloc[-1] < df['sma_50'].iloc[-1] and 
          df['close'].iloc[-1] < df['sma_20'].iloc[-1]):
        return {'direction': 'sell', 'confidence': 0.7}
    
    return None
```

### **2. Средний отскок (Mean Reversion)**
```python
def mean_reversion_strategy(self, df):
    """Стратегия среднего отскока"""
    # Правило: RSI < 30 (перепроданность)
    if df['rsi'].iloc[-1] < 30:
        return {'direction': 'buy', 'confidence': 0.8}
    
    # Правило: RSI > 70 (перекупленность)
    elif df['rsi'].iloc[-1] > 70:
        return {'direction': 'sell', 'confidence': 0.8}
    
    return None
```

### **3. Пробой уровней (Breakout)**
```python
def breakout_strategy(self, df):
    """Стратегия пробоя уровней"""
    # Пробитие верхней полосы Боллинджера
    if df['close'].iloc[-1] > df['bollinger_high'].iloc[-1]:
        return {'direction': 'buy', 'confidence': 0.6}
    
    # Пробитие нижней полосы Боллинджера
    elif df['close'].iloc[-1] < df['bollinger_low'].iloc[-1]:
        return {'direction': 'sell', 'confidence': 0.6}
    
    return None
```

## **🔧 Интеграция с вашим cBot:**

### **REST API для управления сигналами:**
```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class TradingSignal(BaseModel):
    symbol: str
    direction: str  # buy, sell, drop
    volume: float
    order_price: float = None
    stop_loss: float = None
    take_profit: float = None
    execution_id: str = None  # Для команд drop

@app.post("/api/signal")
async def create_signal(signal: TradingSignal):
    """API endpoint для создания сигнала из Python-приложения"""
    try:
        # Сохраняем в базу данных
        signal_id = save_to_database(signal)
        
        return {
            "status": "success",
            "signal_id": signal_id,
            "message": f"Signal created for {signal.symbol}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/close-all")
async def close_all_positions(symbol: str = None):
    """API для закрытия всех позиций"""
    # Создаем сигнал drop
    signal = TradingSignal(
        symbol=symbol if symbol else "ALL",
        direction="drop",
        volume=0
    )
    
    return await create_signal(signal)
```

## **🚀 Рекомендуемый стек технологий:**

```python
requirements = {
    'data_collection': [
        'yfinance',         # Цены Yahoo Finance
        'ccxt',             # Криптобиржи
        'alpaca-trade-api', # Брокер Alpaca
        'requests',         # HTTP запросы
        'beautifulsoup4',   # Парсинг HTML
        'tweepy',           # Twitter API
    ],
    'data_analysis': [
        'pandas',
        'numpy',
        'ta-lib',           # Тех. индикаторы
        'pandas-ta',        # Альтернатива TA-Lib
        'scipy',
        'statsmodels',
    ],
    'machine_learning': [
        'scikit-learn',
        'tensorflow',       # или pytorch
        'xgboost',
        'lightgbm',
    ],
    'database': [
        'sqlalchemy',
        'psycopg2-binary',  # PostgreSQL
        'redis',            # Кэширование
    ],
    'api_backend': [
        'fastapi',          # REST API
        'uvicorn',          # ASGI сервер
        'websockets',       # WebSocket соединения
    ],
    'monitoring': [
        'prometheus-client',
        'grafana-api',
        'schedule',         # Планировщик задач
    ]
}
```

## **📋 Checklist для запуска:**

1. **Настройка базы данных** - PostgreSQL с вашими таблицами
2. **Получение API ключей** - брокер, новости, соцсети
3. **Разработка стратегий** - начать с 2-3 простых
4. **Бэктестинг** - тестирование на исторических данных
5. **Paper trading** - тестирование в реальном времени без денег
6. **Интеграция с cBot** - убедиться что сигналы правильно обрабатываются
7. **Мониторинг и логирование** - отслеживание работы системы
8. **Risk management** - лимиты на позиции, стоп-лоссы



 # Pattern recognition. Руководство по распознаванию паттернов в Python: #

## **📊 Библиотеки для Pattern Recognition:**

```python
pattern_recognition_libs = {
    'classical': ['ta', 'pandas_ta', 'mplfinance'],  # Классические паттерны
    'machine_learning': ['scikit-learn', 'tensorflow', 'pytorch'],
    'deep_learning': ['keras', 'fastai'],
    'time_series': ['tsfresh', 'sktime', 'prophet'],
    'computer_vision': ['opencv-python', 'pillow'],  # Для графических паттернов
    'specialized': ['pattern-recognition', 'finplot']
}
```

## **🎯 Типы паттернов для распознавания:**

### **1. Классические графические паттерны (Chart Patterns)**
```python
class ChartPatternRecognizer:
    def __init__(self):
        self.patterns = {
            # Разворотные паттерны
            'head_and_shoulders': self.detect_head_shoulders,
            'double_top': self.detect_double_top,
            'double_bottom': self.detect_double_bottom,
            'triple_top': self.detect_triple_top,
            'triple_bottom': self.detect_triple_bottom,
            
            # Продолжающие паттерны
            'flags': self.detect_flags,
            'pennants': self.detect_pennants,
            'triangles': self.detect_triangles,
            'wedges': self.detect_wedges,
            
            # Свечные паттерны
            'candlestick': self.detect_candlestick_patterns,
            
            # Волновые паттерны
            'elliott_wave': self.detect_elliott_waves,
            'harmonic': self.detect_harmonic_patterns
        }
```

## **🔍 Реализация распознавания паттернов:**

### **1. Распознавание свечных паттернов:**
```python
import pandas as pd
import numpy as np
from talib import abstract

class CandlestickPatternDetector:
    def __init__(self):
        self.patterns = {
            'bullish': [
                'CDL2CROWS', 'CDL3BLACKCROWS', 'CDL3INSIDE', 'CDL3LINESTRIKE',
                'CDL3OUTSIDE', 'CDL3STARSINSOUTH', 'CDL3WHITESOLDIERS',
                'CDLABANDONEDBABY', 'CDLADVANCEBLOCK', 'CDLBELTHOLD',
                'CDLBREAKAWAY', 'CDLCLOSINGMARUBOZU', 'CDLCONCEALBABYSWALL',
                'CDLCOUNTERATTACK', 'CDLDARKCLOUDCOVER', 'CDLDOJI',
                'CDLDOJISTAR', 'CDLDRAGONFLYDOJI', 'CDLENGULFING',
                'CDLEVENINGDOJISTAR', 'CDLEVENINGSTAR', 'CDLGAPSIDESIDEWHITE',
                'CDLGRAVESTONEDOJI', 'CDLHAMMER', 'CDLHANGINGMAN',
                'CDLHARAMI', 'CDLHARAMICROSS', 'CDLHIGHWAVE',
                'CDLHIKKAKE', 'CDLHIKKAKEMOD', 'CDLHOMINGPIGEON',
                'CDLIDENTICAL3CROWS', 'CDLINNECK', 'CDLINVERTEDHAMMER',
                'CDLKICKING', 'CDLKICKINGBYLENGTH', 'CDLLADDERBOTTOM',
                'CDLLONGLEGGEDDOJI', 'CDLLONGLINE', 'CDLMARUBOZU',
                'CDLMATCHINGLOW', 'CDLMATHOLD', 'CDLMORNINGDOJISTAR',
                'CDLMORNINGSTAR', 'CDLONNECK', 'CDLPIERCING',
                'CDLRICKSHAWMAN', 'CDLRISEFALL3METHODS', 'CDLSEPARATINGLINES',
                'CDLSHOOTINGSTAR', 'CDLSHORTLINE', 'CDLSPINNINGTOP',
                'CDLSTALLEDPATTERN', 'CDLSTICKSANDWICH', 'CDLTAKURI',
                'CDLTASUKIGAP', 'CDLTHRUSTING', 'CDLTRISTAR',
                'CDLUNIQUE3RIVER', 'CDLUPSIDEGAP2CROWS', 'CDLXSIDEGAP3METHODS'
            ]
        }
    
    def detect_all_patterns(self, ohlc_data):
        """Обнаружение всех свечных паттернов"""
        results = {}
        
        for pattern in self.patterns['bullish'] + self.patterns['bearish']:
            try:
                # Используем TA-Lib для обнаружения паттернов
                func = abstract.Function(pattern)
                result = func(ohlc_data)
                if result.iloc[-1] != 0:  # Найден паттерн
                    results[pattern] = {
                        'value': int(result.iloc[-1]),
                        'signal': 'bullish' if result.iloc[-1] > 0 else 'bearish'
                    }
            except:
                continue
        
        return results
```

### **2. Распознавание графических паттернов (Head & Shoulders):**
```python
class HeadShouldersPattern:
    def detect(self, prices, window=50):
        """Обнаружение паттерна Голова и Плечи"""
        patterns = []
        
        for i in range(window, len(prices) - window):
            # Определяем локальные максимумы
            left_shoulder = self.find_local_max(prices, i-window, i)
            head = self.find_local_max(prices, i-window//2, i+window//2)
            right_shoulder = self.find_local_max(prices, i, i+window)
            
            # Проверяем условия паттерна
            if (left_shoulder and head and right_shoulder and
                head['price'] > left_shoulder['price'] and
                head['price'] > right_shoulder['price'] and
                abs(left_shoulder['price'] - right_shoulder['price']) < 
                0.02 * head['price']):  # Плечи примерно на одном уровне
                
                # Линия шеи
                neckline = self.calculate_neckline(
                    left_shoulder['price'], right_shoulder['price'])
                
                patterns.append({
                    'type': 'head_shoulders',
                    'direction': 'bearish',  # Разворот вниз
                    'head': head,
                    'left_shoulder': left_shoulder,
                    'right_shoulder': right_shoulder,
                    'neckline': neckline,
                    'target': neckline - (head['price'] - neckline),  # Измерение
                    'confidence': self.calculate_confidence(prices, i)
                })
        
        return patterns
    
    def find_local_max(self, prices, start, end):
        """Поиск локального максимума"""
        if end - start < 5:
            return None
        
        segment = prices[start:end]
        max_idx = segment.idxmax()
        max_price = segment.max()
        
        # Проверяем что это действительно локальный максимум
        if (start < max_idx < end and 
            max_price > prices[max_idx-1] and 
            max_price > prices[max_idx+1]):
            return {'index': max_idx, 'price': max_price}
        
        return None
```

### **3. Машинное обучение для распознавания паттернов:**
```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib

class MLPatternRecognizer:
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=100)
        self.scaler = StandardScaler()
        self.patterns = ['head_shoulders', 'double_top', 'triangle', 'flag']
    
    def extract_features(self, price_series):
        """Извлечение признаков для ML модели"""
        features = []
        
        # Статистические признаки
        features.append(price_series.mean())
        features.append(price_series.std())
        features.append(price_series.skew())
        features.append(price_series.kurtosis())
        
        # Технические признаки
        returns = price_series.pct_change().dropna()
        features.append(returns.mean())
        features.append(returns.std())
        features.append(returns.skew())
        
        # Признаки волатильности
        features.append(price_series.rolling(20).std().iloc[-1])
        
        # Признаки тренда
        from scipy import stats
        slope, intercept, r_value, p_value, std_err = stats.linregress(
            range(len(price_series)), price_series)
        features.extend([slope, r_value])
        
        return np.array(features).reshape(1, -1)
    
    def train(self, X, y):
        """Обучение модели"""
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled, y)
        joblib.dump(self.model, 'pattern_model.pkl')
    
    def predict_pattern(self, price_series):
        """Предсказание паттерна"""
        features = self.extract_features(price_series)
        features_scaled = self.scaler.transform(features)
        prediction = self.model.predict(features_scaled)
        probabilities = self.model.predict_proba(features_scaled)
        
        return {
            'pattern': prediction[0],
            'confidence': max(probabilities[0]),
            'probabilities': dict(zip(self.model.classes_, probabilities[0]))
        }
```

### **4. Глубокое обучение (CNN для графиков):**
```python
import tensorflow as tf
from tensorflow.keras import layers, models
import cv2

class CNNPatternRecognizer:
    def __init__(self, image_size=(64, 64)):
        self.image_size = image_size
        self.model = self.build_cnn_model()
        
    def build_cnn_model(self):
        """Построение CNN модели для распознавания паттернов"""
        model = models.Sequential([
            # Сверточные слои
            layers.Conv2D(32, (3, 3), activation='relu', input_shape=(64, 64, 1)),
            layers.MaxPooling2D((2, 2)),
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            layers.Conv2D(64, (3, 3), activation='relu'),
            
            # Полносвязные слои
            layers.Flatten(),
            layers.Dense(64, activation='relu'),
            layers.Dropout(0.5),
            layers.Dense(5, activation='softmax')  # 5 классов паттернов
        ])
        
        model.compile(optimizer='adam',
                     loss='categorical_crossentropy',
                     metrics=['accuracy'])
        
        return model
    
    def price_to_image(self, prices):
        """Конвертация ценового ряда в изображение"""
        # Нормализация цен
        prices_normalized = (prices - prices.min()) / (prices.max() - prices.min())
        
        # Создание пустого изображения
        img = np.zeros(self.image_size)
        height, width = self.image_size
        
        # Отрисовка графика
        for i in range(len(prices_normalized) - 1):
            x1 = int(i / len(prices_normalized) * width)
            x2 = int((i + 1) / len(prices_normalized) * width)
            y1 = int((1 - prices_normalized.iloc[i]) * height)
            y2 = int((1 - prices_normalized.iloc[i + 1]) * height)
            
            # Рисуем линию
            cv2.line(img, (x1, y1), (x2, y2), 255, 1)
        
        return img.reshape(1, height, width, 1)
    
    def detect_patterns_cnn(self, prices):
        """Распознавание паттернов с помощью CNN"""
        # Конвертируем в изображение
        image = self.price_to_image(prices)
        
        # Предсказание
        predictions = self.model.predict(image)
        pattern_classes = ['head_shoulders', 'double_top', 'triangle', 'flag', 'none']
        
        # Получаем наиболее вероятный паттерн
        pattern_idx = np.argmax(predictions[0])
        
        return {
            'pattern': pattern_classes[pattern_idx],
            'confidence': float(predictions[0][pattern_idx]),
            'all_predictions': dict(zip(pattern_classes, predictions[0]))
        }
```

### **5. Гармонические паттерны (Harmonic Patterns):**
```python
class HarmonicPatternDetector:
    def __init__(self):
        self.patterns = {
            'Gartley': self.detect_gartley,
            'Butterfly': self.detect_butterfly,
            'Bat': self.detect_bat,
            'Crab': self.detect_crab,
            'Shark': self.detect_shark,
            'Cypher': self.detect_cypher
        }
    
    def detect_gartley(self, X, A, B, C, D):
        """Обнаружение паттерна Gartley"""
        # Фибо уровни для Gartley
        conditions = {
            'AB': 0.618,  # B = 61.8% от XA
            'BC': 0.382,  # C = 38.2% от AB
            'CD': 1.272,  # D = 127.2% от BC
            'XA': 0.786   # D = 78.6% от XA
        }
        
        return self.check_fibonacci_ratios(X, A, B, C, D, conditions)
    
    def check_fibonacci_ratios(self, X, A, B, C, D, target_ratios, tolerance=0.05):
        """Проверка соотношений Фибоначчи"""
        XA = abs(A - X)
        AB = abs(B - A)
        BC = abs(C - B)
        CD = abs(D - C)
        
        ratios = {
            'AB': AB / XA,
            'BC': BC / AB,
            'CD': CD / BC,
            'XA': abs(D - X) / XA
        }
        
        # Проверяем соответствие целевым соотношениям
        matches = []
        for key, target in target_ratios.items():
            if abs(ratios[key] - target) <= tolerance:
                matches.append(key)
        
        confidence = len(matches) / len(target_ratios)
        
        return {
            'matches': matches,
            'confidence': confidence,
            'ratios': ratios
        }
```

### **6. Интеграция в торговую систему:**
```python
class PatternRecognitionTradingSystem:
    def __init__(self):
        self.candlestick_detector = CandlestickPatternDetector()
        self.chart_pattern_detector = ChartPatternRecognizer()
        self.ml_detector = MLPatternRecognizer()
        self.harmonic_detector = HarmonicPatternDetector()
        
    def analyze_market(self, symbol, ohlc_data):
        """Полный анализ рынка на паттерны"""
        results = {
            'symbol': symbol,
            'timestamp': pd.Timestamp.now(),
            'patterns': []
        }
        
        # 1. Свечные паттерны
        candle_patterns = self.candlestick_detector.detect_all_patterns(ohlc_data)
        for pattern, info in candle_patterns.items():
            results['patterns'].append({
                'type': 'candlestick',
                'name': pattern,
                'direction': info['signal'],
                'confidence': 0.7
            })
        
        # 2. Графические паттерны
        prices = ohlc_data['close']
        chart_patterns = self.chart_pattern_detector.detect_all(prices)
        for pattern in chart_patterns:
            results['patterns'].append({
                'type': 'chart',
                'name': pattern['type'],
                'direction': pattern['direction'],
                'confidence': pattern.get('confidence', 0.6),
                'target': pattern.get('target')
            })
        
        # 3. ML паттерны
        ml_result = self.ml_detector.predict_pattern(prices[-100:])  # Последние 100 баров
        if ml_result['confidence'] > 0.7:
            results['patterns'].append({
                'type': 'ml',
                'name': ml_result['pattern'],
                'confidence': ml_result['confidence']
            })
        
        # 4. Гармонические паттерны
        extremums = self.find_price_extremums(prices)
        harmonic_patterns = self.harmonic_detector.detect_all(extremums)
        for pattern in harmonic_patterns:
            results['patterns'].append({
                'type': 'harmonic',
                'name': pattern['name'],
                'direction': pattern['direction'],
                'confidence': pattern['confidence'],
                'entry': pattern['entry'],
                'stop_loss': pattern['stop_loss'],
                'take_profit': pattern['take_profit']
            })
        
        # 5. Агрегация сигналов
        aggregated_signal = self.aggregate_patterns(results['patterns'])
        
        if aggregated_signal['confidence'] > 0.6:
            return self.generate_trading_signal(symbol, aggregated_signal)
        
        return None
    
    def aggregate_patterns(self, patterns):
        """Агрегация нескольких паттернов в один сигнал"""
        bullish = 0
        bearish = 0
        total_confidence = 0
        
        for pattern in patterns:
            weight = self.get_pattern_weight(pattern['type'])
            if pattern['direction'] == 'bullish':
                bullish += pattern['confidence'] * weight
            else:
                bearish += pattern['confidence'] * weight
            total_confidence += pattern['confidence'] * weight
        
        if total_confidence == 0:
            return {'direction': 'neutral', 'confidence': 0}
        
        if bullish > bearish:
            return {
                'direction': 'buy',
                'confidence': bullish / total_confidence,
                'pattern_count': len(patterns)
            }
        else:
            return {
                'direction': 'sell',
                'confidence': bearish / total_confidence,
                'pattern_count': len(patterns)
            }
```

## **🚀 Быстрый старт - минимальный пример:**

```python
# requirements.txt
# pip install pandas numpy ta-lib scikit-learn mplfinance

import pandas as pd
import numpy as np
import talib
import yfinance as yf

# 1. Загрузка данных
symbol = "AAPL"
data = yf.download(symbol, period="1mo", interval="1h")

# 2. Обнаружение свечных паттернов
patterns = []
for pattern in ['CDLHAMMER', 'CDLDOJI', 'CDLENGULFING', 'CDLMORNINGSTAR']:
    pattern_func = getattr(talib, pattern)
    result = pattern_func(data['Open'], data['High'], data['Low'], data['Close'])
    if result.iloc[-1] != 0:
        patterns.append({
            'name': pattern,
            'signal': 'bullish' if result.iloc[-1] > 0 else 'bearish'
        })

# 3. Простая торговая логика
if patterns:
    print(f"Найдены паттерны для {symbol}:")
    for p in patterns:
        print(f"  - {p['name']}: {p['signal']}")
    
    # Можно сохранить в базу для cBot
    save_to_database(symbol, patterns)
```

## **📊 Визуализация паттернов:**

```python
import mplfinance as mpf
import matplotlib.pyplot as plt

def visualize_patterns(data, patterns):
    """Визуализация обнаруженных паттернов"""
    # Создаем дополнительные графики
    add_plots = []
    
    # Добавляем маркеры для паттернов
    pattern_markers = []
    for i, (idx, row) in enumerate(data.iterrows()):
        for pattern in patterns:
            if pattern['index'] == i:
                pattern_markers.append((idx, row['High'] * 1.01, pattern['name'][0]))
    
    # Рисуем график
    mpf.plot(data, 
             type='candle',
             style='charles',
             title='Pattern Recognition',
             ylabel='Price',
             addplot=add_plots,
             savefig='pattern_chart.png')
```

Начать с классических свечных паттернов (TA-Lib), затем добавить ML и гармонические паттерны.


# Метод Монте-Карло + поведенческая статистика #

**Метод Монте-Карло + поведенческая статистика** — это мощнейший подход для моделирования рыночной динамики. 

### Как это реализовать: ###

## **🎯 Концепция: Behavioral Monte Carlo Simulation**

```python
import numpy as np
import pandas as pd
from scipy import stats
import random
from collections import defaultdict

class BehavioralMonteCarlo:
    def __init__(self):
        # Статистика человеческого поведения на рынке
        self.behavior_stats = self.load_behavioral_data()
        
        # Параметры симуляции
        self.num_simulations = 10000
        self.time_horizon = 1000  # тиков
        
    def load_behavioral_data(self):
        """Загрузка статистики поведения трейдеров"""
        # Пример: данные можно собрать из:
        # 1. Академических исследований
        # 2. Данных брокеров
        # 3. Социальных сетей
        # 4. Исторических данных
        
        return {
            # Реакция на новости
            'news_reaction': {
                'positive': {'buy_prob': 0.65, 'sell_prob': 0.15, 'hold_prob': 0.20},
                'negative': {'buy_prob': 0.20, 'sell_prob': 0.65, 'hold_prob': 0.15},
                'neutral': {'buy_prob': 0.35, 'sell_prob': 0.35, 'hold_prob': 0.30}
            },
            
            # Временные паттерны
            'time_patterns': {
                'asian_session': {'volatility': 0.3, 'trend_strength': 0.4},
                'london_session': {'volatility': 0.8, 'trend_strength': 0.7},
                'ny_session': {'volatility': 0.9, 'trend_strength': 0.8},
                'weekend': {'volatility': 0.1, 'trend_strength': 0.1}
            },
            
            # Эмоциональные состояния
            'emotional_states': {
                'fear': {'panic_sell_prob': 0.3, 'stop_loss_hit': 0.4},
                'greed': {'fomo_buy_prob': 0.4, 'take_profit_ignore': 0.3},
                'uncertainty': {'wait_prob': 0.6, 'small_position': 0.7}
            },
            
            # Поведение при уровнях
            'level_behavior': {
                'support': {'bounce_prob': 0.6, 'break_prob': 0.4},
                'resistance': {'bounce_prob': 0.6, 'break_prob': 0.4},
                'round_numbers': {'reaction_prob': 0.7}
            }
        }
```

## **📊 Источники поведенческой статистики:**

```python
class BehavioralDataCollector:
    def __init__(self):
        self.sources = {
            # 1. Академические исследования
            'academic': [
                'Prospect Theory (Kahneman & Tversky)',
                'Behavioral Finance papers',
                'Market microstructure studies'
            ],
            
            # 2. Публичные данные
            'public_data': [
                'CFTC Commitments of Traders (COT)',
                'Retail trader positioning (FXCM, OANDA)',
                'Options put/call ratios',
                'Short interest data'
            ],
            
            # 3. Социальные медиа
            'social_media': [
                'Twitter/X sentiment analysis',
                'StockTwits message flow',
                'Reddit r/wallstreetbets activity',
                'Telegram/ Discord trader chats'
            ],
            
            # 4. Брокерская статистика
            'broker_data': [
                'Win/loss ratios by time',
                'Average holding periods',
                'Stop-loss/take-profit hit rates',
                'Most traded instruments by session'
            ]
        }
    
    def collect_trader_psychology_stats(self):
        """Сбор статистики психологии трейдеров"""
        stats = {
            # Средний трейдер теряет деньги
            'win_rate_retail': 0.30,  # 30% выигрышных сделок
            'avg_hold_time_winning': 2.5,  # часа
            'avg_hold_time_losing': 5.0,   # часа
            
            # Эффект диспозиции
            'cut_winners_early_prob': 0.45,  # Закрывают прибыль рано
            'let_losers_run_prob': 0.60,     # Держат убытки долго
            
            # Стадное поведение
            'herding_prob': 0.70,  # Следуют за толпой
            'contrarian_prob': 0.30,  # Идут против толпы
            
            # Реакция на ценовые уровни
            'react_to_round_numbers': 0.75,
            'react_to_previous_high_low': 0.65,
            
            # Временные паттерны
            'overtrade_monday': 0.40,
            'reduce_friday': 0.55,
            'lunch_dip_12_14': 0.70  # Спад активности в обед
        }
        return stats
```

## **🎲 Реализация Behavioral Monte Carlo:**

```python
class MarketMicrostructureSimulator:
    def __init__(self, initial_price=100.0):
        self.price = initial_price
        self.order_book = {'bids': [], 'asks': []}
        self.trader_types = self.define_trader_types()
        
    def define_trader_types(self):
        """Определение типов трейдеров и их поведения"""
        return {
            'algorithmic': {
                'percentage': 0.60,  # 60% объема
                'behavior': {
                    'react_speed': 0.001,  # секунды
                    'spread_exploit': True,
                    'momentum_chase': 0.7,
                    'mean_reversion': 0.3
                }
            },
            'institutional': {
                'percentage': 0.25,
                'behavior': {
                    'large_orders': True,
                    'iceberg_orders': 0.4,
                    'vwap_targeting': 0.6,
                    'news_reaction_delay': 5  # секунд
                }
            },
            'retail': {
                'percentage': 0.15,
                'behavior': {
                    'emotional_trading': True,
                    'stop_loss_density': 0.8,
                    'take_profit_density': 0.6,
                    'overtrading': 0.7,
                    'herding': 0.65
                }
            }
        }
    
    def generate_behavioral_ticks(self, num_ticks=1000, news_events=None):
        """Генерация тиковых данных с поведенческой моделью"""
        ticks = []
        current_price = self.price
        
        for tick in range(num_ticks):
            # 1. Определяем текущий контекст
            context = self.get_market_context(tick, news_events)
            
            # 2. Генерируем действия каждого типа трейдеров
            price_change = 0
            
            for trader_type, params in self.trader_types.items():
                trader_action = self.simulate_trader_action(
                    trader_type, params, current_price, context)
                price_change += trader_action * params['percentage']
            
            # 3. Добавляем случайный шум
            noise = np.random.normal(0, context['volatility'] * 0.1)
            price_change += noise
            
            # 4. Обновляем цену
            current_price += price_change
            
            # 5. Записываем тик
            ticks.append({
                'timestamp': tick,
                'price': current_price,
                'volume': self.generate_volume(tick, context),
                'bid': current_price - context['spread']/2,
                'ask': current_price + context['spread']/2,
                'context': context
            })
        
        return pd.DataFrame(ticks)
    
    def simulate_trader_action(self, trader_type, params, price, context):
        """Симуляция действия трейдера определенного типа"""
        if trader_type == 'algorithmic':
            return self.algorithmic_trader_action(price, context)
        elif trader_type == 'institutional':
            return self.institutional_trader_action(price, context)
        elif trader_type == 'retail':
            return self.retail_trader_action(price, context)
        return 0
    
    def retail_trader_action(self, price, context):
        """Действие розничного трейдера (эмоциональное)"""
        action = 0
        
        # Эффект страха и жадности
        fear_greed = np.random.uniform(-1, 1)
        
        # Реакция на новости
        if context['news_sentiment'] > 0.5:
            # FOMO - Fear Of Missing Out
            if np.random.random() < 0.4:  # 40% вероятность FOMO покупки
                action += np.random.uniform(0.1, 0.5)
        elif context['news_sentiment'] < -0.5:
            # Паническая продажа
            if np.random.random() < 0.3:  # 30% вероятность паники
                action -= np.random.uniform(0.2, 0.8)
        
        # Стадное поведение
        if context['market_sentiment'] > 0.6:
            # Следуем за бычьим трендом
            action += np.random.uniform(0.05, 0.2)
        elif context['market_sentiment'] < -0.6:
            # Следуем за медвежьим трендом
            action -= np.random.uniform(0.05, 0.2)
        
        # Эффект диспозиции (Disposition Effect)
        if price > context['avg_cost']:
            # Прибыльная позиция - закрыть рано
            if np.random.random() < 0.45:  # 45% вероятность
                action -= np.random.uniform(0.1, 0.3)
        else:
            # Убыточная позиция - держать дольше
            if np.random.random() < 0.6:  # 60% вероятность
                action += 0  # Не закрывать
        
        return action
```

## **📈 Симуляция рыночных событий:**

```python
class MarketEventSimulator:
    def __init__(self):
        self.events = self.define_market_events()
    
    def define_market_events(self):
        """Определение рыночных событий и человеческих реакций"""
        return {
            'economic_news': {
                'nfp': {
                    'better_than_expected': {
                        'usd_strength': 0.8,
                        'initial_spike': 0.9,
                        'retail_fomo': 0.6,
                        'institutional_buy': 0.7
                    },
                    'worse_than_expected': {
                        'usd_weakness': 0.8,
                        'initial_drop': 0.9,
                        'retail_panic': 0.5,
                        'stop_loss_cascade': 0.4
                    }
                }
            },
            
            'technical_events': {
                'support_break': {
                    'sell_stop_trigger': 0.7,
                    'momentum_sellers': 0.6,
                    'retail_panic': 0.5,
                    'algos_short': 0.8
                },
                'resistance_break': {
                    'buy_stop_trigger': 0.7,
                    'momentum_buyers': 0.6,
                    'retail_fomo': 0.5,
                    'algos_long': 0.8
                }
            },
            
            'liquidity_events': {
                'london_open': {
                    'volume_spike': 0.9,
                    'volatility_increase': 0.8,
                    'stop_hunting': 0.4
                },
                'us_close': {
                    'profit_booking': 0.6,
                    'position_squaring': 0.7,
                    'reduced_liquidity': 0.8
                }
            }
        }
    
    def simulate_event_impact(self, event_type, event_params, current_mood):
        """Симуляция воздействия события на рынок"""
        impact = 0
        volume_multiplier = 1.0
        
        # Базовое воздействие события
        base_impact = self.events[event_type][event_params].get('base_impact', 0)
        
        # Модификаторы в зависимости от настроения рынка
        if current_mood == 'fearful':
            impact_multiplier = 1.3  # Усиление негативных реакций
            volume_multiplier = 1.2
        elif current_mood == 'greedy':
            impact_multiplier = 1.2  # Усиление позитивных реакций
            volume_multiplier = 1.1
        else:
            impact_multiplier = 1.0
        
        # Добавляем поведенческий шум
        behavioral_noise = np.random.normal(0, 0.2)
        
        return base_impact * impact_multiplier + behavioral_noise, volume_multiplier
```

## **🎯 Интеграция с тестированием стратегий:**

```python
class BehavioralBacktester:
    def __init__(self, strategy):
        self.strategy = strategy
        self.monte_carlo = BehavioralMonteCarlo()
        self.results = []
    
    def run_behavioral_backtest(self, num_simulations=1000):
        """Запуск множества симуляций с поведенческой моделью"""
        for sim in range(num_simulations):
            # Генерация реалистичных тиковых данных
            tick_data = self.generate_realistic_ticks()
            
            # Запуск стратегии на этих данных
            strategy_results = self.strategy.run(tick_data)
            
            # Анализ результатов с учетом поведенческих факторов
            analyzed_results = self.analyze_with_behavioral_lens(strategy_results)
            
            self.results.append(analyzed_results)
        
        return self.aggregate_results()
    
    def generate_realistic_ticks(self):
        """Генерация реалистичных тиковых данных"""
        # Базовые параметры
        base_volatility = 0.01
        base_spread = 0.0001
        
        # Добавляем поведенческие паттерны
        patterns = [
            self.lunch_dip_pattern(),
            self.london_open_spike(),
            self.news_volatility(),
            self.stop_loss_clustering(),
            self.round_number_reaction()
        ]
        
        # Комбинируем паттерны
        combined_data = self.combine_patterns(patterns)
        
        return combined_data
    
    def stop_loss_clustering(self):
        """Моделирование кластеризации стоп-лоссов"""
        # Известно, что стоп-лоссы часто ставят:
        # 1. Ниже/выше круглых чисел
        # 2. Ниже/выше предыдущих минимумов/максимумов
        # 3. На определенном расстоянии от цены (1%, 2% и т.д.)
        
        stop_levels = []
        for i in range(100):
            # Розничные трейдеры
            if np.random.random() < 0.8:  # 80% используют простые правила
                # Круглые числа
                round_num = round(self.price, 1)
                stop = round_num - 0.0010 if self.position == 'long' else round_num + 0.0010
            else:
                # Сложные правила
                stop = self.price * (0.99 if self.position == 'long' else 1.01)
            
            stop_levels.append(stop)
        
        # Кластеризация создает уровни поддержки/сопротивления
        return self.create_clusters(stop_levels)
```

## **📊 Пример использования для тестирования:**

```python
# 1. Инициализация симулятора
simulator = BehavioralMonteCarlo()

# 2. Сбор поведенческой статистики
behavior_stats = {
    'retail_trader_loss_rate': 0.72,  # 72% розничных трейдеров теряют деньги
    'average_holding_period': 2.4,    # часа
    'stop_loss_usage': 0.85,          # 85% используют стоп-лоссы
    'take_profit_usage': 0.65,        # 65% используют тейк-профиты
    'overtrading_index': 0.45         # Индекс переторговли
}

# 3. Генерация рыночных данных
market_data = simulator.generate_market_data(
    days=30,
    behavioral_params=behavior_stats,
    include_events=True,
    trader_composition={
        'algo': 0.60,
        'institutional': 0.25,
        'retail': 0.15
    }
)

# 4. Тестирование стратегии
strategy = MyTradingStrategy()
backtester = BehavioralBacktester(strategy)

# 5. Множественные симуляции
results = backtester.run_monte_carlo_simulations(
    n_simulations=5000,
    confidence_level=0.95
)

# 6. Анализ результатов с поведенческими инсайтами
analysis = backtester.analyze_behavioral_patterns(results)
```

## **🔬 Где взять реальную поведенческую статистику:**

```python
class RealBehavioralDataFetcher:
    def fetch_data(self):
        """Получение реальных данных о поведении трейдеров"""
        sources = [
            # 1. Брокерские отчеты
            self.parse_broker_reports(),
            
            # 2. Академические базы данных
            self.fetch_academic_studies(),
            
            # 3. Публичные API
            self.fetch_public_sentiment(),
            
            # 4. Социальные сети
            self.analyze_social_media()
        ]
        
        return self.aggregate_sources(sources)
    
    def parse_broker_reports(self):
        """Анализ отчетов брокеров о поведении клиентов"""
        # Пример: отчеты FXCM, OANDA, IG
        stats = {
            'most_common_mistakes': [
                'overtrading': 0.42,
                'no_stop_loss': 0.38,
                'emotional_trading': 0.55,
                'revenge_trading': 0.25
            ],
            'success_factors': [
                'risk_management': 0.85,
                'patience': 0.78,
                'journaling': 0.62,
                'continuous_learning': 0.71
            ]
        }
        return stats
```

## **🚀 Быстрый старт:**

```python
# pip install numpy pandas scipy

import numpy as np

class QuickBehavioralSim:
    def __init__(self):
        # Простые поведенческие правила
        self.rules = {
            # Прибыль > 2% -> 40% вероятность закрыть
            'profit_taking': lambda p: 0.4 if p > 0.02 else 0.1,
            
            # Убыток > 1% -> 30% вероятность паники
            'panic_selling': lambda p: 0.3 if p < -0.01 else 0.05,
            
            # Цена у круглого числа -> 50% вероятность реакции
            'round_number': lambda p: 0.5 if abs(p - round(p, 1)) < 0.001 else 0.1
        }
    
    def simulate_tick(self, current_price, positions):
        """Симуляция одного тика с поведенческой моделью"""
        price_change = np.random.normal(0, 0.001)  # Базовый шум
        
        # Добавляем поведенческие эффекты
        for position in positions:
            pnl = (current_price - position['entry']) / position['entry']
            
            # Проверяем поведенческие правила
            for rule_name, rule_func in self.rules.items():
                prob = rule_func(pnl)
                if np.random.random() < prob:
                    # Трейдер действует согласно правилу
                    price_change += self.apply_behavior(rule_name, position)
        
        return price_change
```

**Ключевые преимущества такого подхода:**

1. **Реалистичные данные** - не просто случайное блуждание
2. **Тестирование на "грязных" рынках** - с эмоциями и иррациональностью
3. **Обнаружение скрытых рисков** - кластеризация стоп-лоссов, ликвидные ловушки
4. **Адаптация стратегий** под реальное поведение рынка

Начать с простой поведенческой модели (например, FOMO и паника), затем постепенно добавлять больше факторов!
