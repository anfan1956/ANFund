-- Drop existing tables if they exist
if OBJECT_ID('tms.bars') is not null drop table tms.bars
if OBJECT_ID('tms.sources') is not null drop table tms.sources
if OBJECT_ID('tms.timeframes') is not null drop table tms.timeframes


CREATE TABLE tms.timeframes (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    timeframeCode VARCHAR(10) NOT NULL UNIQUE, -- 'M1', 'M5', 'H1', 'D1' и т.д.
    timeframeName NVARCHAR(50) NOT NULL, -- '1 Minute', '5 Minutes', '1 Hour', '1 Day'
    minutes INT NOT NULL -- Количество минут в таймфрейме
);
GO

create table tms.sources
(
    ID int IDENTITY(1,1) PRIMARY KEY,
    sourceName NVARCHAR(50) not NULL,
    sourceURL NVARCHAR(255) NULL
)
go

CREATE TABLE tms.bars (
    ID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TickerJID INT NOT NULL CONSTRAINT fk_bars_tickers FOREIGN KEY REFERENCES ref.assetMasterTable(ID), 
    barTime DATETIME NOT NULL,
    timeframeID INT NOT NULL CONSTRAINT fk_bars_timeFrames FOREIGN KEY REFERENCES tms.timeFrames(ID),
    openValue FLOAT NOT NULL, 
    closeValue FLOAT NOT NULL,
    highValue FLOAT NOT NULL,
    lowValue FLOAT NOT NULL, 
    sourceID INT NOT NULL CONSTRAINT fk_bars_sources FOREIGN KEY REFERENCES tms.sources(ID),
    CONSTRAINT uq_bars_ticker_time_timeframe UNIQUE (TickerJID, barTime, timeframeid, sourceID)
);
GO


-- Create index for performance (with proper IF EXISTS check)
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_bars_ticker_time' AND object_id = OBJECT_ID('tms.bars'))
BEGIN
    DROP INDEX idx_bars_ticker_time ON tms.bars
END
go

CREATE INDEX idx_bars_ticker_time ON tms.bars (TickerJID, timeFrameID, barTime);
go

-- Insert source
-- Заполняем базовые таймфреймы
INSERT INTO tms.timeframes (timeframeCode, timeframeName, minutes) VALUES
('M1',   '1 Minute',    1),
('M5',   '5 Minutes',   5),
('M15',  '15 Minutes',  15),
('M30',  '30 Minutes',  30),
('H1',   '1 Hour',      60),
('H4',   '4 Hours',     240),
('D1',   '1 Day',       1440),
('W1',   '1 Week',      10080),
('MN1',  '1 Month',     43200);
GO


insert into tms.sources (sourceName) values 
('Peperstone_cTrader');
GO
-- 1. Добавить колонку для MA50
/*
ALTER TABLE tms.bars 
ADD MA200 FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA500 FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA20 FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA30 FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA5 FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA21_FIB FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA55_FIB FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA144_FIB FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA233_FIB FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA195_NYSE FLOAT NULL;

ALTER TABLE tms.bars 
ADD MA390_NYSE FLOAT NULL;

-- 2. Создать индекс для производительности
CREATE INDEX idx_bars_ticker_timeframe_time 
ON tms.bars (TickerJID, timeframeID, barTime) 
INCLUDE (closeValue);
GO
*/


;WITH MA50_CTE AS (
    SELECT 
        ID,
        TickerJID,
        barTime,
        timeframeID,
        sourceID,
        closeValue,
        MA50,
        -- Рассчитываем MA50 для каждой строки
        AVG(closeValue) OVER (
            PARTITION BY TickerJID, timeframeID, sourceID
            ORDER BY barTime
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ) AS calculated_MA50
    FROM tms.bars
)
UPDATE MA50_CTE
SET MA50 = calculated_MA50
WHERE calculated_MA50 IS NOT NULL;
GO

