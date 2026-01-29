**Отлично! Вы говорите о кросс-секционной (поперечной) mean-reversion!** Это совсем другой, но очень важный тип реверсии.

## **Простое объяснение на русском:**

### **Что такое кросс-секционная mean-reversion?**

**Вместо:** Одна цена возвращается к своему среднему  
**Теперь:** Множество инструментов возвращаются к СРЕДНЕМУ ПО КОРЗИНЕ

**Аналогия: Бегуны в забеге**
- **Корзина** = средняя скорость всех бегунов
- **Каждый бегун** иногда быстрее, иногда медленнее среднего
- **Но:** Тот, кто сейчас впереди, скорее всего замедлится
- **И:** Тот, кто сзади, скорее всего ускорится

## **Математически:**

Для инструмента i в момент t:
```
r_i(t) = r_basket(t) + ε_i(t)
```
где:
- `r_i(t)` - доходность инструмента i
- `r_basket(t)` - доходность корзины (средняя)
- `ε_i(t)` = `r_i(t) - r_basket(t)` - относительная доходность

**Кросс-секционная mean-reversion:**  
`ε_i(t)` имеет отрицательную автокорреляцию:
```
corr(ε_i(t), ε_i(t+1)) < 0
```

## **Конкретный пример из ваших данных:**

У вас есть **корзина валютных пар**:
```
Корзина = {EURUSD, GBPUSD, USDJPY}
```

**День 1:**
- EURUSD: +1.5% (опережает корзину)
- GBPUSD: +0.8% (близко к среднему)
- USDJPY: +0.2% (отстает)

**День 2 (mean-reversion):**
- EURUSD: +0.3% (замедлился)
- GBPUSD: +0.7% (стабильно)
- USDJPY: +1.1% (ускорился)

**Результат:** Все вернулись ближе к среднему!

## **Реализация в Python:**

