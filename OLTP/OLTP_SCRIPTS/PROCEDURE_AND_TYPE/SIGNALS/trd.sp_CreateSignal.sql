use cTrader
go

IF OBJECT_ID('trd.sp_CreateSignal') is not null DROP PROC trd.sp_CreateSignal
GO 
/*
CREATE PROC trd.sp_CreateSignal 
    @ticker VARCHAR(50)
	, @direction NVARCHAR(10)  --buy, sell, drop
    , @volume NUMERIC(18, 6)
    , @orderPrice NUMERIC(18, 6)
    , @stopLoss NUMERIC(18, 6)
    , @takeProfit NUMERIC(18, 6)
    , @expiry DATETIME 
    , @brokerID INT = 2 
    , @platformID INT = 1
    , @tradeID int = null			-- ID from trd.trades_v (для drop)
    , @tradeType varchar(50) = null   -- 'POSITION' or 'PENDING ORDER' (для drop)
	, @strategy_configuration_id int = null
AS
BEGIN try;
    begin transaction

    if @ticker is null or @volume is null or @direction is null
        THROW 50000, 'Required parameter is null.', 1;
    
    -- Для DROP сигналов получаем существующий UUID
    DECLARE @tradeLabel UNIQUEIDENTIFIER = NULL;
    
    IF @direction = 'drop'
    BEGIN
        IF @tradeID IS NULL OR @tradeType IS NULL
            THROW 50000, 'Instrument to drop is not provided', 1;
        
        -- Получаем UUID из существующего трейда
        SELECT @tradeLabel = orderUUID
        FROM trd.trades_v 
        WHERE 1=1
			AND ID = @tradeID 
			AND tradeType = @tradeType;
        
        IF @tradeLabel IS NULL
            THROW 50000, 'Trade not found for drop operation', 1;
    END
    
    -- Получаем assetID
    DECLARE @assetID INT;

    SELECT @assetID = sm.assetID
    FROM ref.assetMasterTable m
		JOIN ref.SymbolMapping sm ON sm.assetID = m.ID 
    WHERE sm.brokerID = @brokerID
      AND sm.platformID = @platformID
      AND m.ticker = @ticker;
    
    IF @assetID IS NULL
        THROW 50000, 'Symbol mapping not found', 1;
    
	DECLARE @UUID UNIQUEIDENTIFIER;
	SET @UUID = NEWID();

    -- Вставляем сигнал с правильным positionLabel
    IF @expiry IS NULL
    BEGIN
        INSERT INTO algo.tradingSignals 
        (assetID, volume, direction, orderPrice, stopLoss, takeProfit, positionLabel, signalTypeID)
        SELECT 
            @assetID,
            @volume,
            @direction,
            @orderPrice,
            @stopLoss,
            @takeProfit,
            CASE 
                WHEN @direction = 'drop' THEN @tradeLabel  -- Используем существующий UUID
                ELSE @UUID                                   -- Генерируем новый UUID для buy/sell
            END
			, 1;
    END
		ELSE
    BEGIN
        INSERT INTO algo.tradingSignals 
        (assetID, volume, direction, orderPrice, stopLoss, takeProfit, expiry, positionLabel, signalTypeID)
        SELECT 
            @assetID,
            @volume,
            @direction,
            @orderPrice,
            @stopLoss,
            @takeProfit,
            @expiry,
            CASE 
                WHEN @direction = 'drop' THEN @tradeLabel		-- Используем существующий UUID
                ELSE @UUID										-- новый UUID для buy/sell
            END
			, 1;
    END
			if @strategy_configuration_id is not null
			BEGIN
				INSERT INTO algo.strategies_positions (trade_uuid, strategy_configuration_id)
				VALUES (@UUID, @strategy_configuration_id)
			END 
	COMMIT TRANSACTION    
END TRY
BEGIN CATCH
    Throw;
	rollback transaction
END CATCH
GO
*/

CREATE PROC trd.sp_CreateSignal 
    @ticker VARCHAR(50)
	, @direction NVARCHAR(10)  --buy, sell, drop
    , @volume NUMERIC(18, 6)
    , @orderPrice NUMERIC(18, 6)
    , @stopLoss NUMERIC(18, 6)
    , @takeProfit NUMERIC(18, 6)
    , @expiry DATETIME 
    , @brokerID INT = 2 
    , @platformID INT = 1
    , @tradeID int = null			-- ID from trd.trades_v (для drop)
    , @tradeType varchar(50) = null   -- 'POSITION' or 'PENDING ORDER' (для drop)
	, @strategy_configuration_id int = null
