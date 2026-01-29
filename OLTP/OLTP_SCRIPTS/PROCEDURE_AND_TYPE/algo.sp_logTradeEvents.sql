USE ctrader
GO

-- Drop and recreate procedure with READ COMMITTED
IF OBJECT_ID('algo.sp_LogTradeEvents', 'P') IS NOT NULL DROP PROCEDURE algo.sp_LogTradeEvents;
if TYPE_ID('algo.TradeEventTableType') is not NULL drop type algo.TradeEventTableType
GO

CREATE TYPE [algo].[TradeEventTableType] AS TABLE (
	tradeUUID uniqueidentifier NULL,
    tradeType VARCHAR(50) NULL,
	eventName nvarchar(50) NULL,
	category nvarchar(20) NULL,
	direction nvarchar(5) NULL,
	accountNumber nvarchar(50) NULL,
	brokerName nvarchar(100) NULL,
	platformCode nvarchar(20) NULL,
	symbol VARCHAR (50),
	volume decimal(18, 4) NULL,
	price decimal(18, 6) NULL,
	slPrice decimal(18, 6) NULL,
	tpPrice decimal(18, 6) NULL,
	tradeTypeName nvarchar(50) NULL,
	profitInfo xml NULL
)
GO

CREATE PROCEDURE algo.sp_LogTradeEvents @events algo.TradeEventTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    BEGIN TRY
        -- Use READ COMMITTED instead of SNAPSHOT
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        BEGIN TRANSACTION;
        
        -- for rows inserted
        DECLARE @insertedTradeLogs TABLE (
            ID INT,
            tradeUuid UNIQUEIDENTIFIER,
            tradeEventTypeID INT
        );
        
        -- Insert ALL trade log entries (Open, Modify, Close, etc.)
        INSERT INTO algo.tradeLog (
            tradeTypeID,
            tradeEventTypeID,
            direction,
            accountID,
            currencyID,
            assetID,
            volume,
            price,
            slPrice,
            tpPrice,
            tradeUuid,
            created
        )
        OUTPUT inserted.ID, inserted.tradeUuid, inserted.tradeEventTypeID
        INTO @insertedTradeLogs
        SELECT 
            tt.ID,
            et.ID,
            e.direction,
            trd.account_ID(e.accountNumber, e.brokerName, e.platformCode),
            a.currencyID,
            sm.assetID,
            e.volume,
            e.price,
            e.slPrice,
            e.tpPrice,
            e.tradeUUID,
            GETDATE()
        FROM @events e
            INNER JOIN algo.tradeType tt ON tt.tradeTypeName = e.tradeTypeName
            INNER JOIN algo.tradeEventType et ON et.eventName = e.eventName AND et.Category = e.category and e.tradeType = et.tradeType
            INNER join trd.brokers b on b.brokerName = e.brokerName
            INNER JOIN trd.platforms p on p.platformCode= e.platformCode 
            INNER JOIN ref.SymbolMapping sm on sm.brokerID = b.ID and sm.platformID = p.ID and e.symbol = sm.Symbol
            inner join trd.account a on a.brokerID = b.ID and a.platformID = p.ID and a.accountNumber = e.accountNumber; 
        

        INSERT INTO algo.tradeResults (
            tradeLogID, 
            closeEventTypeID, 
            closed, 
            exitPrice, 
            grossProfit, 
            netProfit,
            swap,
            commission
        )
        SELECT 
            itl.ID,
            itl.tradeEventTypeID,  
            GETDATE(),
            e.price,
            ISNULL(e.profitInfo.value('(/Profit/Gross)[1]', 'DECIMAL(18,4)'), 0),
            ISNULL(e.profitInfo.value('(/Profit/Net)[1]', 'DECIMAL(18,4)'), 0),
            ISNULL(e.profitInfo.value('(/Profit/Swap)[1]', 'DECIMAL(18,4)'), 0),
            ISNULL(e.profitInfo.value('(/Profit/Commission)[1]', 'DECIMAL(18,4)'), 0)
        FROM @events e
			INNER JOIN @insertedTradeLogs itl ON itl.tradeUuid = e.tradeUUID
			join algo.tradeEventType et on et.ID=itl.tradeEventTypeID
        WHERE et.category = 'Close' and et.tradeType = 'Position';
        
        COMMIT TRANSACTION;
        
        DECLARE @rowCount INT = @@ROWCOUNT;
        -- PRINT FORMATMESSAGE('Successfully logged %d trade events', @rowCount);
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;    
        select ERROR_MESSAGE() as eror;
        THROW;
    END CATCH
END
GO