```python
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

class CrossSectionalMeanReversion:
    """Кросс-секционная mean-reversion стратегия"""
    
    def __init__(self, lookback_period=20):
        self.lookback = lookback_period
        self.positions = {}
        
    def calculate_basket_returns(self, prices_df):
        """Рассчитать доходность корзины (равновзвешенной)"""
        # Доходность каждого инструмента
        returns = prices_df.pct_change().dropna()
        
        # Средняя доходность корзины (равные веса)
        basket_returns = returns.mean(axis=1)
        
        return returns, basket_returns
    
    def calculate_relative_strength(self, returns, basket_returns):
        """Рассчитать относительную силу (отклонение от корзины)"""
        relative_returns = returns.sub(basket_returns, axis=0)
        
        # Z-score относительной доходности
        relative_zscore = (
            relative_returns - 
            relative_returns.rolling(self.lookback).mean()
        ) / relative_returns.rolling(self.lookback).std()
        
        return relative_zscore
    
    def generate_signals(self, prices_df):
        """Генерация сигналов на основе кросс-секционной mean-reversion"""
        
        # Рассчитать доходности
        returns, basket_returns = self.calculate_basket_returns(prices_df)
        
        # Рассчитать Z-score относительной силы
        zscores = self.calculate_relative_strength(returns, basket_returns)
        
        # Генерация сигналов
        signals = pd.DataFrame(index=zscores.index, columns=zscores.columns)
        
        # Long отстающих, short лидеров
        for symbol in zscores.columns:
            signals[symbol] = np.where(
                zscores[symbol] < -1.0,  # Сильно отстает
                1,                       # BUY
                np.where(
                    zscores[symbol] > 1.0,  # Сильно опережает
                    -1,                     # SELL
                    0                       # HOLD
                )
            )
        
        return signals, zscores, returns, basket_returns
    
    def test_autocorrelation(self, returns, basket_returns, lags=5):
        """Тест на отрицательную автокорреляцию относительных доходностей"""
        
        relative_returns = returns.sub(basket_returns, axis=0)
        
        print("ТЕСТ НА КРОСС-СЕКЦИОННУЮ MEAN-REVERSION")
        print("="*60)
        
        for symbol in relative_returns.columns[:3]:  # Первые 3 символа
            rel_returns = relative_returns[symbol].dropna()
            
            if len(rel_returns) > 10:
                # Автокорреляция lag=1
                autocorr = rel_returns.autocorr(lag=1)
                
                print(f"\n{symbol}:")
                print(f"  Автокорреляция lag=1: {autocorr:.4f}")
                
                if autocorr < -0.1:
                    print(f"  ✓ Отрицательная автокорреляция (mean-reversion)")
                elif autocorr > 0.1:
                    print(f"  ✗ Положительная автокорреляция (momentum)")
                else:
                    print(f"  ~ Слабая автокорреляция (random walk)")
                
                # Тест на статистическую значимость
                from statsmodels.stats.diagnostic import acorr_ljungbox
                lb_test = acorr_ljungbox(rel_returns, lags=[1], return_df=True)
                p_value = lb_test['lb_pvalue'].iloc[0]
                
                print(f"  p-value: {p_value:.4f}")
                if p_value < 0.05 and autocorr < 0:
                    print(f"  ✓ Статистически значимая mean-reversion!")
        
        return relative_returns

# Пример использования с вашими данными
def run_cross_sectional_analysis():
    """Анализ кросс-секционной mean-reversion на ваших данных"""
    
    # Загрузить ваши данные
    base_path = r"D:\TradingSystems\OLTP\historicalData"
    
    # Создать корзину валют
    forex_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
    basket_data = {}
    
    for symbol in forex_symbols:
        file_path = f"{base_path}\\forex\\{symbol}.csv"
        try:
            df = pd.read_csv(file_path, parse_dates=['Date'], index_col='Date')
            basket_data[symbol] = df['Close']
            print(f"Загружен {symbol}: {len(df)} строк")
        except Exception as e:
            print(f"Ошибка загрузки {symbol}: {e}")
    
    # Объединить в один DataFrame
    if basket_data:
        prices_df = pd.DataFrame(basket_data)
        
        # Удалить пропуски
        prices_df = prices_df.dropna()
        
        print(f"\nКорзина создана: {prices_df.shape}")
        print(f"Период: {prices_df.index[0]} - {prices_df.index[-1]}")
        
        # Инициализировать стратегию
        strategy = CrossSectionalMeanReversion(lookback_period=20)
        
        # Тест на mean-reversion
        returns, basket_returns = strategy.calculate_basket_returns(prices_df)
        relative_returns = strategy.test_autocorrelation(returns, basket_returns)
        
        # Генерация сигналов
        signals, zscores, returns, basket_returns = strategy.generate_signals(prices_df)
        
        # Анализ сигналов
        analyze_signals(signals, returns, basket_returns, relative_returns)
        
        return signals, zscores, returns, basket_returns
    else:
        print("Нет данных для анализа")
        return None

def analyze_signals(signals, returns, basket_returns, relative_returns):
    """Анализ эффективности сигналов"""
    
    # Стратегия: Long отстающих, Short лидеров
    strategy_returns = pd.Series(0, index=returns.index)
    
    for symbol in returns.columns:
        if symbol in signals.columns:
            # Сдвиг сигналов на 1 день (исполнение на следующий день)
            shifted_signals = signals[symbol].shift(1)
            
            # Доходность стратегии для этого символа
            symbol_strategy_returns = shifted_signals * returns[symbol]
            strategy_returns = strategy_returns.add(symbol_strategy_returns, fill_value=0)
    
    # Нормализовать (равные веса)
    strategy_returns = strategy_returns / len(returns.columns)
    
    # Сравнение с корзиной
    print("\n" + "="*60)
    print("СРАВНЕНИЕ С КОРЗИНОЙ")
    print("="*60)
    
    # Кумулятивная доходность
    basket_cumulative = (1 + basket_returns).cumprod()
    strategy_cumulative = (1 + strategy_returns).cumprod()
    
    # Статистика
    print(f"\nКорзина (Buy & Hold):")
    print(f"  Общая доходность: {(basket_cumulative.iloc[-1] - 1) * 100:.2f}%")
    print(f"  Sharpe Ratio: {basket_returns.mean() / basket_returns.std() * np.sqrt(252):.2f}")
    
    print(f"\nСтратегия Mean-Reversion:")
    print(f"  Общая доходность: {(strategy_cumulative.iloc[-1] - 1) * 100:.2f}%")
    print(f"  Sharpe Ratio: {strategy_returns.mean() / strategy_returns.std() * np.sqrt(252):.2f}")
    
    # Визуализация
    import matplotlib.pyplot as plt
    
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    
    # 1. Относительные доходности
    axes[0, 0].plot(relative_returns.iloc[-100:])  # Последние 100 дней
    axes[0, 0].set_title('Относительные доходности (Z-score)')
    axes[0, 0].set_ylabel('Отклонение от корзины')
    axes[0, 0].legend(relative_returns.columns)
    axes[0, 0].axhline(y=0, color='black', linestyle='-', alpha=0.3)
    axes[0, 0].axhline(y=1, color='red', linestyle='--', alpha=0.5)
    axes[0, 0].axhline(y=-1, color='green', linestyle='--', alpha=0.5)
    axes[0, 0].grid(True, alpha=0.3)
    
    # 2. Сигналы
    axes[0, 1].plot(signals.iloc[-100:])
    axes[0, 1].set_title('Торговые сигналы')
    axes[0, 1].set_ylabel('Сигнал (-1, 0, 1)')
    axes[0, 1].legend(signals.columns)
    axes[0, 1].grid(True, alpha=0.3)
    
    # 3. Кумулятивная доходность
    axes[1, 0].plot(basket_cumulative, label='Корзина', linewidth=2)
    axes[1, 0].plot(strategy_cumulative, label='Mean-Reversion', linewidth=2)
    axes[1, 0].set_title('Кумулятивная доходность')
    axes[1, 0].set_ylabel('Доходность (разы)')
    axes[1, 0].legend()
    axes[1, 0].grid(True, alpha=0.3)
    
    # 4. Распределение относительных доходностей
    for symbol in relative_returns.columns:
        axes[1, 1].hist(relative_returns[symbol].dropna(), 
                       bins=50, alpha=0.5, label=symbol, density=True)
    axes[1, 1].set_title('Распределение относительных доходностей')
    axes[1, 1].set_xlabel('Отклонение от корзины')
    axes[1, 1].set_ylabel('Плотность')
    axes[1, 1].legend()
    axes[1, 1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(r'D:\TradingSystems\OLTP\historicalData\cross_sectional_analysis.png', 
                dpi=150, bbox_inches='tight')
    plt.show()
    
    print(f"\nГрафики сохранены: cross_sectional_analysis.png")

if __name__ == "__main__":
    results = run_cross_sectional_analysis()
```