AS
BEGIN try;
    begin transaction

    if @ticker is null or @volume is null or @direction is null
        THROW 50000, 'Required parameter is null.', 1;
    
    -- Get signalTypeID from strategySignalType table
    DECLARE @signalTypeID INT;
    
    SELECT @signalTypeID = ID 
    FROM algo.strategySignalType 
    WHERE TypeName = UPPER(@direction);
    
    IF @signalTypeID IS NULL
        THROW 50000, 'Invalid direction. Must be BUY, SELL, or DROP', 1;
    
    -- Для DROP сигналов получаем существующий UUID
    DECLARE @tradeLabel UNIQUEIDENTIFIER = NULL;
    
    IF UPPER(@direction) = 'DROP'
    BEGIN
        IF @tradeID IS NULL OR @tradeType IS NULL
            THROW 50000, 'Instrument to drop is not provided', 1;
        
        -- Получаем UUID из существующего трейда
        SELECT @tradeLabel = orderUUID
        FROM trd.trades_v 
        WHERE 1=1
			AND ID = @tradeID 
			AND tradeType = @tradeType;
        
        IF @tradeLabel IS NULL
            THROW 50000, 'Trade not found for drop operation', 1;
    END
    
    -- Получаем assetID
    DECLARE @assetID INT;

    SELECT @assetID = sm.assetID
    FROM ref.assetMasterTable m
		JOIN ref.SymbolMapping sm ON sm.assetID = m.ID 
    WHERE sm.brokerID = @brokerID
      AND sm.platformID = @platformID
      AND m.ticker = @ticker;
    
    IF @assetID IS NULL
        THROW 50000, 'Symbol mapping not found', 1;
    
	DECLARE @UUID UNIQUEIDENTIFIER;
	SET @UUID = NEWID();

    -- Вставляем сигнал с правильным positionLabel и signalTypeID
    IF @expiry IS NULL
    BEGIN
        INSERT INTO algo.tradingSignals 
        (assetID, volume, signalTypeID, orderPrice, stopLoss, takeProfit, positionLabel)
        SELECT 
            @assetID,
            @volume,
            @signalTypeID,
            @orderPrice,
            @stopLoss,
            @takeProfit,
            CASE 
                WHEN UPPER(@direction) = 'DROP' THEN @tradeLabel  -- Используем существующий UUID
                ELSE @UUID                                   -- Генерируем новый UUID для buy/sell
            END;
    END
		ELSE
    BEGIN
        INSERT INTO algo.tradingSignals 
        (assetID, volume, signalTypeID, orderPrice, stopLoss, takeProfit, expiry, positionLabel)
        SELECT 
            @assetID,
            @volume,
            @signalTypeID,
            @orderPrice,
            @stopLoss,
            @takeProfit,
            @expiry,
            CASE 
                WHEN UPPER(@direction) = 'DROP' THEN @tradeLabel		-- Используем существующий UUID
                ELSE @UUID										-- новый UUID для buy/sell
            END;
    END
			if @strategy_configuration_id is not null
			BEGIN
				INSERT INTO algo.strategies_positions (trade_uuid, strategy_configuration_id)
				VALUES (@UUID, @strategy_configuration_id)
			END 
	COMMIT TRANSACTION    
END TRY
BEGIN CATCH
	select ERROR_MESSAGE()
    Throw;
	rollback transaction
END CATCH
GO

/* 
			---the columns is dropped
	alter table algo.tradingSignals
	alter column direction nvarchar (10) null
	alter table algo.tradingSignals
	drop constraint CK_tradingSignals_direction;
	alter table algo.tradingSignals
	drop column direction 
*/




















/*******************************************************************
 CALLING THE PROCEFURE

********************************************************************/
declare 	
	@ticker VARCHAR(50) =  'BTCUSD'			--'XAUUSD' 
	-- 'NVDA'  --	 
	, @direction NVARCHAR(10) = 'buy'		--buy, sell, drop
	, @volume NUMERIC(18, 6)  =  0.01
	, @orderPrice NUMERIC(18, 6) = null		--96600
	, @stopLoss	NUMERIC(18, 6)
	, @takeProfit NUMERIC(18, 6)
	, @expiry DATETIME 
	, @brokerID INT =2 
	, @platformID INT = 1
	, @id int								-- =  5732 -- null --  24 
	, @tradeType varchar (50) = 'POSITION'  -- null -- 'PENDING ORDER'	
	, @strategy_configuration_id int = 3
	;
/*
exec trd.sp_CreateSignal 
	 @ticker
	, @direction
	, @volume
	, @orderPrice
	, @stopLoss
	, @takeProfit
	, @expiry
	, @brokerID 
	, @platformID
	, @id 
	, @tradeType
	, @strategy_configuration_id 
	;
*/

--select * from trd.trades_v order by 3 DESC, createdTime DESC, 4;
--select top 5 * from trd.trades_v order by 1 desc
select top 5 * from algo.tradingSignals with (nolock) order by signalID desc; 
declare @uuid uniqueidentifier  = (select top 1 positionLabel from algo.tradingSignals order by signalID desc);
select * from algo.strategies_positions sp 
where sp.trade_uuid = @uuid