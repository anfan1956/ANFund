# adaptive_trading_system.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import time
import threading
import json
import os
from typing import Dict, List, Optional, Tuple


class MarketRegimeDetector:
    """Детектор рыночных режимов"""

    def __init__(self, lookback_periods: Dict[str, int] = None):
        self.lookback = lookback_periods or {
            'short': 20,  # Для MA кроссоверов
            'medium': 60,  # Для volatility
            'long': 252  # Для ADF/Hurst
        }

        # Пороги для классификации
        self.thresholds = {
            'adf_pvalue': 0.05,
            'hurst_mean_rev': 0.45,
            'hurst_trend': 0.55,
            'ma_crossover_signal': 0.01  # 1% разница
        }

    def calculate_indicators(self, prices: pd.Series) -> Dict:
        """Расчет всех индикаторов для определения режима"""

        returns = prices.pct_change().dropna()

        indicators = {
            'prices': prices,
            'returns': returns,
            'timestamp': datetime.now()
        }

        # 1. Moving Average Crossover (трендовый сигнал)
        indicators['ma_fast'] = prices.rolling(self.lookback['short']).mean()
        indicators['ma_slow'] = prices.rolling(self.lookback['medium']).mean()
        indicators['ma_diff_pct'] = (
                (indicators['ma_fast'] - indicators['ma_slow']) / indicators['ma_slow']
        ).iloc[-1]

        # 2. Volatility (ATR)
        high = prices.rolling(self.lookback['short']).max()
        low = prices.rolling(self.lookback['short']).min()
        indicators['atr'] = (high - low).mean()
        indicators['volatility_pct'] = returns.std() * np.sqrt(252)

        # 3. ADF test (упрощенный)
        indicators['adf_pvalue'] = self._simplified_adf_test(prices)

        # 4. Hurst exponent (упрощенный)
        indicators['hurst'] = self._calculate_hurst_simple(prices)

        # 5. RSI для mean-reversion
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
        rs = gain / loss
        indicators['rsi'] = 100 - (100 / (1 + rs)).iloc[-1]

        return indicators

    def _simplified_adf_test(self, prices: pd.Series) -> float:
        """Упрощенный ADF тест"""
        from statsmodels.tsa.stattools import adfuller

        try:
            result = adfuller(prices.dropna(), maxlag=1)
            return result[1]
        except:
            return 1.0  # Если ошибка - считаем non-stationary

    def _calculate_hurst_simple(self, prices: pd.Series) -> float:
        """Упрощенный расчет Hurst exponent"""
        returns = np.log(prices).diff().dropna()
        n = len(returns)

        if n < 20:
            return 0.5

        # Variance Ratio для lag=2
        var_1 = np.var(returns)

        # 2-period returns
        returns_2 = returns.rolling(2).sum().dropna()
        var_2 = np.var(returns_2) / 2

        vr = var_2 / var_1 if var_1 > 0 else 1.0

        # VR -> Hurst approximation
        hurst = 0.5 + np.log(vr) / (2 * np.log(2))

        return min(max(hurst, 0), 1)  # Ограничить 0-1

    def detect_regime(self, indicators: Dict) -> Tuple[str, float]:
        """Определение текущего рыночного режима"""

        confidence_scores = {
            'MEAN_REVERSION': 0.0,
            'TREND': 0.0,
            'RANDOM_WALK': 0.0
        }

        # 1. Mean-reversion сигналы
        if indicators['adf_pvalue'] < self.thresholds['adf_pvalue']:
            confidence_scores['MEAN_REVERSION'] += 0.4

        if indicators['hurst'] < self.thresholds['hurst_mean_rev']:
            confidence_scores['MEAN_REVERSION'] += 0.3

        if 30 < indicators['rsi'] < 70:
            confidence_scores['MEAN_REVERSION'] += 0.1

        # 2. Trend сигналы
        if abs(indicators['ma_diff_pct']) > self.thresholds['ma_crossover_signal']:
            confidence_scores['TREND'] += 0.4

        if indicators['hurst'] > self.thresholds['hurst_trend']:
            confidence_scores['TREND'] += 0.3

        if indicators['rsi'] < 30 or indicators['rsi'] > 70:
            confidence_scores['TREND'] += 0.1  # Перекупленность/перепроданность

        # 3. Random walk сигналы
        if (0.45 <= indicators['hurst'] <= 0.55 and
                indicators['adf_pvalue'] > 0.1):
            confidence_scores['RANDOM_WALK'] += 0.7

        # Нормализация
        total = sum(confidence_scores.values())
        if total > 0:
            for key in confidence_scores:
                confidence_scores[key] /= total

        # Определение режима
        regime = max(confidence_scores, key=confidence_scores.get)
        confidence = confidence_scores[regime]

        return regime, confidence


