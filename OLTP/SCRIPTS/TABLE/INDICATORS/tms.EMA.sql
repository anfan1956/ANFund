USE [cTrader]
GO

-- Сначала проверяем, существует ли таблица, и удаляем если есть
IF OBJECT_ID('tms.EMA', 'U') IS NOT NULL
BEGIN
    PRINT 'Dropping existing table tms.EMA...';
    
    -- Сначала удаляем foreign keys
    DECLARE @sql NVARCHAR(MAX);
    
    -- Генерируем SQL для удаления всех FK
    SELECT @sql = STRING_AGG(
        'ALTER TABLE tms.EMA DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';', 
        CHAR(13)
    )
    FROM sys.foreign_keys fk
    WHERE fk.parent_object_id = OBJECT_ID('tms.EMA');
    
    IF @sql IS NOT NULL
    BEGIN
        EXEC sp_executesql @sql;
        PRINT 'Dropped foreign keys';
    END
    
    DROP TABLE tms.EMA;
END
GO

-- Создаем таблицу для EMA значений
CREATE TABLE tms.EMA
(
    ID BIGINT IDENTITY(1,1) PRIMARY KEY,          -- Используем BIGINT для совместимости
    BarID BIGINT NOT NULL,                        -- FK к основному бару (BIGINT!)
    TickerJID INT NOT NULL,                       -- Дублируем для производительности
    BarTime DATETIME NOT NULL,                    -- Время бара
    TimeFrameID INT NOT NULL,                     -- Таймфрейм
    
    -- Экспоненциальные скользящие средние (EMA)
    EMA_5_SHORT DECIMAL(18,8) NULL,               -- EMA 5 - очень краткосрочный тренд
    EMA_9_MACD_SIGNAL DECIMAL(18,8) NULL,         -- EMA 9 - сигнальная линия MACD
    EMA_12_MACD_FAST DECIMAL(18,8) NULL,          -- EMA 12 - быстрая линия MACD
    EMA_20_SHORT DECIMAL(18,8) NULL,              -- EMA 20 - краткосрочный тренд
    EMA_26_MACD_SLOW DECIMAL(18,8) NULL,          -- EMA 26 - медленная линия MACD
    EMA_50_MEDIUM DECIMAL(18,8) NULL,             -- EMA 50 - среднесрочный тренд
    EMA_100_LONG DECIMAL(18,8) NULL,              -- EMA 100 - долгосрочный тренд
    EMA_200_LONG DECIMAL(18,8) NULL,              -- EMA 200 - основной тренд
    
    -- EMA на основе чисел Фибоначчи
    EMA_21_FIBO DECIMAL(18,8) NULL,               -- EMA 21 - Фибоначчи уровень
    EMA_55_FIBO DECIMAL(18,8) NULL,               -- EMA 55 - Фибоначчи уровень
    EMA_144_FIBO DECIMAL(18,8) NULL,              -- EMA 144 - Фибоначчи уровень
    EMA_233_FIBO DECIMAL(18,8) NULL,              -- EMA 233 - Фибоначчи уровень
    
    CreatedDate DATETIME DEFAULT GETDATE(),
    
    -- Правильные ограничения внешних ключей
    CONSTRAINT FK_EMA_Bars_BarID FOREIGN KEY (BarID) 
        REFERENCES tms.Bars(ID) ON DELETE CASCADE,
    
    -- Ссылка на мастер-таблицу тикеров
    CONSTRAINT FK_EMA_AssetMaster_TickerJID FOREIGN KEY (TickerJID) 
        REFERENCES ref.assetMasterTable(ID),
    
    -- Проверочные ограничения для timeframeID
    CONSTRAINT CHK_EMA_TimeFrameID CHECK (TimeFrameID BETWEEN 1 AND 9),
    
    -- Уникальность: один бар - одна запись EMA
    CONSTRAINT UQ_EMA_Bar UNIQUE (BarID)
);
GO

PRINT 'Table tms.EMA created successfully!';
GO

-- Создаем оптимизированные индексы для производительности
PRINT 'Creating indexes for tms.EMA...';

-- Основной индекс для запросов по тикеру и времени
CREATE INDEX IX_EMA_Ticker_TimeFrame_Time 
ON tms.EMA(TickerJID, TimeFrameID, BarTime DESC)
INCLUDE (EMA_5_SHORT, EMA_20_SHORT, EMA_50_MEDIUM, EMA_200_LONG);
GO

-- Индекс для запросов по времени
CREATE INDEX IX_EMA_BarTime_Desc 
ON tms.EMA(BarTime DESC)
INCLUDE (TickerJID, TimeFrameID);
GO

-- Композитный индекс для аналитических запросов
CREATE INDEX IX_EMA_Ticker_TimeFrame_Composite 
ON tms.EMA(TickerJID, TimeFrameID, BarTime DESC)
INCLUDE (EMA_12_MACD_FAST, EMA_26_MACD_SLOW, EMA_9_MACD_SIGNAL);
GO

-- Индекс для запросов по внешнему ключу
CREATE INDEX IX_EMA_BarID 
ON tms.EMA(BarID)
INCLUDE (TickerJID, TimeFrameID, BarTime);
GO

PRINT 'All indexes created successfully!';
GO

-- Проверяем структуру таблицы
PRINT '=== TABLE STRUCTURE ===';
SELECT 
    c.column_id,
    c.name as ColumnName,
    TYPE_NAME(c.user_type_id) as DataType,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('tms.EMA')
ORDER BY c.column_id;
GO

-- Быстрая проверка создания таблицы
PRINT '=== QUICK VALIDATION ===';
SELECT 
    'Table exists' as CheckItem,
    CASE WHEN OBJECT_ID('tms.EMA', 'U') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END as Status
UNION ALL
SELECT 
    'Primary key exists',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID('tms.EMA') AND is_primary_key = 1
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'Foreign key to Bars exists',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        WHERE fk.parent_object_id = OBJECT_ID('tms.EMA')
          AND fk.name = 'FK_EMA_Bars_BarID'
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'Foreign key to assetMasterTable exists',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        WHERE fk.parent_object_id = OBJECT_ID('tms.EMA')
          AND fk.name = 'FK_EMA_AssetMaster_TickerJID'
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'Check constraint exists',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.check_constraints 
        WHERE parent_object_id = OBJECT_ID('tms.EMA')
          AND name = 'CHK_EMA_TimeFrameID'
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'Unique constraint exists',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.key_constraints 
        WHERE parent_object_id = OBJECT_ID('tms.EMA')
          AND name = 'UQ_EMA_Bar'
          AND type = 'UQ'
    ) THEN 'PASS' ELSE 'FAIL' END;
GO