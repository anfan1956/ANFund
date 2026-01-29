
USE [cTrader]
SET NOCOUNT ON;



DECLARE @RowsMA INT, @RowsEMA INT, @RowsMomentum INT;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @timeGap int = 60 -- default delay parameter in minutes parameter for 1 min,

declare @calcStart datetime = getdate(), 
	@ema int, @ma int, @momentum int;

	-- 1. EMA  логируем внутри процедуры
    EXEC tms.sp_UpdateEMA @timeGap = @timeGap; 
	select @ema =  datediff(MILLISECOND, @calcStart, getdate());

	-- 2. MA , логируем внутри процедуры
	EXEC tms.sp_UpdateMA @timeGap = @timeGap;
	select @ma =  datediff(MILLISECOND, @calcStart, getdate());

	-- 3. Momentum (каждую минуту)
	SET @StartTime = GETDATE();
		EXEC tms.sp_UpdateIndicatorsMomentum @timeGap = @timeGap
		select @momentum =  datediff(MILLISECOND, @calcStart, getdate());

select @ema as ema, @ma as ma, @momentum as momentym
		

		
