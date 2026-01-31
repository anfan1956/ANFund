use cTrader
go

IF OBJECT_ID('trd.sp_CreateSignal') is not null DROP PROC trd.sp_CreateSignal
GO 

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
    WHERE upper(TypeName) = UPPER(@direction);
    
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
			--if @strategy_configuration_id is not null
			BEGIN
				INSERT INTO algo.strategies_positions (trade_uuid, strategy_configuration_id) VALUES (@UUID, @strategy_configuration_id)
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
	 @ticker VARCHAR(50) =  'BTCUSD'			
	, @direction NVARCHAR(10) = 'buy'		--buy, sell, drop
	, @volume NUMERIC(18, 6)  =  0.01
	, @orderPrice NUMERIC(18, 6) = null		--96600
	, @stopLoss	NUMERIC(18, 6)
	, @takeProfit NUMERIC(18, 6)
	, @expiry DATETIME 
	, @brokerID INT =2 
	, @platformID INT = 1
	, @id int								-- =  5732 -- null --  24 
	, @tradeType varchar (50)				-- = 'POSITION'  -- null -- 'PENDING ORDER'	
	, @strategy_configuration_id int		-- = 3
	;
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
/*
*/

select top 5 * from algo.tradingSignals with (nolock) order by signalID desc; 
select top 5 * from trd.trades_v order by 1 desc

declare @uuid uniqueidentifier  = (select top 1 positionLabel from algo.tradingSignals order by signalID desc);
select @uuid;
select top 5 * from algo.strategies_positions sp 
	where sp.trade_uuid = @uuid
order by createdTime desc;

/*
--SELECT algo.fn_GetStrategyPositionIDs(3) as positions_json;

	--  до того, как робот исполнил
select top 5 * from algo.tradingSignals with (nolock) order by signalID desc; 
signalID	assetID	volume	orderPrice	stopLoss	takeProfit	timeCreated	expiry	status	executionType	executionID	executionTime	positionLabel	signalTypeID
836	56	0.010000	NULL	NULL	NULL	2026-01-29 16:02:48.363	2026-01-29 17:02:48.363	PENDING	NULL	NULL	NULL	ED31DFC6-9235-4C1D-A5B0-0B2340564BD4	1
835	56	0.010000	NULL	NULL	NULL	2026-01-29 15:50:55.297	2026-01-29 16:50:55.297	ACCEPTED	position	192574576	2026-01-29 15:50:56.033	4450EED3-D153-4E42-8DF2-965D33CCD7D4	1
834	13	0.020000	NULL	NULL	NULL	2026-01-29 08:32:30.733	2026-01-29 09:32:30.733	ACCEPTED	position	192439532	2026-01-29 08:32:31.573	F90E5747-054B-4F01-997E-A33534274C38	1
833	13	0.020000	NULL	NULL	NULL	2026-01-29 08:17:30.383	2026-01-29 09:17:30.383	ACCEPTED	position	192435099	2026-01-29 08:17:31.237	42B7E971-4704-4A09-B860-997286AAEE71	1
832	13	0.020000	NULL	NULL	NULL	2026-01-29 08:10:07.347	2026-01-29 09:10:07.347	ACCEPTED	position	192433012	2026-01-29 08:10:08.043	10BD1139-0528-42AB-8191-B2CC6B28F499	1

select top 5 * from trd.trades_v order by 1 desc
ID	orderUUID	tradeType	ticker	direction	entryPrice	createdTime	volume	margin	creationOrder
34	F46CE967-6464-4F19-ABBE-E3CFC7C452D0	PENDING ORDER	EURUSD	long	1.150000	2026-01-19 23:39:44.017	10000.00	NULL	5
32	F1883A71-20C2-430C-8A3B-35C1A915C576	PENDING ORDER	XPTUSD	long	2256.000000	2026-01-15 04:38:46.893	2.00	NULL	4
25	13A76AF1-9A44-4BD1-930C-08B6D330302F	PENDING ORDER	BTCUSD	long	96600.000000	2026-01-14 22:18:40.543	0.02	NULL	3
17	8BDDE67B-35F6-4ADA-83DC-A1B417AC1061	PENDING ORDER	SpotBrent	long	62.448000	2026-01-12 11:35:44.420	25.00	NULL	2
16	7BB3C16F-A142-453D-BB51-C2A177527285	PENDING ORDER	SpotBrent	long	63.172000	2026-01-12 11:34:07.550	20.00	NULL	1

______________________________________________________________________________
	-- сразу после исполнения
select top 5 * from algo.tradingSignals with (nolock) order by signalID desc; 
signalID	assetID	volume	orderPrice	stopLoss	takeProfit	timeCreated	expiry	status	executionType	executionID	executionTime	positionLabel	signalTypeID
836	56	0.010000	NULL	NULL	NULL	2026-01-29 16:02:48.363	2026-01-29 17:02:48.363	ACCEPTED	position	192579664	2026-01-29 16:02:48.960	ED31DFC6-9235-4C1D-A5B0-0B2340564BD4	1
835	56	0.010000	NULL	NULL	NULL	2026-01-29 15:50:55.297	2026-01-29 16:50:55.297	ACCEPTED	position	192574576	2026-01-29 15:50:56.033	4450EED3-D153-4E42-8DF2-965D33CCD7D4	1
834	13	0.020000	NULL	NULL	NULL	2026-01-29 08:32:30.733	2026-01-29 09:32:30.733	ACCEPTED	position	192439532	2026-01-29 08:32:31.573	F90E5747-054B-4F01-997E-A33534274C38	1
833	13	0.020000	NULL	NULL	NULL	2026-01-29 08:17:30.383	2026-01-29 09:17:30.383	ACCEPTED	position	192435099	2026-01-29 08:17:31.237	42B7E971-4704-4A09-B860-997286AAEE71	1
832	13	0.020000	NULL	NULL	NULL	2026-01-29 08:10:07.347	2026-01-29 09:10:07.347	ACCEPTED	position	192433012	2026-01-29 08:10:08.043	10BD1139-0528-42AB-8191-B2CC6B28F499	1

select top 5 * from trd.trades_v order by 1 desc
ID	orderUUID	tradeType	ticker	direction	entryPrice	createdTime	volume	margin	creationOrder
6063	ED31DFC6-9235-4C1D-A5B0-0B2340564BD4	POSITION	BTCUSD	Buy	87992.970000	2026-01-29 13:02:45.000	0.01	439.97	1
34	F46CE967-6464-4F19-ABBE-E3CFC7C452D0	PENDING ORDER	EURUSD	long	1.150000	2026-01-19 23:39:44.017	10000.00	NULL	5
32	F1883A71-20C2-430C-8A3B-35C1A915C576	PENDING ORDER	XPTUSD	long	2256.000000	2026-01-15 04:38:46.893	2.00	NULL	4
25	13A76AF1-9A44-4BD1-930C-08B6D330302F	PENDING ORDER	BTCUSD	long	96600.000000	2026-01-14 22:18:40.543	0.02	NULL	3
17	8BDDE67B-35F6-4ADA-83DC-A1B417AC1061	PENDING ORDER	SpotBrent	long	62.448000	2026-01-12 11:35:44.420	25.00	NULL	2


*/