class KellyPortfolioManager:
    """Менеджер портфеля с расчетом Kelly"""

    def __init__(self, initial_capital: float = 50000, max_leverage: float = 30):
        self.capital = initial_capital
        self.max_leverage = max_leverage
        self.positions = {}  # symbol -> {'size': float, 'entry_price': float}

        # Параметры металлов
        self.metals = {
            'XAUUSD': {
                'ticker': 'GC=F',
                'volatility': 0.015,  # дневная волатильность ~1.5%
                'correlation_matrix': None
            },
            'XAGUSD': {
                'ticker': 'SI=F',
                'volatility': 0.025,  # ~2.5%
                'correlation_matrix': None
            },
            'XPTUSD': {
                'ticker': 'PL=F',
                'volatility': 0.020,  # ~2.0%
                'correlation_matrix': None
            }
        }

    def calculate_kelly_for_metals(self, regime_confidence: float) -> Dict:
        """Расчет размера позиций по Kelly для mean-reversion режима"""

        # Для mean-reversion: win_rate ~60%, win_loss_ratio ~1.0
        # Учитываем confidence режима
        adjusted_win_rate = 0.5 + 0.1 * regime_confidence  # 50-60%
        win_loss_ratio = 1.2  # TP/SL ratio

        # Kelly formula
        p = adjusted_win_rate
        q = 1 - p
        b = win_loss_ratio
        a = 1  # loss = 1 unit

        kelly_fraction = (p / a - q / b)

        # Ограничения
        kelly_fraction = max(0, min(kelly_fraction, 0.1))  # Max 10% per trade
        half_kelly = kelly_fraction / 2  # Более консервативно

        # Распределение между металлами
        positions = {}
        total_risk = self.capital * half_kelly

        # Распределение на основе волатильности (обратно пропорционально)
        volatilities = {sym: data['volatility'] for sym, data in self.metals.items()}
        total_inv_vol = sum(1 / v for v in volatilities.values())

        for symbol, vol in volatilities.items():
            weight = (1 / vol) / total_inv_vol
            position_value = total_risk * weight

            # Расчет количества (упрощенно)
            # В реальности нужно знать цену и размер контракта
            positions[symbol] = {
                'weight': weight,
                'risk_amount': position_value,
                'size': position_value / 1000,  # Упрощенный расчет
                'stop_loss_pct': vol * 1.5,  # Stop loss = 1.5 * дневной волатильности
                'take_profit_pct': vol * 1.5 * win_loss_ratio
            }

        return positions

    def calculate_trend_positions(self, signals: Dict, regime_confidence: float) -> Dict:
        """Расчет позиций для трендового режима"""

        # В трендовом режиме используем меньший размер (более рискованно)
        max_risk = self.capital * 0.02 * regime_confidence  # 2% с учетом confidence

        positions = {}

        for symbol, signal in signals.items():
            if abs(signal) > 0.5:  # Сильный сигнал
                direction = 1 if signal > 0 else -1

                positions[symbol] = {
                    'direction': direction,
                    'size': max_risk / len(signals),
                    'stop_loss_pct': 0.02,  # 2% стоп-лосс
                    'trailing_stop': True,
                    'signal_strength': abs(signal)
                }

        return positions


