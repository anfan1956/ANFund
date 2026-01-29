Понял. Распишу алгоритм последовательно, как будет работать CLR:

## **Последовательность расчетов в одном проходе:**

### **1. Сбор исходных данных:**
- Читаем бары (`tms.bars`) с фильтрами
- Для каждого бара: High, Low, Close, Volume
- Сортируем по TickerJID, TimeFrameID, BarTime (ASC)

### **2. Расчет компонентов по группам (TickerJID + TimeFrameID):**

#### **A. Волатильность:**
- **True Range** для каждого бара: `MAX(High-Low, ABS(High-PrevClose), ABS(Low-PrevClose))`
- **ATR(14)**: Скользящее среднее True Range за 14 периодов
- **ATR %**: `(ATR / Close) * 100`
- **Historical Volatility(20)**: Стандартное отклонение лог-доходностей за 20 периодов, годовое

#### **B. Тренд (ADX система):**
- **+DM** и **-DM** (Directional Movement)
- **TR** (True Range) - уже есть
- **+DI(14)** и **-DI(14)**: Сглаженные +DM и -DM, деленные на ATR(14)
- **DX**: `ABS(+DI - -DI) / (+DI + -DI) * 100`
- **ADX(14)**: Сглаженное среднее DX за 14 периодов

#### **C. Паттерны свечей:**
- **Inside Bar**: `High <= PrevHigh AND Low >= PrevLow`
- **Outside Bar**: `High > PrevHigh AND Low < PrevLow`
- **Pin Bar**: `(High - MAX(Open, Close)) > 2 * ABS(Close - Open) OR (MIN(Open, Close) - Low) > 2 * ABS(Close - Open)`

#### **D. Стоп-лосс уровни (Chandelier Exit):**
- **Highest High(22)** для long позиций
- **Lowest Low(22)** для short позиций
- **Chandelier Exit Long**: `HighestHigh(22) - ATR(22) * 3`
- **Chandelier Exit Short**: `LowestLow(22) + ATR(22) * 3`

### **3. Определение режима рынка:**

#### **Шаг 1: Расчет скоринга:**
- **Trend Score**: На основе ADX и DI (`0-1`, где 1 = сильный тренд)
- **Volatility Score**: На основе ATR% и HistVol (`0-1`, где 1 = высокая волатильность)
- **Pattern Score**: На основе свечных паттернов

#### **Шаг 2: Определение Primary Regime:**
1. Если `VolatilityScore > 0.7` → **HIGH_VOL** (4)
2. Если `VolatilityScore < 0.3` → **LOW_VOL** (5)
3. Если `TrendScore > 0.7`:
   - Если `+DI > -DI` → **TREND_UP** (1)
   - Иначе → **TREND_DOWN** (2)
4. Если `TrendScore < 0.4` → **RANGING** (3)
5. По умолчанию → **RANGING** (3)

#### **Шаг 3: Дополнительные метрики:**
- **Regime Confidence**: Уверенность в текущем режиме
- **Regime Change Flag**: Изменился ли режим с предыдущего бара
- **Overall Score**: Комбинированный скор всех компонентов

### **4. Возврат результата:**
Возвращаем одну таблицу со всеми полями для всех 5 таблиц, которые ты создал.

## **Преимущества подхода:**
- **Один проход** по данным вместо 5 отдельных
- **Сохранение контекста** по группам
- **Минимальные обращения** к БД
- **Согласованность данных** (все рассчитывается на одних и тех же барах)

**Верно? Тогда начну писать код.**