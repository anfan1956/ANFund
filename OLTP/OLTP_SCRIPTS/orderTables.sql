use cTrader
GO

if OBJECT_ID('trd.orders') is not null drop table trd.orders;
if OBJECT_ID('trd.orderType') is not null drop table trd.orderType


GO
create Table trd.orderType (
    ID int not null PRIMARY KEY,
    orderTypeName NVARCHAR (50) not null constraint uq_orderTypeName UNIQUE,
    orderTypeDescription NVARCHAR(255) null,
    orderTypeCode nvarchar(36) null, 
    modified DATETIME DEFAULT GETDATE()
)
create Table trd.orders (
    ID int not null PRIMARY KEY,
    orderID varchar (50) not null , -- order number with brokers account
    accountID int not null CONSTRAINT fk_account_order FOREIGN KEY REFERENCES trd.account(ID),
    assetID int not null CONSTRAINT fk_asset_order FOREIGN KEY REFERENCES ref.assetMasterTable(ID),
    price money not null,
    volume NUMERIC(18, 6) not NULL, 
    takeProfit NUMERIC(18, 6) NULL, 
    stopLoss NUMERIC(18, 6) NULL, 
    typeID NVARCHAR (50) not null,
    direction NVARCHAR(5) not null CONSTRAINT ch_orders_directions CHECK (direction in ('BUY', 'SELL')),
    created DATETIME DEFAULT GETDATE(),
    modified DATETIME NULL,
    expiry DATETIME NULL 
    
)