## **Где работает кросс-секционная mean-reversion:**

### **1. Внутри сектора акций:**
- **Корзина:** Акции технологического сектора (AAPL, MSFT, GOOGL, AMZN)
- **Механика:** Если AAPL вырос на 5%, а сектор на 2%, AAPL может скорректироваться

### **2. Валютные пары:**
- **Корзина:** EURUSD, GBPUSD, USDJPY (все против USD)
- **Механика:** Если EURUSD сильно вырос, а другие нет, может быть коррекция

### **3. Товары:**
- **Корзина:** Золото, серебро, платина (драгметаллы)
- **Механика:** Относительная цена между металлами выравнивается

## **Ключевые особенности:**

### **1. НЕ требует, чтобы цены были mean-reverting!**
- Отдельные инструменты могут быть random walk
- **Но их ОТНОСИТЕЛЬНЫЕ движения** mean-reverting

### **2. Работает даже на растущем/падающем рынке:**
```python
# Весь рынок растет (+10% за месяц)
# Но:
# - Stock A: +15% (опережает)
# - Stock B: +5% (отстает)
# Стратегия: Short A, Long B
```

### **3. Market-neutral по корзине:**
- Long отстающие + Short лидирующие
- Общая позиция нейтральна к движению корзины
- **Доходность = разница в относительных движениях**

## **Тест на ваших данных:**

Давайте проверим, есть ли кросс-секционная mean-reversion в ваших данных:

