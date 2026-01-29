USE cTrader
GO

PRINT 'Creating function fn_CheckBarExists...'

-- Удаляем функцию если существует
IF OBJECT_ID('tms.fn_CheckBarExists', 'FN') IS NOT NULL
    DROP FUNCTION tms.fn_CheckBarExists
GO

-- Создаем функцию для проверки существования бара
CREATE FUNCTION tms.fn_CheckBarExists (
    @TickerJID INT,
    @BarTime DATETIME2(3),
    @TimeFrameID INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @Exists BIT = 0;
    
    -- Проверяем существование бара в таблице Bars
    IF EXISTS (
        SELECT 1 
        FROM tms.Bars 
        WHERE TickerJID = @TickerJID 
          AND BarTime = @BarTime 
          AND TimeFrameID = @TimeFrameID
    )
    BEGIN
        SET @Exists = 1;
    END
    
    RETURN @Exists;
END
GO

PRINT 'Function tms.fn_CheckBarExists created successfully!';
GO