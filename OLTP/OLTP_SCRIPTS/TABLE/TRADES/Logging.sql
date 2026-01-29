use ctrader
GO

-- Clean up
if OBJECT_ID('algo.tradeResults') is not null drop table algo.tradeResults
if OBJECT_ID('algo.tradeLog') is not null drop table algo.tradeLog
if OBJECT_ID('algo.tradeEventType') is not null drop table algo.tradeEventType
if OBJECT_ID('algo.tradeType') is not null drop table algo.tradeType
GO

-- 1. Trade Types
CREATE TABLE algo.tradeType (
    ID INT NOT NULL IDENTITY PRIMARY KEY, 
    tradeTypeName VARCHAR(50) NOT NULL,
    created DATETIME DEFAULT(GETDATE()),
    CONSTRAINT UQ_tradeType_name UNIQUE (tradeTypeName)
)

-- 2. Event Types - только торговые события
CREATE TABLE algo.tradeEventType (
    ID INT NOT NULL IDENTITY PRIMARY KEY, 
    tradeType VARCHAR(50) CONSTRAINT ch_tradeType CHECK (tradeType in ('PendingOrder', 'Position')),
    eventName VARCHAR(50) NOT NULL,
    Category VARCHAR(20) NOT NULL CHECK (Category IN ('Open', 'Close', 'Modify')),
    Comment varchar (200),
    created DATETIME DEFAULT(GETDATE()),
    CONSTRAINT UQ_eventType_name_category UNIQUE (tradetype, eventName, Category)
)

-- 3. Main trade log - только реальные торговые события
CREATE TABLE algo.tradeLog (
    ID INT NOT NULL IDENTITY PRIMARY KEY, 
    tradeTypeID INT NOT NULL 
        CONSTRAINT FK_tradeLog_type FOREIGN KEY REFERENCES algo.tradeType(ID),
    tradeEventTypeID INT NOT NULL 
        CONSTRAINT FK_tradeLog_eventType FOREIGN KEY REFERENCES algo.tradeEventType(ID),
    direction VARCHAR(5) 
        CONSTRAINT CH_tradeLog_direction CHECK (direction IN ('long', 'short')),
    accountID INT 
        CONSTRAINT FK_tradeLog_account FOREIGN KEY REFERENCES trd.account(ID),
    currencyID INT 
        CONSTRAINT FK_tradeLog_currency FOREIGN KEY REFERENCES trd.currency(ID),
    assetID INT NULL,
    volume DECIMAL(18, 4) NULL,
    price NUMERIC(18, 6),
    slPrice NUMERIC(18, 6) NULL,
    tpPrice NUMERIC(18, 6) NULL,
    tradeUuid UNIQUEIDENTIFIER NOT NULL,
    created DATETIME DEFAULT(GETDATE()),
    
    --CONSTRAINT UQ_tradeLog_uuid UNIQUE (tradeUuid),
    INDEX IX_tradeLog_account_created (accountID, created),
    INDEX IX_tradeLog_uuid (tradeUuid)
)

-- 4. Trade results (for closed positions only)
CREATE TABLE algo.tradeResults (
    ID INT NOT NULL IDENTITY PRIMARY KEY,
    tradeLogID INT NOT NULL 
        CONSTRAINT FK_tradeResults_tradeLog FOREIGN KEY REFERENCES algo.tradeLog(ID),
    closeEventTypeID INT NULL 
        CONSTRAINT FK_tradeResults_closeEvent FOREIGN KEY REFERENCES algo.tradeEventType(ID),
    closed DATETIME NOT NULL DEFAULT(GETDATE()),
    exitPrice NUMERIC(18, 6) NOT NULL,
    volumeClosed DECIMAL(18, 4) NULL,
    grossProfit DECIMAL(18, 4) NULL,
    netProfit DECIMAL(18, 4) NULL,
    swap DECIMAL(18, 4) NULL,
    commission DECIMAL(18, 4) NULL,
    created DATETIME DEFAULT(GETDATE()),
    
    INDEX IX_tradeResults_tradeLog (tradeLogID),
    INDEX IX_tradeResults_closed (closed),
    CONSTRAINT UQ_tradeResults_tradeLog UNIQUE (tradeLogID)
)
GO