```python
# quick_cross_sectional_test.py
import pandas as pd
import numpy as np

def quick_test():
    """Быстрый тест на кросс-секционную mean-reversion"""
    
    base_path = r"D:\TradingSystems\OLTP\historicalData"
    
    # Тест 1: Forex корзина
    print("ТЕСТ 1: FOREX КОРЗИНА (EURUSD, GBPUSD, USDJPY)")
    print("-" * 50)
    
    forex_data = {}
    for symbol in ['EURUSD', 'GBPUSD', 'USDJPY']:
        df = pd.read_csv(f"{base_path}\\forex\\{symbol}.csv", 
                        parse_dates=['Date'], index_col='Date')
        forex_data[symbol] = df['Close']
    
    forex_df = pd.DataFrame(forex_data).dropna()
    test_basket(forex_df, "Forex Basket")
    
    # Тест 2: Stocks корзина
    print("\n" + "="*60)
    print("ТЕСТ 2: STOCKS КОРЗИНА (AAPL, SPY)")
    print("-" * 50)
    
    stocks_data = {}
    for symbol in ['AAPL', 'SPY']:
        df = pd.read_csv(f"{base_path}\\stocks\\{symbol}.csv", 
                        parse_dates=['Date'], index_col='Date')
        stocks_data[symbol] = df['Close']
    
    stocks_df = pd.DataFrame(stocks_data).dropna()
    test_basket(stocks_df, "Stocks Basket")

def test_basket(prices_df, basket_name):
    """Тестирование корзины на mean-reversion"""
    
    # Рассчитать доходности
    returns = prices_df.pct_change().dropna()
    
    # Средняя доходность корзины
    basket_returns = returns.mean(axis=1)
    
    # Относительные доходности
    relative_returns = returns.sub(basket_returns, axis=0)
    
    print(f"\n{basket_name}:")
    print(f"  Период: {returns.index[0].date()} - {returns.index[-1].date()}")
    print(f"  Инструментов: {len(returns.columns)}")
    print(f"  Торговых дней: {len(returns)}")
    
    # Автокорреляция относительных доходностей
    print(f"\n  Автокорреляция относительных доходностей (lag=1):")
    
    mean_reversion_count = 0
    total_count = 0
    
    for symbol in relative_returns.columns:
        rel_series = relative_returns[symbol].dropna()
        
        if len(rel_series) > 10:
            autocorr = rel_series.autocorr(lag=1)
            
            print(f"    {symbol}: {autocorr:7.4f}", end="")
            
            if autocorr < -0.1:
                print("  ✓ Mean-reversion")
                mean_reversion_count += 1
            elif autocorr > 0.1:
                print("  ✗ Momentum")
            else:
                print("  ~ Random")
            
            total_count += 1
    
    print(f"\n  Итог: {mean_reversion_count}/{total_count} инструментов показывают mean-reversion")
    
    # Средняя автокорреляция
    avg_autocorr = relative_returns.apply(lambda x: x.autocorr(lag=1)).mean()
    print(f"  Средняя автокорреляция: {avg_autocorr:.4f}")
    
    if avg_autocorr < -0.05:
        print(f"  ВЫВОД: ✓ Корзина показывает кросс-секционную mean-reversion!")
    elif avg_autocorr > 0.05:
        print(f"  ВЫВОД: ✗ Корзина показывает momentum (анти-reversion)")
    else:
        print(f"  ВЫВОД: ~ Слабая или отсутствующая mean-reversion")

if __name__ == "__main__":
    quick_test()
```

## **Торговая стратегия на основе этого:**

**Pair Trading / Statistical Arbitrage:**
```
Для каждой пары инструментов (i, j) в корзине:
1. Рассчитать относительную силу: z = (return_i - return_j)
2. Если z > threshold: Short i, Long j
3. Если z < -threshold: Long i, Short j
4. Выход когда z ≈ 0
```

## **Почему это может работать:**

1. **Институциональные потоки:** Большие деньги перетекают между инструментами
2. **Индексные фонды:** Автоматическая ребалансировка
3. **Психология:** Трейдеры фиксируют прибыль в лидерах, покупают отстающих
4. **Ликвидность:** Деньги ищут недооцененные активы

## **Важное ограничение:**

**Кросс-секционная mean-reversion НЕ гарантирована!**
- Инструменты могут дивергировать навсегда
- Нужен стоп-лосс на случай break down
- Требуется постоянный мониторинг корреляций

**Хотите реализовать полноценную стратегию pair trading на основе кросс-секционной mean-reversion для ваших данных?**




**Отлично! Вы прекрасно объяснили связь между mean-reversion, стационарностью и тестами ADF/Variance Ratio.** Давайте углубимся в эту тему.

## **Ключевое понимание:**

### **Два эквивалентных взгляда на одно явление:**

| Mean-Reversion (ADF тест) | Стационарность (Variance Ratio/Hurst) |
|--------------------------|--------------------------------------|
| **Фокус:** Возврат к среднему | **Фокус:** Скорость роста дисперсии |
| **Модель:** AR(1): ΔP = α(μ-P) + ε | **Модель:** Var(log(P)) ∝ τ²ᴴ |
| **Тест:** ADF (α ≠ 0?) | **Тест:** Variance Ratio (H = 0.5?) |
| **H₀:** Random Walk (α = 0) | **H₀:** Random Walk (H = 0.5) |

## **Математическая связь:**

### **1. Mean-Reversion модель:**
```
ΔP_t = α(μ - P_{t-1}) + ε_t, где ε_t ~ N(0, σ²)
```
- α < 0 → mean-reversion
- α = 0 → random walk
- α > 0 → momentum (взрывной процесс)

