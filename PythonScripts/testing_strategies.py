# test_strategies.py
import pandas as pd
import numpy as np
import os
from datetime import datetime


def load_data(symbol, asset_type='forex'):
    """Загрузить данные для символа"""
    path = f"D:\\TradingSystems\\OLTP\\historicalData\\{asset_type}\\{symbol}.csv"
    df = pd.read_csv(path, parse_dates=['Date'])
    return df


def calculate_metrics(returns, trades=None):
    """Рассчитать метрики производительности"""
    if len(returns) == 0:
        return {}

    total_return = np.prod(1 + returns) - 1
    sharpe = returns.mean() / returns.std() * np.sqrt(252) if returns.std() > 0 else 0
    max_drawdown = calculate_max_drawdown(returns)

    metrics = {
        'total_return': total_return,
        'annual_return': (1 + total_return) ** (252 / len(returns)) - 1,
        'sharpe_ratio': sharpe,
        'max_drawdown': max_drawdown,
        'volatility': returns.std() * np.sqrt(252),
        'win_rate': (returns > 0).mean() if trades is None else trades['is_win'].mean()
    }

    return metrics


def calculate_max_drawdown(returns):
    """Расчет максимальной просадки"""
    cumulative = np.cumprod(1 + returns)
    peak = np.maximum.accumulate(cumulative)
    drawdown = (cumulative - peak) / peak
    return np.min(drawdown)


def moving_average_crossover(df, fast_period=10, slow_period=30):
    """Стратегия пересечения скользящих средних"""
    df = df.copy()

    # Рассчитать MA
    df['MA_Fast'] = df['Close'].rolling(window=fast_period).mean()
    df['MA_Slow'] = df['Close'].rolling(window=slow_period).mean()

    # Генерировать сигналы
    df['Signal'] = 0
    df.loc[df['MA_Fast'] > df['MA_Slow'], 'Signal'] = 1
    df['Position'] = df['Signal'].diff()

    # Рассчитать доходность
    df['Market_Return'] = df['Close'].pct_change()
    df['Strategy_Return'] = df['Signal'].shift(1) * df['Market_Return']

    # Удалить NaN
    df = df.dropna()

    # Детали сделок
    buy_signals = df[df['Position'] == 1]
    sell_signals = df[df['Position'] == -1]

    trades = []
    for i in range(min(len(buy_signals), len(sell_signals))):
        if i < len(buy_signals) and i < len(sell_signals):
            trade = {
                'buy_date': buy_signals.iloc[i]['Date'],
                'sell_date': sell_signals.iloc[i]['Date'],
                'buy_price': buy_signals.iloc[i]['Close'],
                'sell_price': sell_signals.iloc[i]['Close'],
                'return': (sell_signals.iloc[i]['Close'] / buy_signals.iloc[i]['Close']) - 1
            }
            trades.append(trade)

    trades_df = pd.DataFrame(trades) if trades else pd.DataFrame()
    if not trades_df.empty:
        trades_df['is_win'] = trades_df['return'] > 0

    return df['Strategy_Return'], trades_df


