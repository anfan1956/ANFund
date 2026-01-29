
IF OBJECT_ID('trd.sp_PendingOrder') is not null drop proc trd.sp_PendingOrder
IF TYPE_ID('trd.PendingOrderTableType') IS NOT NULL
    DROP TYPE trd.PendingOrderTableType;
GO

CREATE TYPE trd.PendingOrderTableType AS TABLE (
    accountNumber VARCHAR(50),
    brokerName NVARCHAR(100),
    platformName NVARCHAR(100),
    orderUUID UNIQUEIDENTIFIER NOT NULL,
    orderTicket NVARCHAR(20) NOT NULL,
    symbol NVARCHAR(50) NOT NULL,
    orderTypeName NVARCHAR(50) NOT NULL,
    direction NVARCHAR(10) NOT NULL,
    volume DECIMAL(18,2) NOT NULL,
    targetPrice DECIMAL(18,6) NULL,
    stopLoss DECIMAL(18,6) NULL,
    takeProfit DECIMAL(18,6) NULL,
    orderStatus NVARCHAR(20) NOT NULL
);
GO
CREATE PROCEDURE trd.sp_PendingOrder
    @orders trd.PendingOrderTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        WITH s as (       
            SELECT 
                a.ID as accountID,
                o.orderUUID,
                o.orderTicket,
                o.symbol,
                ot.ID as orderTypeID,
                o.direction,
                o.volume,
                o.targetPrice,
                o.stopLoss,
                o.takeProfit,
                o.orderStatus
            FROM @orders o
                INNER JOIN trd.orderType ot ON ot.orderTypeName = o.orderTypeName
                INNER JOIN trd.platforms pl on pl.platformName= o.platformName 
                INNER JOIN trd.brokers b on b.brokerName=o.brokerName
                INNER JOIN trd.account a on a.accountNumber = o.accountNumber and a.platformID = pl.ID and a.brokerID = b.ID
        ) 
        MERGE trd.pendingOrder AS t USING s
            ON t.orderUUID = s.orderUUID 
        WHEN MATCHED THEN
            UPDATE SET 
                t.volume          = s.volume,
                t.targetPrice     = s.targetPrice,
                t.stopLoss        = s.stopLoss,
                t.takeProfit      = s.takeProfit,
                t.orderStatus     = s.orderStatus,
                t.modifiedTime    = GETDATE(),
                t.closeTime = CASE 
                    WHEN s.orderStatus IN ('filled', 'cancelled', 'expired') 
                    THEN GETDATE() 
                    ELSE NULL 
                END
        WHEN NOT MATCHED THEN
            INSERT (
                accountID, orderUUID, orderTicket, symbol, orderTypeID, direction,
                volume, targetPrice, stopLoss, takeProfit, orderStatus
            )
            VALUES (
                s.accountID, s.orderUUID, s.orderTicket, s.symbol, 
                s.orderTypeID, s.direction, s.volume, 
                s.targetPrice, s.stopLoss, s.takeProfit, 
                s.orderStatus
            );
        
        COMMIT TRANSACTION;
        
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -1;
    END CATCH;
END
GO
/*
 DECLARE @orders trd.PendingOrderTableType
INSERT INTO @orders VALUES 
('5161801', 'Pepperstone', 'cTrader', 'dd1a112d-a59d-4d7f-b94a-f9f58d5cb96d', '311066262', 'XAUUSD', 'LimitOrder', 'long', 1.00, 4492.900000, NULL, NULL, 'cancelled')

EXEC trd.sp_PendingOrder @orders
go
*/

select * from trd.pendingOrder po where closeTime is null order by 1 desc;
--update trd.pendingOrder set closeTime =GETDATE()
--select * from trd.pendingOrder po where closeTime is null  and symbol = 'BTCUSD' and takeProfit is null