**ADF тест проверяет:** H₀: α = 0

### **2. Стационарность через Hurst exponent:**
Для стационарного ряда:
```
Var(P(t+τ) - P(t)) ∝ τ²ᴴ
```
где:
- **H = 0.5** → Random Walk (дисперсия ∝ τ)
- **H < 0.5** → Mean-Reversion (дисперсия растет медленнее)
- **H > 0.5** → Trend/Momentum (дисперсия растет быстрее)

## **Реализация обоих тестов на Python:**

```python
# comprehensive_stationarity_tests.py
import pandas as pd
import numpy as np
from statsmodels.tsa.stattools import adfuller
import matplotlib.pyplot as plt
from scipy import stats

class StationarityAnalyzer:
    """Комплексный анализ стационарности и mean-reversion"""
    
    def __init__(self, confidence_level=0.05):
        self.confidence = confidence_level
    
    def adf_test(self, price_series):
        """Тест Дики-Фуллера (Augmented Dickey-Fuller)"""
        
        result = adfuller(price_series.dropna(), autolag='AIC')
        
        adf_statistic = result[0]
        p_value = result[1]
        critical_values = result[4]
        
        return {
            'adf_statistic': adf_statistic,
            'p_value': p_value,
            'critical_values': critical_values,
            'is_stationary': p_value < self.confidence
        }
    
    def calculate_hurst_exponent(self, price_series, max_lag=50):
        """Расчет экспоненты Хёрста методом R/S анализа"""
        
        returns = np.log(price_series).diff().dropna()
        lags = range(2, max_lag)
        
        tau = []  # временные лаги
        rs = []   # R/S значения
        
        for lag in lags:
            # Разделить ряд на подпериоды длины lag
            n = len(returns)
            k = n // lag
            
            if k < 2:
                continue
            
            r_s_values = []
            
            for i in range(k):
                subset = returns[i*lag:(i+1)*lag]
                
                if len(subset) < 2:
                    continue
                
                # Среднее и отклонение
                mean = np.mean(subset)
                deviations = subset - mean
                
                # Накопленные отклонения
                z = np.cumsum(deviations)
                
                # Range
                r = np.max(z) - np.min(z)
                
                # Стандартное отклонение
                s = np.std(subset)
                
                if s > 0:
                    r_s_values.append(r / s)
            
            if r_s_values:
                tau.append(lag)
                rs.append(np.mean(r_s_values))
        
        # Линейная регрессия в логарифмическом масштабе
        if len(tau) > 2:
            log_tau = np.log(tau)
            log_rs = np.log(rs)
            
            # OLS регрессия: log(R/S) = log(c) + H * log(τ)
            slope, intercept, r_value, p_value, std_err = stats.linregress(log_tau, log_rs)
            
            hurst_exponent = slope
            
            return {
                'hurst': hurst_exponent,
                'r_squared': r_value**2,
                'tau': tau,
                'rs': rs,
                'log_tau': log_tau,
                'log_rs': log_rs,
                'intercept': intercept
            }
        
        return None
    
    def variance_ratio_test(self, price_series, lags=[2, 4, 8, 16]):
        """Variance Ratio тест (Lo-MacKinlay)"""
        
        returns = np.log(price_series).diff().dropna()
        n = len(returns)
        
        results = {}
        
        for q in lags:
            if q >= n:
                continue
            
            # 1-period variance
            var_1 = np.var(returns)
            
            # q-period variance
            # Создать q-period returns
            q_returns = []
            for i in range(0, n - q + 1, q):
                q_return = np.log(price_series.iloc[i + q]) - np.log(price_series.iloc[i])
                q_returns.append(q_return)
            
            var_q = np.var(q_returns) / q
            
            # Variance Ratio
            vr = var_q / var_1
            
            # Статистика теста
            mu = np.mean(returns)
            phi = 0
            
            # Оценка асимптотической дисперсии
            for j in range(1, q):
                autocov = np.cov(returns[j:], returns[:-j])[0, 1]
                phi += (2 * (q - j) / q)**2 * autocov / var_1
            
            # Статистика теста
            m = (n * q) if q < n else n
            test_stat = (vr - 1) / np.sqrt(phi / m)
            
            # p-value (двусторонний тест)
            p_value = 2 * (1 - stats.norm.cdf(abs(test_stat)))
            
            results[q] = {
                'variance_ratio': vr,
                'test_statistic': test_stat,
                'p_value': p_value,
                'reject_random_walk': p_value < self.confidence
            }
        
        return results
    
    def analyze_series(self, price_series, name=""):
        """Полный анализ временного ряда"""
        
        print(f"\n{'='*60}")
        print(f"АНАЛИЗ: {name}")
        print(f"{'='*60}")
        
        # 1. ADF тест
        print("\n1. ADF ТЕСТ (Mean-Reversion):")
        adf_results = self.adf_test(price_series)
        
        print(f"   ADF статистика: {adf_results['adf_statistic']:.4f}")
        print(f"   p-value: {adf_results['p_value']:.4f}")
        
        if adf_results['is_stationary']:
            print("   ✓ Отвергаем H₀: ряд СТАЦИОНАРЕН (mean-reverting)")
        else:
            print("   ✗ Не отвергаем H₀: ряд НЕСТАЦИОНАРЕН (random walk)")
        
        # 2. Hurst Exponent
        print("\n2. HURST EXPONENT АНАЛИЗ:")
        hurst_results = self.calculate_hurst_exponent(price_series)
        
        if hurst_results:
            H = hurst_results['hurst']
            print(f"   Hurst exponent (H): {H:.4f}")
            print(f"   R²: {hurst_results['r_squared']:.4f}")
            
            if H < 0.5:
                print("   ✓ H < 0.5: Mean-Reversion (антиперсистентность)")
            elif H > 0.5:
                print("   ✗ H > 0.5: Trend/Momentum (персистентность)")
            else:
                print("   ~ H ≈ 0.5: Random Walk")
        else:
            print("   Не удалось рассчитать Hurst exponent")
        
        # 3. Variance Ratio тест
        print("\n3. VARIANCE RATIO ТЕСТ:")
        vr_results = self.variance_ratio_test(price_series)
        
        for q, result in vr_results.items():
            print(f"   Lag {q}: VR = {result['variance_ratio']:.4f}, "
                  f"p = {result['p_value']:.4f}", end="")
            
            if result['reject_random_walk']:
                if result['variance_ratio'] < 1:
                    print(" ✓ Mean-Reversion")
                else:
                    print(" ✗ Momentum")
            else:
                print(" ~ Random Walk")
        
        return {
            'adf': adf_results,
            'hurst': hurst_results,
            'variance_ratio': vr_results,
            'name': name
        }

# Анализ ваших данных
def analyze_your_data():
    """Анализ всех ваших временных рядов"""
    
    base_path = r"D:\TradingSystems\OLTP\historicalData"
    analyzer = StationarityAnalyzer(confidence_level=0.05)
    
    all_results = {}
    
    # 1. Forex данные
    print("\n" + "="*60)
    print("FOREX АНАЛИЗ")
    print("="*60)
    
    forex_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
    for symbol in forex_symbols:
        try:
            df = pd.read_csv(f"{base_path}\\forex\\{symbol}.csv", 
                           parse_dates=['Date'], index_col='Date')
            results = analyzer.analyze_series(df['Close'], f"FOREX: {symbol}")
            all_results[symbol] = results
        except Exception as e:
            print(f"Ошибка загрузки {symbol}: {e}")
    
    # 2. Stocks данные
    print("\n" + "="*60)
    print("STOCKS АНАЛИЗ")
    print("="*60)
    
    stock_symbols = ['AAPL', 'SPY']
    for symbol in stock_symbols:
        try:
            df = pd.read_csv(f"{base_path}\\stocks\\{symbol}.csv", 
                           parse_dates=['Date'], index_col='Date')
            results = analyzer.analyze_series(df['Close'], f"STOCK: {symbol}")
            all_results[symbol] = results
        except Exception as e:
            print(f"Ошибка загрузки {symbol}: {e}")
    
    return all_results

def create_summary_table(results_dict):
    """Создать сводную таблицу результатов"""
    
    summary_data = []
    
    for symbol, results in results_dict.items():
        row = {
            'Symbol': symbol,
            'ADF p-value': results['adf']['p_value'],
            'ADF Stationary': results['adf']['is_stationary'],
            'Hurst Exponent': results['hurst']['hurst'] if results['hurst'] else np.nan,
            'Market Type': classify_market_type(results)
        }
        summary_data.append(row)
    
    summary_df = pd.DataFrame(summary_data)
    
    print("\n" + "="*60)
    print("СВОДНАЯ ТАБЛИЦА РЕЗУЛЬТАТОВ")
    print("="*60)
    print(summary_df.to_string(index=False))
    
    # Сохранить
    summary_path = r"D:\TradingSystems\OLTP\historicalData\stationarity_summary.csv"
    summary_df.to_csv(summary_path, index=False)
    print(f"\nСводная таблица сохранена: {summary_path}")
    
    return summary_df

def classify_market_type(results):
    """Классификация типа рынка по результатам тестов"""
    
    adf_stationary = results['adf']['is_stationary']
    hurst = results['hurst']['hurst'] if results['hurst'] else 0.5
    
    if adf_stationary and hurst < 0.45:
        return "STRONG MEAN-REVERSION"
    elif adf_stationary and hurst < 0.5:
        return "WEAK MEAN-REVERSION"
    elif not adf_stationary and hurst > 0.55:
        return "TREND/MOMENTUM"
    elif not adf_stationary and hurst > 0.5:
        return "WEAK MOMENTUM"
    else:
        return "RANDOM WALK"

# Визуализация результатов
def visualize_results(results_dict):
    """Визуализация результатов анализа"""
    
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    
    symbols = list(results_dict.keys())
    
    for idx, symbol in enumerate(symbols[:6]):  # Первые 6 символов
        ax = axes[idx//3, idx%3]
        results = results_dict[symbol]
        
        if results['hurst']:
            # График R/S анализа
            ax.scatter(results['hurst']['log_tau'], 
                      results['hurst']['log_rs'], 
                      alpha=0.6, label='Данные')
            
            # Линия регрессии
            x_fit = np.array([min(results['hurst']['log_tau']), 
                            max(results['hurst']['log_tau'])])
            y_fit = results['hurst']['intercept'] + results['hurst']['hurst'] * x_fit
            
            ax.plot(x_fit, y_fit, 'r-', 
                   label=f'H = {results["hurst"]["hurst"]:.3f}')
            
            ax.set_xlabel('log(τ)')
            ax.set_ylabel('log(R/S)')
            ax.set_title(f'{symbol} - R/S Analysis')
            ax.legend()
            ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(r'D:\TradingSystems\OLTP\historicalData\hurst_analysis.png', 
                dpi=150, bbox_inches='tight')
    plt.show()
    
    # Визуализация Hurst exponents
    fig, ax = plt.subplots(figsize=(10, 6))
    
    hurst_values = []
    symbol_names = []
    
    for symbol, results in results_dict.items():
        if results['hurst']:
            hurst_values.append(results['hurst']['hurst'])
            symbol_names.append(symbol)
    
    colors = []
    for h in hurst_values:
        if h < 0.45:
            colors.append('green')  # Mean-reversion
        elif h > 0.55:
            colors.append('red')    # Momentum
        else:
            colors.append('gray')   # Random walk
    
    bars = ax.bar(symbol_names, hurst_values, color=colors, alpha=0.7)
    ax.axhline(y=0.5, color='black', linestyle='--', label='Random Walk (H=0.5)')
    ax.axhline(y=0.45, color='green', linestyle=':', alpha=0.5, label='Mean-Reversion threshold')
    ax.axhline(y=0.55, color='red', linestyle=':', alpha=0.5, label='Momentum threshold')
    
    ax.set_xlabel('Символ')
    ax.set_ylabel('Hurst Exponent')
    ax.set_title('Экспоненты Хёрста для различных активов')
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(r'D:\TradingSystems\OLTP\historicalData\hurst_bar_chart.png', 
                dpi=150, bbox_inches='tight')
    plt.show()

if __name__ == "__main__":
    # Запустить полный анализ
    print("ПОЛНЫЙ АНАЛИЗ СТАЦИОНАРНОСТИ И MEAN-REVERSION")
    print("="*60)
    
    results = analyze_your_data()
    
    if results:
        summary_df = create_summary_table(results)
        visualize_results(results)
        
        # Вывод рекомендаций по стратегиям
        print("\n" + "="*60)
        print("РЕКОМЕНДАЦИИ ПО СТРАТЕГИЯМ")
        print("="*60)
        
        for _, row in summary_df.iterrows():
            market_type = row['Market Type']
            
            if "MEAN-REVERSION" in market_type:
                print(f"\n{row['Symbol']}: {market_type}")
                print(f"  Рекомендуемые стратегии:")
                print(f"  • Mean-reversion trading (RSI, Bollinger Bands)")
                print(f"  • Pair trading/Statistical arbitrage")
                print(f"  • Range-bound strategies")
            
            elif "MOMENTUM" in market_type:
                print(f"\n{row['Symbol']}: {market_type}")
                print(f"  Рекомендуемые стратегии:")
                print(f"  • Trend following")
                print(f"  • Moving average crossovers")
                print(f"  • Breakout strategies")
            
            elif "RANDOM WALK" in market_type:
                print(f"\n{row['Symbol']}: {market_type}")
                print(f"  Рекомендуемые стратегии:")
                print(f"  • Market making (если ликвидность)")
                print(f"  • Very short-term mean-reversion")
                print(f"  • Осторожно: большинство стратегий могут не работать")
```

