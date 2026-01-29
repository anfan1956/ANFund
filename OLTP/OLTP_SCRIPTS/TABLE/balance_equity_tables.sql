use cTrader
go


if OBJECT_ID('algo.cBot') is NOT NULL DROP TABLE algo.cBot
if OBJECT_ID('fin.transactions') is NOT NULL DROP TABLE fin.transactions
if OBJECT_ID('fin.transactionType') is not null drop table fin.transactionType
if OBJECT_ID('fin.transactionSource') is not null drop table fin.transactionSource

if OBJECT_ID('algo.cBotType') is not null drop table algo.cBotType


GO
create Table fin.transactionSource (
    ID int not null PRIMARY KEY,
    sourceName NVARCHAR (50) not null constraint uq_transactionsource UNIQUE,
    sourceDescription NVARCHAR(255) null,
    sourceCode nvarchar(36) null, 
    modified DATETIME DEFAULT GETDATE()
)
create Table fin.TransactionType (
    ID int not null PRIMARY KEY,
    typeName NVARCHAR (50) not null constraint uq_transactionType UNIQUE,
    typeDescription NVARCHAR(255) null,
    modified DATETIME DEFAULT GETDATE()
)

create Table fin.transactions (
    ID int not null IDENTITY PRIMARY KEY,
    transactionTypeID int not null CONSTRAINT fk_transaction_transactiontype FOREIGN key REFERENCES fin.transactions (ID), 
    accountID int not null CONSTRAINT fk_account_transaction FOREIGN key REFERENCES trd.account (ID),
    amount money not null, 
    transactionDate DATETIME NOT NULL, 
    sourceID int not NULL CONSTRAINT fk_source_transaction FOREIGN key REFERENCES fin.transactionSource (ID)
)

create Table algo.cBotType (
    ID int not null IDENTITY PRIMARY KEY,
    cBotTypeName NVARCHAR(25) not null,
    typeDescription NVARCHAR (255),
    platformID int not null CONSTRAINT fk_platform_cBotType FOREIGN KEY REFERENCES trd.platforms (ID), 
    CONSTRAINT uq_cBotTypeName UNIQUE (cBotTypeName, platformID)
)
create Table algo.cBot (
    ID int not null IDENTITY PRIMARY KEY,
    cBotTypeID int not null CONSTRAINT fk_cBotType_cBot FOREIGN KEY REFERENCES algo.cBotType(ID),
    modified datetime DEFAULT (getdate())
      
)