-- Создать триггер для автоматического расчета MA50
CREATE OR ALTER TRIGGER tms.trg_bars_CalculateMA50
ON tms.bars
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Обновить MA50 для вставленных/обновленных строк
    UPDATE b
    SET MA50 = ma.calculated_MA50
    FROM tms.bars b
    INNER JOIN inserted i ON b.ID = i.ID
    CROSS APPLY (
        SELECT AVG(b2.closeValue) AS calculated_MA50
        FROM tms.bars b2
        WHERE b2.TickerJID = b.TickerJID
          AND b2.timeframeID = b.timeframeID
          AND b2.sourceID = b.sourceID
          AND b2.barTime <= b.barTime
          AND b2.barTime > DATEADD(
                MINUTE, 
                CASE WHEN b.timeframeID = 1 THEN -50
                     WHEN b.timeframeID = 2 THEN -250
                     WHEN b.timeframeID = 3 THEN -750
                     WHEN b.timeframeID = 4 THEN -3000
                     ELSE -50 END, 
                b.barTime
          )
    ) ma;
END;
GO


CREATE OR ALTER TRIGGER tms.trg_bars_CalculateAllMA_Optimized
ON tms.bars
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Используем CTE для более эффективного расчета
    WITH RankedBars AS (
        SELECT 
            i.ID,
            b2.closeValue,
            ROW_NUMBER() OVER (
                PARTITION BY i.ID
                ORDER BY b2.barTime DESC
            ) AS rn
        FROM inserted i
        INNER JOIN tms.bars b2 ON 
            b2.TickerJID = i.TickerJID
            AND b2.timeframeID = i.timeframeID
            AND b2.sourceID = i.sourceID
            AND b2.barTime <= i.barTime
    ),
    AggregatedMA AS (
        SELECT 
            ID,
            -- Рассчитываем все MA за один проход
            AVG(CASE WHEN rn <= 5 THEN closeValue END) AS MA5,
            AVG(CASE WHEN rn <= 20 THEN closeValue END) AS MA20,
            AVG(CASE WHEN rn <= 30 THEN closeValue END) AS MA30,
            AVG(CASE WHEN rn <= 50 THEN closeValue END) AS MA50,
            AVG(CASE WHEN rn <= 100 THEN closeValue END) AS MA100,
            AVG(CASE WHEN rn <= 200 THEN closeValue END) AS MA200,
            AVG(CASE WHEN rn <= 500 THEN closeValue END) AS MA500
        FROM RankedBars
        GROUP BY ID
    )
    -- Обновляем таблицу
    UPDATE b
    SET 
        b.MA5 = a.MA5,
        b.MA20 = a.MA20,
        b.MA30 = a.MA30,
        b.MA50 = a.MA50,
        b.MA100 = a.MA100,
        b.MA200 = a.MA200,
        b.MA500 = a.MA500
    FROM tms.bars b
    INNER JOIN AggregatedMA a ON b.ID = a.ID;
END;
GO



-- Заполнение исторических данных для всех MA
/*
UPDATE b
SET 
    MA5 = ma.MA5,
    MA20 = ma.MA20,
    MA30 = ma.MA30,
    MA50 = ma.MA50,
    MA100 = ma.MA100,
    MA200 = ma.MA200,
    MA500 = ma.MA500
FROM tms.bars b
CROSS APPLY (
    SELECT 
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 5 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA5,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 20 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA20,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 30 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA30,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 50 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA50,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 100 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA100,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 200 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA200,
        
        (SELECT AVG(closeValue) 
         FROM (SELECT TOP 500 closeValue 
               FROM tms.bars b2 
               WHERE b2.TickerJID = b.TickerJID
                 AND b2.timeframeID = b.timeframeID
                 AND b2.sourceID = b.sourceID
                 AND b2.barTime <= b.barTime
               ORDER BY b2.barTime DESC) t) AS MA500
) ma
WHERE b.MA5 IS NULL 
   OR b.MA20 IS NULL 
   OR b.MA30 IS NULL 
   OR b.MA50 IS NULL 
   OR b.MA100 IS NULL 
   OR b.MA200 IS NULL 
   OR b.MA500 IS NULL;
GO
*/


select * from tms.bars order by barTime desc;