class AdaptiveTradingBot:
    """Адаптивный торговый бот с переключением режимов"""

    def __init__(self, config: Dict = None):
        self.config = config or {
            'update_interval': 60,  # секунды
            'metals_to_trade': ['XAUUSD', 'XAGUSD', 'XPTUSD'],
            'initial_capital': 50000,
            'max_drawdown': 0.20,  # 20% максимальная просадка
            'data_path': r"D:\TradingSystems\OLTP\historicalData\metals"
        }

        # Инициализация компонентов
        self.regime_detector = MarketRegimeDetector()
        self.portfolio_manager = KellyPortfolioManager(
            initial_capital=self.config['initial_capital']
        )

        # Состояние системы
        self.current_regime = None
        self.regime_confidence = 0.0
        self.active_positions = {}
        self.trade_history = []
        self.is_running = False

        # Загрузка данных
        self.price_data = self.load_metals_data()

        # Статистика
        self.performance_stats = {
            'total_trades': 0,
            'winning_trades': 0,
            'total_pnl': 0.0,
            'current_drawdown': 0.0,
            'max_drawdown': 0.0,
            'regime_changes': 0
        }

    def load_metals_data(self) -> Dict[str, pd.DataFrame]:
        """Загрузка данных по металлам"""

        data = {}

        for metal in self.config['metals_to_trade']:
            try:
                # Ищем файл с минутными данными
                file_patterns = [
                    f"{metal}_1min.csv",
                    f"{metal}_daily.csv",
                    f"{metal}.csv"
                ]

                for pattern in file_patterns:
                    file_path = os.path.join(self.config['data_path'], pattern)
                    if os.path.exists(file_path):
                        df = pd.read_csv(file_path, parse_dates=['DateTime' if 'DateTime' in pd.read_csv(file_path, nrows=1).columns else 'Date'])
                        if 'DateTime' in df.columns:
                            df.set_index('DateTime', inplace=True)
                        else:
                            df.set_index('Date', inplace=True)

                        data[metal] = df
                        print(f"Загружен {metal}: {len(df)} строк")
                        break
            except Exception as e:
                print(f"Ошибка загрузки {metal}: {e}")

        return data

    def monitor_markets(self):
        """Основной цикл мониторинга рынков"""

        print(f"Запуск мониторинга рынков в {datetime.now()}")
        print(f"Торгуемые инструменты: {list(self.price_data.keys())}")

        self.is_running = True

        while self.is_running:
            try:
                # 1. Сбор последних данных
                current_prices = {}
                indicators_by_metal = {}

                for metal, df in self.price_data.items():
                    if len(df) > 100:
                        recent_data = df.iloc[-100:]  # Последние 100 баров
                        prices = recent_data['Close']
                        current_prices[metal] = prices.iloc[-1]

                        # Расчет индикаторов для каждого металла
                        indicators = self.regime_detector.calculate_indicators(prices)
                        indicators_by_metal[metal] = indicators

                if not indicators_by_metal:
                    print("Нет данных для анализа")
                    time.sleep(self.config['update_interval'])
                    continue

                # 2. Агрегация индикаторов по всем металлам
                aggregated_indicators = self.aggregate_indicators(indicators_by_metal)

                # 3. Определение общего режима
                new_regime, confidence = self.regime_detector.detect_regime(
                    aggregated_indicators
                )

                # 4. Проверка изменения режима
                regime_changed = self.check_regime_change(new_regime, confidence)

                if regime_changed:
                    print(f"\n{'=' * 60}")
                    print(f"ИЗМЕНЕНИЕ РЕЖИМА: {self.current_regime} -> {new_regime}")
                    print(f"Confidence: {confidence:.2%}")
                    print(f"Время: {datetime.now()}")
                    print(f"{'=' * 60}")

                    self.current_regime = new_regime
                    self.regime_confidence = confidence
                    self.performance_stats['regime_changes'] += 1

                    # 5. Действия при изменении режима
                    self.handle_regime_change(
                        new_regime,
                        confidence,
                        indicators_by_metal,
                        current_prices
                    )

                # 6. Мониторинг текущих позиций
                self.monitor_positions(current_prices)

                # 7. Логирование состояния
                if datetime.now().second % 30 == 0:  # Каждые 30 секунд
                    self.log_status(current_prices)

                # Пауза перед следующим обновлением
                time.sleep(self.config['update_interval'])

            except Exception as e:
                print(f"Ошибка в цикле мониторинга: {e}")
                time.sleep(10)

    def aggregate_indicators(self, indicators_by_metal: Dict) -> Dict:
        """Агрегация индикаторов по всем металлам"""

        aggregated = {
            'adf_pvalue': np.mean([ind['adf_pvalue'] for ind in indicators_by_metal.values()]),
            'hurst': np.mean([ind['hurst'] for ind in indicators_by_metal.values()]),
            'rsi': np.mean([ind['rsi'] for ind in indicators_by_metal.values()]),
            'ma_diff_pct': np.mean([ind['ma_diff_pct'] for ind in indicators_by_metal.values()]),
            'volatility_pct': np.mean([ind['volatility_pct'] for ind in indicators_by_metal.values()])
        }

        return aggregated

    def check_regime_change(self, new_regime: str, confidence: float) -> bool:
        """Проверка, изменился ли режим"""

        if self.current_regime is None:
            return True

        # Если режим тот же, но confidence изменился значительно
        if self.current_regime == new_regime:
            confidence_change = abs(confidence - self.regime_confidence)
            return confidence_change > 0.3  # Изменение на 30%

        # Если режим другой и confidence достаточно высок
        return confidence > 0.6  # Минимум 60% уверенности

    def handle_regime_change(self, regime: str, confidence: float,
                             indicators: Dict, current_prices: Dict):
        """Обработка изменения режима"""

        # 1. Закрытие позиций при смене режима
        if self.active_positions:
            print(f"Закрытие позиций из-за смены режима...")
            self.close_all_positions(current_prices)

        # 2. Открытие новых позиций в соответствии с режимом
        if regime == 'MEAN_REVERSION':
            self.enter_mean_reversion_mode(confidence, indicators, current_prices)

        elif regime == 'TREND':
            self.enter_trend_mode(confidence, indicators, current_prices)

        elif regime == 'RANDOM_WALK':
            print("Режим RANDOM_WALK - остаемся вне рынка")
            self.active_positions = {}

    def enter_mean_reversion_mode(self, confidence: float, indicators: Dict,
                                  current_prices: Dict):
        """Вход в mean-reversion режим"""

        print("\nВХОД В MEAN-REVERSION РЕЖИМ")
        print(f"Confidence: {confidence:.2%}")

        # Расчет позиций по Kelly
        positions = self.portfolio_manager.calculate_kelly_for_metals(confidence)

        # Открытие позиций
        for metal, position_info in positions.items():
            if metal in current_prices:
                price = current_prices[metal]

                # Определение направления (на основе RSI)
                rsi = indicators[metal]['rsi']
                direction = -1 if rsi > 70 else 1 if rsi < 30 else 0

                if direction != 0:
                    self.open_position(
                        symbol=metal,
                        direction=direction,
                        size=position_info['size'],
                        entry_price=price,
                        stop_loss=price * (1 - direction * position_info['stop_loss_pct']),
                        take_profit=price * (1 + direction * position_info['take_profit_pct']),
                        regime='MEAN_REVERSION'
                    )

    def enter_trend_mode(self, confidence: float, indicators: Dict,
                         current_prices: Dict):
        """Вход в трендовый режим"""

        print("\nВХОД В TREND РЕЖИМ")
        print(f"Confidence: {confidence:.2%}")

        # Генерация трендовых сигналов
        trend_signals = {}

        for metal, ind in indicators.items():
            # Сигнал на основе MA кроссовера
            if abs(ind['ma_diff_pct']) > 0.01:  # 1% разница
                trend_signals[metal] = np.sign(ind['ma_diff_pct'])
            else:
                trend_signals[metal] = 0

        # Расчет позиций
        positions = self.portfolio_manager.calculate_trend_positions(
            trend_signals, confidence
        )

        # Открытие позиций
        for metal, position_info in positions.items():
            if metal in current_prices and position_info['direction'] != 0:
                price = current_prices[metal]
                direction = position_info['direction']

                self.open_position(
                    symbol=metal,
                    direction=direction,
                    size=position_info['size'],
                    entry_price=price,
                    stop_loss=price * (1 - direction * position_info['stop_loss_pct']),
                    take_profit=None,  # Трейлинг стоп в трендовом режиме
                    regime='TREND',
                    trailing_stop=True
                )

    def open_position(self, symbol: str, direction: int, size: float,
                      entry_price: float, stop_loss: float, take_profit: Optional[float],
                      regime: str, trailing_stop: bool = False):
        """Открытие позиции"""

        position_id = f"{symbol}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        position = {
            'id': position_id,
            'symbol': symbol,
            'direction': direction,  # 1 = long, -1 = short
            'size': size,
            'entry_price': entry_price,
            'current_price': entry_price,
            'stop_loss': stop_loss,
            'take_profit': take_profit,
            'regime': regime,
            'trailing_stop': trailing_stop,
            'trailing_stop_activated': False,
            'open_time': datetime.now(),
            'max_favorable': entry_price if direction == 1 else entry_price,
            'min_favorable': entry_price if direction == -1 else entry_price
        }

        self.active_positions[position_id] = position

        print(f"  Открыта позиция: {symbol} {'LONG' if direction == 1 else 'SHORT'}")
        print(f"    Размер: ${size:.2f}, Цена: {entry_price:.4f}")
        print(f"    Stop Loss: {stop_loss:.4f}")
        if take_profit:
            print(f"    Take Profit: {take_profit:.4f}")

        self.performance_stats['total_trades'] += 1

    def monitor_positions(self, current_prices: Dict):
        """Мониторинг текущих позиций"""

        positions_to_close = []

        for position_id, position in list(self.active_positions.items()):
            symbol = position['symbol']

            if symbol not in current_prices:
                continue

            current_price = current_prices[symbol]
            position['current_price'] = current_price

            # Обновление trailing stop для трендовых позиций
            if position['trailing_stop']:
                self.update_trailing_stop(position, current_price)

            # Проверка stop loss
            if (position['direction'] == 1 and current_price <= position['stop_loss']) or \
                    (position['direction'] == -1 and current_price >= position['stop_loss']):
                positions_to_close.append((position_id, 'STOP_LOSS', current_price))

            # Проверка take profit (только для mean-reversion)
            elif position['take_profit'] is not None:
                if (position['direction'] == 1 and current_price >= position['take_profit']) or \
                        (position['direction'] == -1 and current_price <= position['take_profit']):
                    positions_to_close.append((position_id, 'TAKE_PROFIT', current_price))

            # Проверка изменения режима для позиции
            if self.check_position_regime_exit(position):
                positions_to_close.append((position_id, 'REGIME_EXIT', current_price))

        # Закрытие позиций
        for position_id, reason, exit_price in positions_to_close:
            self.close_position(position_id, reason, exit_price)

    def update_trailing_stop(self, position: Dict, current_price: float):
        """Обновление трейлинг стопа"""

        if position['direction'] == 1:  # LONG
            if current_price > position['max_favorable']:
                position['max_favorable'] = current_price
                # Подтягиваем стоп на ATR расстоянии
                atr_distance = current_price * 0.02  # 2% для примера
                new_stop = current_price - atr_distance
                if new_stop > position['stop_loss']:
                    position['stop_loss'] = new_stop
                    position['trailing_stop_activated'] = True

        else:  # SHORT
            if current_price < position['min_favorable']:
                position['min_favorable'] = current_price
                atr_distance = current_price * 0.02
                new_stop = current_price + atr_distance
                if new_stop < position['stop_loss']:
                    position['stop_loss'] = new_stop
                    position['trailing_stop_activated'] = True

    def check_position_regime_exit(self, position: Dict) -> bool:
        """Проверка, нужно ли закрыть позицию из-за изменения режима"""

        # Для mean-reversion позиций: закрываем при переходе к GRW
        if position['regime'] == 'MEAN_REVERSION':
            if self.current_regime in ['RANDOM_WALK', 'TREND']:
                return True

        # Для трендовых позиций: закрываем при переходе к mean-reversion
        elif position['regime'] == 'TREND':
            if self.current_regime == 'MEAN_REVERSION':
                return True

        return False

    def close_position(self, position_id: str, reason: str, exit_price: float):
        """Закрытие позиции"""

        if position_id not in self.active_positions:
            return

        position = self.active_positions[position_id]

        # Расчет P&L
        entry_price = position['entry_price']
        direction = position['direction']
        size = position['size']

        if direction == 1:  # LONG
            pnl = (exit_price - entry_price) * size
        else:  # SHORT
            pnl = (entry_price - exit_price) * size

        pnl_pct = (exit_price / entry_price - 1) * direction * 100

        # Обновление статистики
        self.performance_stats['total_pnl'] += pnl

        if pnl > 0:
            self.performance_stats['winning_trades'] += 1

        # Запись в историю
        trade_record = {
            **position,
            'exit_price': exit_price,
            'exit_time': datetime.now(),
            'pnl': pnl,
            'pnl_pct': pnl_pct,
            'exit_reason': reason,
            'holding_period': (datetime.now() - position['open_time']).total_seconds() / 3600
        }

        self.trade_history.append(trade_record)

        # Удаление из активных позиций
        del self.active_positions[position_id]

        print(f"\nЗакрыта позиция: {position['symbol']}")
        print(f"  Причина: {reason}")
        print(f"  P&L: ${pnl:.2f} ({pnl_pct:.2f}%)")
        print(f"  Время удержания: {trade_record['holding_period']:.1f} часов")

    def close_all_positions(self, current_prices: Dict):
        """Закрытие всех позиций"""

        for position_id in list(self.active_positions.keys()):
            position = self.active_positions[position_id]
            symbol = position['symbol']

            if symbol in current_prices:
                self.close_position(position_id, 'FORCED_CLOSE', current_prices[symbol])

    def log_status(self, current_prices: Dict):
        """Логирование текущего статуса"""

        print(f"\n{'=' * 60}")
        print(f"СТАТУС СИСТЕМЫ - {datetime.now()}")
        print(f"{'=' * 60}")

        print(f"\nТекущий режим: {self.current_regime} "
              f"(Confidence: {self.regime_confidence:.2%})")

        print(f"\nАктивные позиции: {len(self.active_positions)}")

        total_exposure = 0
        for position_id, position in self.active_positions.items():
            symbol = position['symbol']
            current_price = current_prices.get(symbol, position['current_price'])

            # Расчет текущего P&L
            if position['direction'] == 1:
                unrealized_pnl = (current_price - position['entry_price']) * position['size']
            else:
                unrealized_pnl = (position['entry_price'] - current_price) * position['size']

            unrealized_pnl_pct = (current_price / position['entry_price'] - 1) * position['direction'] * 100

            total_exposure += abs(position['size'] * position['entry_price'])

            print(f"  {position_id[:8]}: {symbol} "
                  f"{'LONG' if position['direction'] == 1 else 'SHORT'} "
                  f"| P&L: ${unrealized_pnl:.2f} ({unrealized_pnl_pct:.2f}%)")

        print(f"\nСтатистика производительности:")
        print(f"  Всего сделок: {self.performance_stats['total_trades']}")
        print(f"  Выигрышных: {self.performance_stats['winning_trades']}")

        if self.performance_stats['total_trades'] > 0:
            win_rate = (self.performance_stats['winning_trades'] /
                        self.performance_stats['total_trades'] * 100)
            print(f"  Win Rate: {win_rate:.1f}%")

        print(f"  Общий P&L: ${self.performance_stats['total_pnl']:.2f}")
        print(f"  Изменений режима: {self.performance_stats['regime_changes']}")

        print(f"\nЭкспозиция: ${total_exposure:.2f} "
              f"({total_exposure / self.config['initial_capital'] * 100:.1f}% от капитала)")

        # Сохранение состояния
        self.save_state()

    def save_state(self):
        """Сохранение состояния системы"""

        state = {
            'current_regime': self.current_regime,
            'regime_confidence': self.regime_confidence,
            'performance_stats': self.performance_stats,
            'active_positions_count': len(self.active_positions),
            'timestamp': datetime.now().isoformat()
        }

        state_path = os.path.join(self.config['data_path'], 'bot_state.json')

        try:
            with open(state_path, 'w') as f:
                json.dump(state, f, indent=2, default=str)
        except:
            pass

    def stop(self):
        """Остановка бота"""

        print("\nОстановка бота...")
        self.is_running = False

        # Закрытие всех позиций
        if self.active_positions:
            print("Закрытие оставшихся позиций...")
            # В реальной системе здесь будет обращение к брокеру

        # Сохранение финального отчета
        self.generate_final_report()

    def generate_final_report(self):
        """Генерация финального отчета"""

        report_path = os.path.join(self.config['data_path'], 'trading_report.json')

        report = {
            'summary': self.performance_stats,
            'trade_history': self.trade_history[-100:],  # Последние 100 сделок
            'final_capital': self.config['initial_capital'] + self.performance_stats['total_pnl'],
            'start_time': self.trade_history[0]['open_time'] if self.trade_history else None,
            'end_time': datetime.now(),
            'total_hours': None
        }

        if report['start_time']:
            report['total_hours'] = (report['end_time'] - report['start_time']).total_seconds() / 3600

        try:
            with open(report_path, 'w') as f:
                json.dump(report, f, indent=2, default=str)
            print(f"Отчет сохранен: {report_path}")
        except Exception as e:
            print(f"Ошибка сохранения отчета: {e}")


