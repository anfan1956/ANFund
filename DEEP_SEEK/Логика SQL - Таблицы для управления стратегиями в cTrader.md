## Таблицы для управления стратегиями в cTrader (на основе DATABASE_OBJECTS_SCHEMAS.csv)

### 1. Создание стратегий
**Таблицы:**
- `algo.strategy_classes` - классы стратегий (шаблоны)
  - `ID` (PK), `class_name`, `class_code`, `category`
- `algo.strategies` - сами стратегии
  - `ID` (PK), `strategy_name`, `strategy_code`, `strategy_class_id` (FK → strategy_classes.ID)
- `algo.ParameterSets` - параметры стратегий
  - `Id` (PK), `ParameterSetJson`, `strategy_id` (FK → strategies.ID)
- `algo.ConfigurationSets` - конфигурации стратегий
  - `Id` (PK), `ParameterSetId` (FK → ParameterSets.Id), `ParameterValuesJson`

**Логика создания:**
1. Выбирается класс стратегии из `strategy_classes`
2. Создается запись в `strategies` с ссылкой на класс
3. Создаются параметры в `ParameterSets`
4. Создаются конфигурации в `ConfigurationSets`

### 2. Модификация стратегий
**Таблицы:**
- `algo.ParameterSets` - изменение параметров через JSON
- `algo.ConfigurationSets` - изменение конфигураций
- `algo.strategies` - обновление `modified_date`

### 3. Запуск стратегий
**Таблицы:**
- `algo.strategyTracker` - трекер запущенных стратегий
  - `ID` (PK), `configID` (FK → ConfigurationSets.Id)
  - `timeStarted`, `modified`, `timeClosed` (NULL = запущена)
- `algo.tradingSignals` - сигналы для исполнения
  - `signalID` (PK), `assetID`, `direction`, `volume`, `status`
  - `status` = 'PENDING' при запуске

**Логика запуска:**
1. Запись в `strategyTracker` с `timeStarted` = текущее время
2. `timeClosed` = NULL (стратегия активна)
3. Генерация начальных сигналов в `tradingSignals` со статусом 'PENDING'

### 4. Мониторинг стратегий
**Основные таблицы:**
- `algo.strategyTracker` - проверка `modified` и `timeClosed`
- `algo.strategiesDashboard_v` (VIEW) - дашборд стратегий
  - `configID`, `strategy_code`, `strategy_name`
  - `lastHeartbeat`, `minutesSinceHeartbeat`
- `algo.strategiesRunning_v` (VIEW) - запущенные стратегии
  - `configID`, `strategy`, `ticker`, `tradeID`, `openTime`
- `algo.tradeLog` - лог торговых событий
  - `tradeTypeID`, `tradeEventTypeID`, `direction`, `volume`, `price`
- `fin.strategies_results` (VIEW) - финансовые результаты

**Процедуры мониторинга:**
1. Проверка `strategyTracker.modified` - если давно не обновлялась, стратегия "зависла"
2. Анализ `strategiesDashboard_v.minutesSinceHeartbeat` > порога → тревога
3. Мониторинг `tradingSignals.executionTime` - задержки исполнения

### 5. Остановка стратегий
**Таблицы:**
- `algo.strategy_termination_queue` - очередь на остановку
  - `id` (PK), `config_id` (FK → ConfigurationSets.Id)
  - `terminate` (bit), `requested_at`, `terminated_at`
- `algo.strategyTracker` - установка `timeClosed`
- `algo.tradingSignals` - отмена pending сигналов (`status` = 'CANCELLED')

**Логика остановки:**
1. Добавление записи в `strategy_termination_queue`
2. Обновление `strategyTracker.timeClosed` = текущее время
3. Отмена pending сигналов в `tradingSignals`
4. Обновление `strategy_termination_queue.terminated_at`

### 6. Процедуры (логика работы)
**Запуск стратегии:**
```sql
-- 1. Проверить существование конфигурации (ConfigurationSets)
-- 2. Проверить, не запущена ли уже (strategyTracker.timeClosed IS NULL)
-- 3. Вставить запись в strategyTracker
-- 4. Создать начальные сигналы в tradingSignals
```

**Мониторинг heartbeat:**
```sql
-- 1. Обновить strategyTracker.modified = GETUTCDATE()
-- 2. Проверить strategiesDashboard_v.minutesSinceHeartbeat
-- 3. Если > порога, записать в логи (logsJob_processIndicators)
```

**Остановка стратегии:**
```sql
-- 1. Добавить запись в strategy_termination_queue
-- 2. Обновить strategyTracker.timeClosed = GETUTCDATE()
-- 3. Обновить tradingSignals.status = 'CANCELLED' WHERE status = 'PENDING'
-- 4. Записать событие в tradeLog
```

**Получение конфигурации (через функции):**
- `fn_GetStrategyConfiguration` - возвращает конфигурационные параметры
- `getStrategyParameters` - возвращает параметры стратегии

### 7. Ключевые связи для целостности
1. `strategies.strategy_class_id` → `strategy_classes.ID`
2. `ConfigurationSets.ParameterSetId` → `ParameterSets.Id`
3. `strategyTracker.configID` → `ConfigurationSets.Id`
4. `strategy_termination_queue.config_id` → `ConfigurationSets.Id`
5. `strategies_positions.strategy_configuration_id` → `ConfigurationSets.Id`

Все взаимодействия происходят через VIEW и функции, прямой SQL-код не используется (согласно правилу 9).