-- Reference data - только торговые события
INSERT INTO algo.tradeType (tradeTypeName) VALUES
    ('marketOrder'),
    ('LimitOrder'),
    ('StopOrder'),
    ('Position')

/*
INSERT INTO algo.tradeEventType (tradeType, eventName, Category) VALUES
    -- Opening (что вызвало открытие)
    ('PendingOrder', 'Discretionary', 'Open'),
    ('PendingOrder', 'Signal', 'Open'),
    ('PendingOrder', 'Algorithm', 'Open'),
    ('Position', 'Discretionary', 'Open'),
    ('Position', 'Signal', 'Open'), -- realised by placing market order
    ('Position', 'Algorithm', 'Open'), 
    -- Closing (почему закрылось)
    ('PendingOrder', 'Filled', 'Close'),
    ('PendingOrder', 'Expired', 'Close'),
    ('PendingOrder', 'Signal', 'Close'),
    ('PendingOrder', 'Algorithm', 'Close'),
    ('PendingOrder', 'Discretionary', 'Close'),
    ('Position','StopLoss', 'Close'),
    ('Position','TakeProfit', 'Close'),
    ('Position','ManualClose', 'Close'),
    ('Position','MarginCall', 'Close'),
    ('Position','Signal', 'Close'),  -- Сигнал на закрытие от Python app, может быть partial
    ('Position','Algorithm', 'Close'),  -- Сигнал на закрытие от Python app, может быть partial
    -- Modification (почему изменили)
    ('PendingOrder','Discretionary', 'Modify'),
    ('PendingOrder','Signal', 'Modify'),
    ('PendingOrder','Algorithm', 'Modify'),
    ('Position','Discretionary', 'Modify'),
    ('Position','Signal', 'Modify')
*/

INSERT INTO algo.tradeEventType (tradeType, eventName, Category, Comment) VALUES
    -- PendingOrder Opening
    ('PendingOrder', 'Discretionary', 'Open', 'Pending order opened manually'),
    ('PendingOrder', 'Signal', 'Open', 'Pending order opened by external signal'),
    
    -- Position Opening
    ('Position', 'Discretionary', 'Open', 'Position opened manually via market order'),
    ('Position', 'PendingOrder', 'Open', 'Position opened from filled pending order'),
    ('Position', 'Signal', 'Open', 'Position opened via market order by external signal'),
    
    -- Position Closing
    ('Position', 'StopLoss', 'Close', 'Position closed by stop loss trigger'),
    ('Position', 'TakeProfit', 'Close', 'Position closed by take profit trigger'),
    ('Position', 'ManualClose', 'Close', 'Position closed manually in terminal'),
    ('Position', 'MarginCall', 'Close', 'Position closed due to margin call'),
    ('Position', 'Signal', 'Close', 'Position closed by external close signal'),
    
    -- PendingOrder Closing
    ('PendingOrder', 'Filled', 'Close', 'Pending order filled and converted to position'),
    ('PendingOrder', 'Expired', 'Close', 'Pending order expired by time'),
    ('PendingOrder', 'Signal', 'Close', 'Pending order cancelled by external signal'),
    ('PendingOrder', 'Discretionary', 'Close', 'Pending order cancelled manually'),
    
    -- Modification
    ('PendingOrder', 'Discretionary', 'Modify', 'Pending order parameters modified manually'),
    ('PendingOrder', 'Signal', 'Modify', 'Pending order parameters modified by external signal'),
    ('Position', 'Discretionary', 'Modify', 'Position parameters (SL/TP/Volume) modified manually'),
    ('Position', 'Signal', 'Modify', 'Position parameters (SL/TP/Volume) modified by external signal')


GO

select * from algo.tradeEventType