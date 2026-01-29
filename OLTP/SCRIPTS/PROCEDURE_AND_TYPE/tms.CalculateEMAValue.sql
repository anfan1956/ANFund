USE [cTrader]
GO

-- =============================================
-- Author: AI Assistant
-- Create date: 2024
-- Description: Функция для расчета EMA значения
-- =============================================
CREATE OR ALTER FUNCTION tms.CalculateEMAValue
(
    @TickerJID INT,
    @TimeFrameID INT,
    @CurrentBarTime DATETIME,
    @Period INT,
    @CurrentClose DECIMAL(18,8)
)
RETURNS DECIMAL(18,8)
AS
BEGIN
    DECLARE @Result DECIMAL(18,8);
    
    IF @Period <= 0
        RETURN NULL;
    
    -- Получаем предыдущее значение EMA
    SELECT TOP 1 @Result = 
        CASE @Period
            WHEN 5 THEN EMA_5_SHORT
            WHEN 9 THEN EMA_9_MACD_SIGNAL
            WHEN 12 THEN EMA_12_MACD_FAST
            WHEN 20 THEN EMA_20_SHORT
            WHEN 21 THEN EMA_21_FIBO
            WHEN 26 THEN EMA_26_MACD_SLOW
            WHEN 50 THEN EMA_50_MEDIUM
            WHEN 55 THEN EMA_55_FIBO
            WHEN 100 THEN EMA_100_LONG
            WHEN 144 THEN EMA_144_FIBO
            WHEN 200 THEN EMA_200_LONG
            WHEN 233 THEN EMA_233_FIBO
            ELSE NULL
        END
    FROM tms.EMA e
    INNER JOIN tms.Bars b ON e.BarID = b.ID
    WHERE e.TickerJID = @TickerJID
      AND e.TimeFrameID = @TimeFrameID
      AND b.BarTime < @CurrentBarTime
      AND e.BarID IS NOT NULL
    ORDER BY b.BarTime DESC;
    
    -- Если предыдущего значения нет, используем текущее Close как начальное значение
    IF @Result IS NULL
        SET @Result = @CurrentClose;
    
    -- Рассчитываем коэффициент сглаживания
    DECLARE @Alpha DECIMAL(18,8) = 2.0 / (@Period + 1);
    
    -- Применяем формулу EMA
    SET @Result = (@CurrentClose * @Alpha) + (@Result * (1 - @Alpha));
    
    RETURN @Result;
END;
GO