def rsi_strategy(df, rsi_period=14, oversold=30, overbought=70):
    """Стратегия RSI (индекс относительной силы)"""
    df = df.copy()

    # Рассчитать RSI
    delta = df['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=rsi_period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=rsi_period).mean()
    rs = gain / loss
    df['RSI'] = 100 - (100 / (1 + rs))

    # Генерировать сигналы
    df['Signal'] = 0
    df.loc[df['RSI'] < oversold, 'Signal'] = 1  # Покупка при перепроданности
    df.loc[df['RSI'] > overbought, 'Signal'] = -1  # Продажа при перекупленности
    df['Position'] = df['Signal'].diff()

    # Рассчитать доходность
    df['Market_Return'] = df['Close'].pct_change()
    df['Strategy_Return'] = df['Signal'].shift(1) * df['Market_Return']

    # Удалить NaN
    df = df.dropna()

    return df['Strategy_Return'], pd.DataFrame()


def bollinger_bands_strategy(df, period=20, std_dev=2):
    """Стратегия полос Боллинджера"""
    df = df.copy()

    # Рассчитать полосы Боллинджера
    df['MA'] = df['Close'].rolling(window=period).mean()
    df['Std'] = df['Close'].rolling(window=period).std()
    df['Upper'] = df['MA'] + (df['Std'] * std_dev)
    df['Lower'] = df['MA'] - (df['Std'] * std_dev)

    # Генерировать сигналы
    df['Signal'] = 0
    df.loc[df['Close'] < df['Lower'], 'Signal'] = 1  # Покупка ниже нижней полосы
    df.loc[df['Close'] > df['Upper'], 'Signal'] = -1  # Продажа выше верхней полосы
    df['Position'] = df['Signal'].diff()

    # Рассчитать доходность
    df['Market_Return'] = df['Close'].pct_change()
    df['Strategy_Return'] = df['Signal'].shift(1) * df['Market_Return']

    # Удалить NaN
    df = df.dropna()

    return df['Strategy_Return'], pd.DataFrame()


def test_all_strategies():
    """Протестировать все стратегии на всех активах"""

    symbols = {
        'forex': ['EURUSD', 'GBPUSD', 'USDJPY'],
        'stocks': ['AAPL', 'SPY']
    }

    strategies = {
        'MA_Crossover': moving_average_crossover,
        'RSI': rsi_strategy,
        'Bollinger_Bands': bollinger_bands_strategy
    }

    results = {}

    print("ТЕСТИРОВАНИЕ ТОРГОВЫХ СТРАТЕГИЙ")
    print("=" * 70)

    for asset_type, symbol_list in symbols.items():
        print(f"\n{'=' * 70}")
        print(f"{asset_type.upper()}")
        print(f"{'=' * 70}")

        for symbol in symbol_list:
            print(f"\n{symbol}:")

            try:
                # Загрузить данные
                df = load_data(symbol, asset_type)

                # Рыночная доходность (Buy & Hold)
                market_returns = df['Close'].pct_change().dropna()
                market_metrics = calculate_metrics(market_returns)

                print(f"  Buy & Hold:")
                print(f"    Доходность: {market_metrics['total_return'] * 100:6.2f}%")
                print(f"    Sharpe:     {market_metrics['sharpe_ratio']:6.2f}")
                print(f"    Макс DD:    {market_metrics['max_drawdown'] * 100:6.2f}%")

                # Тестировать каждую стратегию
                for strategy_name, strategy_func in strategies.items():
                    returns, trades = strategy_func(df.copy())

                    if len(returns) > 0:
                        metrics = calculate_metrics(returns, trades)

                        print(f"\n  {strategy_name}:")
                        print(f"    Доходность: {metrics['total_return'] * 100:6.2f}%")
                        print(f"    Sharpe:     {metrics['sharpe_ratio']:6.2f}")
                        print(f"    Макс DD:    {metrics['max_drawdown'] * 100:6.2f}%")
                        print(f"    Волатильность: {metrics['volatility'] * 100:6.2f}%")

                        if not trades.empty:
                            print(f"    Сделок: {len(trades)}")
                            print(f"    Win Rate: {metrics['win_rate'] * 100:5.1f}%")
                            print(f"    Средняя сделка: {trades['return'].mean() * 100:5.2f}%")

                        # Сохранить результаты
                        key = f"{symbol}_{strategy_name}"
                        results[key] = {
                            'symbol': symbol,
                            'strategy': strategy_name,
                            'metrics': metrics,
                            'returns': returns,
                            'trades': trades
                        }

            except Exception as e:
                print(f"  Ошибка: {e}")

    return results


# Запустить тестирование
if __name__ == "__main__":
    results = test_all_strategies()

    # Сохранить результаты
    if results:
        import json

        # Сохранить метрики в JSON
        metrics_dict = {}
        for key, result in results.items():
            metrics_dict[key] = {
                'symbol': result['symbol'],
                'strategy': result['strategy'],
                **{k: (float(v) if isinstance(v, (np.float64, np.int64)) else v)
                   for k, v in result['metrics'].items()}
            }

        output_path = r"D:\TradingSystems\OLTP\historicalData\strategy_results.json"
        with open(output_path, 'w') as f:
            json.dump(metrics_dict, f, indent=2, default=str)

        print(f"\n{'=' * 70}")
        print(f"Результаты сохранены в: {output_path}")