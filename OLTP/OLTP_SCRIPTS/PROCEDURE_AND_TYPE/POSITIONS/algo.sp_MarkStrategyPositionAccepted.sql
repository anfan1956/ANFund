use cTrader 
go

if OBJECT_ID('algo.sp_MarkStrategyPositionAccepted') is not null drop proc algo.sp_MarkStrategyPositionAccepted
go

CREATE PROCEDURE algo.sp_MarkStrategyPositionAccepted
    @trade_uuid NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Проверяем, существует ли запись
    IF NOT EXISTS (SELECT 1 FROM algo.strategies_positions WHERE trade_uuid = @trade_uuid)
    BEGIN;
        -- Это ОШИБКА - запись должна быть создана sp_CreateSignal
        THROW 51000, 'Strategy position record not found. It should be created by sp_CreateSignal.', 1;
    END
    
    -- Обновляем createdTime, если он NULL
    UPDATE algo.strategies_positions
    SET createdTime = GETUTCDATE()
    WHERE trade_uuid = @trade_uuid
        AND createdTime IS NULL;
    
    -- Если createdTime уже был установлен, ничего не делаем (идемпотентно)
END


select top 5 * from algo.strategies_positions order by createdTime desc