## **Практическая интерпретация результатов:**

### **Сценарий 1: Сильная mean-reversion**
```
ADF p-value: 0.001 ✓
Hurst: 0.35 ✓
Variance Ratio: 0.7 (p=0.01) ✓
```
**Вывод:** Цена активно возвращается к среднему. Можно торговать reversal стратегии.

### **Сценарий 2: Слабая mean-reversion**
```
ADF p-value: 0.03 ✓
Hurst: 0.48 ~
Variance Ratio: 0.9 (p=0.2) ✗
```
**Вывод:** Есть признаки mean-reversion, но слабые. Нужны осторожные стратегии.

### **Сценарий 3: Random Walk**
```
ADF p-value: 0.35 ✗
Hurst: 0.51 ~
Variance Ratio: 1.05 (p=0.4) ✗
```
**Вывод:** Цена непредсказуема. Только трендовые стратегии или market making.

### **Сценарий 4: Momentum/Trend**
```
ADF p-value: 0.42 ✗
Hurst: 0.65 ✓
Variance Ratio: 1.3 (p=0.02) ✓
```
**Вывод:** Ярко выраженные тренды. Идеально для trend following.

## **Важные нюансы:**

### **1. Зависимость от таймфрейма:**
```python
# Один и тот же инструмент может показывать разное поведение:
# - На 1-минутном: Mean-reversion (H=0.4)  # Микроструктура
# - На часовом: Random Walk (H=0.5)        # Эффективный рынок
# - На дневном: Momentum (H=0.6)           # Фундаментальные тренды
```

