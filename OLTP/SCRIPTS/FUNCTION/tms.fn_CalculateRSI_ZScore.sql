USE cTrader
GO

PRINT 'Creating function fn_CalculateRSI_ZScore...'

-- Удаляем функцию если существует
IF OBJECT_ID('tms.fn_CalculateRSI_ZScore', 'FN') IS NOT NULL
    DROP FUNCTION tms.fn_CalculateRSI_ZScore
GO

-- Создаем функцию для расчета Z-Score RSI
CREATE FUNCTION tms.fn_CalculateRSI_ZScore (
    @TickerJID INT,
    @TimeFrameID INT,
    @CurrentRSI DECIMAL(8,4),
    @LookbackPeriod INT = 100  -- Количество баров для расчета статистики
)
RETURNS DECIMAL(8,4)
AS
BEGIN
    DECLARE @ZScore DECIMAL(8,4);
    DECLARE @Mean DECIMAL(8,4);
    DECLARE @StdDev DECIMAL(8,4);
    DECLARE @Count INT;
    
    -- Получаем статистику RSI за последние N баров
    SELECT 
        @Mean = AVG(CAST(RSI_14 AS DECIMAL(8,4))),
        @StdDev = STDEV(CAST(RSI_14 AS DECIMAL(8,4))),
        @Count = COUNT(*)
    FROM tms.Indicators_Momentum
    WHERE TickerJID = @TickerJID
      AND TimeFrameID = @TimeFrameID
      AND RSI_14 IS NOT NULL
      AND BarTime < (
          SELECT MAX(BarTime) 
          FROM tms.Indicators_Momentum 
          WHERE TickerJID = @TickerJID 
            AND TimeFrameID = @TimeFrameID
      )
      AND BarTime >= DATEADD(
          MINUTE, 
          -(@LookbackPeriod * (
              SELECT minutes 
              FROM tms.TimeFrames 
              WHERE ID = @TimeFrameID
          )), 
          GETUTCDATE()
      );
    
    -- Если недостаточно данных или стандартное отклонение = 0, возвращаем NULL
    IF @Count < 20 OR @StdDev = 0
    BEGIN
        RETURN NULL;
    END
    
    -- Рассчитываем Z-Score: (значение - среднее) / стандартное отклонение
    SET @ZScore = (@CurrentRSI - @Mean) / @StdDev;
    
    RETURN @ZScore;
END
GO

PRINT 'Function tms.fn_CalculateRSI_ZScore created successfully!';
GO