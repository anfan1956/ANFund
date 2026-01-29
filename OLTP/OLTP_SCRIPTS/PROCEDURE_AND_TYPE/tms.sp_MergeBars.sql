-- ============================================
-- 2. ТАБЛИЧНЫЙ ТИП ДАННЫХ И ПРОЦЕДУРЫ
-- ============================================

-- Удаляем если существуют (в правильном порядке)
IF OBJECT_ID('tms.sp_MergeBars', 'P') IS NOT NULL
    DROP PROCEDURE tms.sp_MergeBars;
GO

IF TYPE_ID('tms.BarsTableType') IS NOT NULL
    DROP TYPE tms.BarsTableType;
GO

-- Создаем табличный тип данных
CREATE TYPE tms.BarsTableType AS TABLE
(
    TickerJID INT NOT NULL,
    barTime DATETIME NOT NULL,
    timeframeID INT NOT NULL,
    openValue FLOAT NOT NULL,
    closeValue FLOAT NOT NULL,
    highValue FLOAT NOT NULL,
    lowValue FLOAT NOT NULL,
    sourceID INT NOT NULL
);
GO


CREATE PROCEDURE [tms].[sp_MergeBars]
    @bars tms.BarsTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Начинаем транзакцию с уровнем изоляции READ COMMITTED
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    DECLARE @TransactionStarted BIT = 0;
    
    -- Объявляем табличную переменную для результата
    DECLARE @Result TABLE (
        TickerJID INT,
        timeframeID INT,
        LastBarTime DATETIME
    );
    
    BEGIN TRY
        -- Если еще нет активной транзакции, начинаем свою
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @TransactionStarted = 1;
        END
        
        -- Временная таблица для хранения обработанных TickerJID и timeframeID
        DECLARE @ProcessedSymbols TABLE (
            TickerJID INT,
            timeframeID INT,
            PRIMARY KEY (TickerJID, timeframeID)
        );
        
        -- Собираем уникальные комбинации TickerJID + timeframeID из входящих данных
        INSERT INTO @ProcessedSymbols (TickerJID, timeframeID)
        SELECT DISTINCT TickerJID, timeframeID
        FROM @bars;
        
        -- Используем MERGE для вставки или обновления
        MERGE tms.bars AS target
        USING @bars AS source
        ON (target.TickerJID = source.TickerJID 
            AND target.barTime = source.barTime 
            AND target.timeframeID = source.timeframeID
            AND target.sourceID = source.sourceID)
         
        -- Если бар не существует, вставляем новый
        WHEN NOT MATCHED THEN
            INSERT (TickerJID, barTime, timeframeID, openValue, closeValue, highValue, lowValue, sourceID)
            VALUES (source.TickerJID, source.barTime, source.timeframeID, 
                    source.openValue, source.closeValue, source.highValue, source.lowValue, source.sourceID);
        
        -- Сохраняем результат во временную таблицу ПЕРЕД коммитом
        INSERT INTO @Result (TickerJID, timeframeID, LastBarTime)
        SELECT 
            b.TickerJID,
            b.timeframeID,
            MAX(b.barTime) AS LastBarTime
        FROM tms.bars b
        INNER JOIN @ProcessedSymbols ps ON b.TickerJID = ps.TickerJID AND b.timeframeID = ps.timeframeID
        GROUP BY b.TickerJID, b.timeframeID;
        
        -- Фиксируем транзакцию, если мы ее начали
        IF @TransactionStarted = 1
            COMMIT TRANSACTION;
        
        -- Возвращаем результат только если транзакция успешно закоммичена
        SELECT 
            TickerJID,
            timeframeID,
            LastBarTime
        FROM @Result
        ORDER BY TickerJID, timeframeID;
        
    END TRY
    BEGIN CATCH
        -- Откатываем транзакцию, если мы ее начали
        IF @TransactionStarted = 1 AND @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Пробрасываем ошибку дальше - процедура ничего не вернет
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN; -- Важно: прерываем выполнение
    END CATCH
END
go


-- Предыдущий вариант
-- Основная процедура для слияния баров
/**
CREATE PROCEDURE tms.sp_MergeBars
    @bars tms.BarsTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @rowCount INT;
    
    -- Используем MERGE для вставки или обновления
    MERGE tms.bars AS target
    USING @bars AS source
    ON (target.TickerJID = source.TickerJID 
        AND target.barTime = source.barTime 
        AND target.timeframeID = source.timeframeID
        AND target.sourceID = source.sourceID)
    
    -- Если бар существует, обновляем значения
    -- WHEN MATCHED THEN
    --     UPDATE SET 
    --         openValue = source.openValue,
    --         closeValue = source.closeValue,
    --         highValue = source.highValue,
    --         lowValue = source.lowValue
    
    -- Если бар не существует, вставляем новый
    WHEN NOT MATCHED THEN
        INSERT (TickerJID, barTime, timeframeID, openValue, closeValue, highValue, lowValue, sourceID)
        VALUES (source.TickerJID, source.barTime, source.timeframeID, 
                source.openValue, source.closeValue, source.highValue, source.lowValue, source.sourceID);
    
    SET @rowCount = @@ROWCOUNT;
    
    RETURN @rowCount;
END
GO
*/
