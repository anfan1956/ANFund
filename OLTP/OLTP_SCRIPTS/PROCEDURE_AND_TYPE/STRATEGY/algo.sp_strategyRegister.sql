

if OBJECT_ID('algo.sp_strategyRegister') is not null drop proc algo.sp_strategyRegister
go

create PROCEDURE algo.sp_strategyRegister 
    @configID int  
AS 
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Получаем конфигурацию
    SELECT 
        sc.config_id as configID,
        sc.ticker,
        sc.ticker_jid,
        sc.timeframe_signal_id,
        sc.timeframe_confirmation_id,
        sc.timeframe_trend_id,
        sc.open_volume,
        sc.trading_close_utc,
        sc.trading_start_utc,
        sc.broker_id,
        sc.platform_id
    INTO #TempConfig
    FROM algo.fn_GetStrategyConfiguration(@configID) sc;
    
    -- 2. Если конфигурация найдена
    IF EXISTS (SELECT 1 FROM #TempConfig)
    BEGIN
        -- Создаём таблицу для реальной регистрации
        CREATE TABLE #RealRegistration (
            configInstanceGUID UNIQUEIDENTIFIER,
            configID INT
        );
        
        -- Регистрируем в трекере
        INSERT INTO algo.strategyTracker (configID)
        OUTPUT inserted.configInstanceGUID, inserted.configID
        INTO #RealRegistration
        SELECT configID FROM #TempConfig;
        
        -- Объединяем данные
        SELECT 
            tc.configID,
            rr.configInstanceGUID,
            tc.ticker,
            tc.ticker_jid,
            tc.timeframe_signal_id,
            tc.timeframe_confirmation_id,
            tc.timeframe_trend_id,
            tc.open_volume,
            tc.trading_close_utc,
            tc.trading_start_utc,
            tc.broker_id,
            tc.platform_id
        INTO #FinalResult
        FROM #TempConfig tc
        INNER JOIN #RealRegistration rr ON tc.configID = rr.configID;
        
        -- Возвращаем JSON
        SELECT (
            SELECT * FROM #FinalResult
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS registration;
        
        -- Очистка
        DROP TABLE #TempConfig;
        DROP TABLE #RealRegistration;
        DROP TABLE #FinalResult;
    END
    ELSE
    BEGIN
        SELECT '{"error": "Configuration not found"}' AS registration;
    END
END;
GO
declare @configID int =3;
EXEC algo.sp_strategyRegister @configID 