def main():
    """Главная функция запуска"""

    print("АДАПТИВНАЯ ТОРГОВАЯ СИСТЕМА ДЛЯ МЕТАЛЛОВ")
    print("=" * 60)
    print("Стратегия переключения между режимами:")
    print("1. Mean Reversion + Kelly портфель")
    print("2. Trend Following")
    print("3. Вне рынка при Random Walk")
    print("=" * 60)

    # Конфигурация
    config = {
        'update_interval': 60,  # Обновление каждые 60 секунд
        'metals_to_trade': ['XAUUSD', 'XAGUSD'],  # Можно добавить 'XPTUSD'
        'initial_capital': 50000,
        'max_drawdown': 0.20,
        'data_path': r"D:\TradingSystems\OLTP\historicalData\metals"
    }

    # Создание и запуск бота
    bot = AdaptiveTradingBot(config)

    # Запуск в отдельном потоке
    bot_thread = threading.Thread(target=bot.monitor_markets)
    bot_thread.daemon = True
    bot_thread.start()

    try:
        # Ожидание команд пользователя
        while True:
            command = input("\nВведите команду (status, stop, exit): ").strip().lower()

            if command == 'status':
                # Вывод текущего статуса
                print(f"\nТекущий режим: {bot.current_regime}")
                print(f"Активных позиций: {len(bot.active_positions)}")
                print(f"Общий P&L: ${bot.performance_stats['total_pnl']:.2f}")

            elif command in ['stop', 'exit']:
                bot.stop()
                print("Бот остановлен")
                break

            time.sleep(1)

    except KeyboardInterrupt:
        print("\n\nОстановка по Ctrl+C...")
        bot.stop()

    except Exception as e:
        print(f"Ошибка: {e}")
        bot.stop()


if __name__ == "__main__":
    main()