if OBJECT_ID('trd.pendingOrder') is not null drop table trd.pendingOrder
if OBJECT_id ('trd.orderType') is not null drop table trd.orderType
GO
create TABLE trd.orderType (
    ID int not null IDENTITY PRIMARY KEY
    , orderTypeName VARCHAR(50) NOT NULL CONSTRAINT uq_orderType UNIQUE
    , orderTypeCode VARCHAR(10) null
    , orderTypeDescription VARCHAR(255) NULL
)

insert into trd.orderType (orderTypeName)
VALUES 
('MarketOrder'), 
('LimitOrder'), 
('StopOrder'), 
('StopLimitOrder')


GO
BEGIN
    CREATE TABLE trd.pendingOrder (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        accountID INT NOT NULL CONSTRAINT fk_pendingOrder_account FOREIGN KEY REFERENCES trd.account(ID),
        orderUUID UNIQUEIDENTIFIER NOT NULL,
        orderTicket NVARCHAR(20) NOT NULL,
        symbol NVARCHAR(50) NOT NULL,
        orderTypeID int  NOT NULL CONSTRAINT fk_pendingOrder_OrderType FOREIGN KEY REFERENCES trd.orderType(ID), 
        direction NVARCHAR(10) NOT NULL CONSTRAINT ch_pendingOrdersDirection CHECK (direction in ('short', 'long')), 
        volume DECIMAL(18,2) NOT NULL,
        targetPrice DECIMAL(18,6) NULL,
        stopLoss DECIMAL(18,6) NULL,
        takeProfit DECIMAL(18,6) NULL,
        orderStatus NVARCHAR(20) NOT NULL CONSTRAINT ch_pendingOrdersStatus CHECK (orderStatus in ('pending', 'filled', 'cancelled', 'expired')), 
        createdTime DATETIME NOT NULL DEFAULT GETDATE(),
        modifiedTime DATETIME NULL,
        closeTime DATETIME NULL -- filled, cancelled, expired etc.

    );
    
    CREATE INDEX IX_pendingOrders_orderUUID ON trd.pendingOrder(orderUUID);
    CREATE INDEX IX_pendingOrders_orderStatus ON trd.pendingOrder(orderStatus) WHERE closeTime IS NULL;
END

GO
select * from trd.pendingOrder