### **2. Структурные breaks:**
```python
# Рынок может менять режимы:
# 2008-2009: Mean-reversion (высокая волатильность)
# 2010-2019: Random Walk (стабильность)
# 2020: Momentum (резкие движения)
```

### **3. Ограничения тестов:**
- **ADF:** Чувствителен к выбору лагов
- **Hurst:** Нужны длинные ряды данных
- **Variance Ratio:** Предполагает нормальность

## **Практическое применение для трейдинга:**

```python
def adaptive_strategy_selection(price_series, lookback_days=252):
    """Адаптивный выбор стратегии на основе текущего режима рынка"""
    
    # Анализ последних lookback_days дней
    recent_prices = price_series[-lookback_days:]
    
    analyzer = StationarityAnalyzer()
    
    # 1. ADF тест
    adf_results = analyzer.adf_test(recent_prices)
    
    # 2. Hurst exponent
    hurst_results = analyzer.calculate_hurst_exponent(recent_prices)
    
    # Классификация
    if adf_results['is_stationary'] and hurst_results['hurst'] < 0.45:
        strategy = "MEAN_REVERSION"
        params = {
            'type': 'reversal',
            'indicators': ['RSI', 'BollingerBands'],
            'stop_loss_pct': 2.0,
            'take_profit_pct': 1.5
        }
    
    elif not adf_results['is_stationary'] and hurst_results['hurst'] > 0.55:
        strategy = "TREND_FOLLOWING"
        params = {
            'type': 'trend',
            'indicators': ['EMA_Cross', 'ADX'],
            'stop_loss_pct': 3.0,
            'trailing_stop': True
        }
    
    else:
        strategy = "MARKET_NEUTRAL"
        params = {
            'type': 'neutral',
            'indicators': ['Statistical_Arbitrage'],
            'position_size': 'small',
            'max_drawdown': 1.0
        }
    
    return strategy, params
```

## **Ключевой вывод:**

**ADF и Variance Ratio/Hurst тесты дополняют друг друга:**

1. **ADF** лучше обнаруживает сильную mean-reversion
2. **Hurst** показывает степень mean-reversion/momentum
3. **Вместе** они дают полную картину поведения цены

**Запустите этот анализ на ваших данных и увидите, какие инструменты действительно mean-reverting, а какие - random walk или trending!**

# 1. Убедитесь, что есть данные металлов
python D:\TradingSystems\PythonScripts\simple_metals_minute.py

# 2. Запустите адаптивную систему
python D:\TradingSystems\PythonScripts\adaptive_trading_system.py