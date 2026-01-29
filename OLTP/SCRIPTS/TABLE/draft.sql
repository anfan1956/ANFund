sql
USE cTrader;
GO

-- Drop tables in correct order (child first, parent last)
IF OBJECT_ID('trd.positionState', 'U') IS NOT NULL
    DROP TABLE trd.positionState;
IF OBJECT_ID('trd.positionStartFinish', 'U') IS NOT NULL
    DROP TABLE trd.positionStartFinish;
IF OBJECT_ID('trd.position', 'U') IS NOT NULL
    DROP TABLE trd.position;
IF OBJECT_ID('trd.account', 'U') IS NOT NULL
    DROP TABLE trd.account;
IF OBJECT_ID('trd.accountType', 'U') IS NOT NULL
    DROP TABLE trd.accountType;
IF OBJECT_ID('trd.platform', 'U') IS NOT NULL
    DROP TABLE trd.platform;
IF OBJECT_ID('trd.broker', 'U') IS NOT NULL
    DROP TABLE trd.broker;
IF OBJECT_ID('trd.client', 'U') IS NOT NULL
    DROP TABLE trd.client;
IF OBJECT_ID('trd.currency', 'U') IS NOT NULL
    DROP TABLE trd.currency;
IF OBJECT_ID('trd.asset', 'U') IS NOT NULL
    DROP TABLE trd.asset;
IF OBJECT_ID('trd.symbol', 'U') IS NOT NULL
    DROP TABLE trd.symbol;

GO

-- ============================================
-- REFERENCE TABLES
-- ============================================

-- Table: trd.currency
CREATE TABLE trd.currency (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    currencyCode CHAR(3) NOT NULL UNIQUE,
    currencyName NVARCHAR(50) NOT NULL
);

CREATE INDEX IX_currency_currencyCode ON trd.currency(currencyCode);

-- Table: trd.client
CREATE TABLE trd.client (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    clientCode VARCHAR(20) NOT NULL UNIQUE,
    firstName NVARCHAR(100) NOT NULL,
    lastName NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    phone NVARCHAR(50)
    );

CREATE INDEX IX_client_clientCode ON trd.client(clientCode);
CREATE INDEX IX_client_email ON trd.client(email);

-- Table: trd.broker
CREATE TABLE trd.broker (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    brokerCode VARCHAR(20) NOT NULL UNIQUE,
    brokerName NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    phone NVARCHAR(50),
    website NVARCHAR(255)

);

CREATE INDEX IX_broker_brokerCode ON trd.broker(brokerCode);

-- Table: trd.platform
CREATE TABLE trd.platform (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    platformCode VARCHAR(20) NOT NULL UNIQUE,
    platformName NVARCHAR(100) NOT NULL,
    platformVersion VARCHAR(20)
);

CREATE INDEX IX_platform_platformCode ON trd.platform(platformCode);

-- Table: trd.accountType
CREATE TABLE trd.accountType (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    typeCode VARCHAR(20) NOT NULL UNIQUE,
    typeName NVARCHAR(100) NOT NULL,
    description NVARCHAR(500),
    leverage DECIMAL(10, 2),
    minDeposit DECIMAL(18, 2)
);

CREATE INDEX IX_accountType_typeCode ON trd.accountType(typeCode);


-- ============================================
-- CORE TABLES
-- ============================================

-- Table: trd.account
CREATE TABLE trd.account (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    accountNumber VARCHAR(50) NOT NULL,
    accountTypeID INT NOT NULL FOREIGN KEY REFERENCES trd.accountType(ID),
    platformID INT NOT NULL FOREIGN KEY REFERENCES trd.platform(ID),
    brokerID INT NOT NULL FOREIGN KEY REFERENCES trd.broker(ID),
    clientID INT NOT NULL FOREIGN KEY REFERENCES trd.client(ID),
    currencyID INT NOT NULL FOREIGN KEY REFERENCES trd.currency(ID),
    modifiedDate DATETIME NOT NULL DEFAULT GETDATE()
    
    CONSTRAINT UQ_account_broker_account UNIQUE (brokerID, accountNumber, platformID)
);

CREATE INDEX IX_account_accountNumber ON trd.account(accountNumber);
CREATE INDEX IX_account_clientID ON trd.account(clientID);
CREATE INDEX IX_account_brokerID ON trd.account(brokerID);
CREATE INDEX IX_account_platformID ON trd.account(platformID);
CREATE INDEX IX_account_accountTypeID ON trd.account(accountTypeID);
CREATE INDEX IX_account_currencyID ON trd.account(currencyID);

-- Table: trd.position
CREATE TABLE trd.position (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    accountID INT NOT NULL FOREIGN KEY REFERENCES trd.account(ID),
    positionTicket VARCHAR(50) NOT NULL,
    assetID INT NOT NULL FOREIGN KEY REFERENCES trd.asset(ID),
    volume DECIMAL(18, 2) NOT NULL,
    margin DECIMAL(18, 2) NOT NULL,
    direction CHAR(4) NOT NULL CHECK (direction IN ('BUY', 'SELL')),
    
    CONSTRAINT UQ_position_account_ticket UNIQUE (accountID, positionTicket)
);

CREATE INDEX IX_position_accountID ON trd.position(accountID);
CREATE INDEX IX_position_symbolID ON trd.position(symbolID);
CREATE INDEX IX_position_positionTicket ON trd.position(positionTicket);

-- Table: trd.positionStartFinish
CREATE TABLE trd.positionStartFinish (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    positionID INT NOT NULL FOREIGN KEY REFERENCES trd.position(ID),
    openPrice DECIMAL(18, 6) NOT NULL,
    closePrice DECIMAL(18, 6),
    openTime DATETIME NOT NULL,
    closeTime DATETIME,
    openBalance DECIMAL(18, 2)  NULL, --referes to account balance but before the whole base in production we don't know
    closeBalance DECIMAL(18, 2)  --referes to account balance but before the whole base in production we don't know
);

CREATE INDEX IX_positionStartFinish_positionID ON trd.positionStartFinish(positionID);
CREATE INDEX IX_positionStartFinish_openTime ON trd.positionStartFinish(openTime);
CREATE INDEX IX_positionStartFinish_closeTime ON trd.positionStartFinish(closeTime);

-- Table: trd.positionState
CREATE TABLE trd.positionState (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    positionID INT NOT NULL FOREIGN KEY REFERENCES trd.position(ID),
    timestamp DATETIME NOT NULL DEFAULT GETDATE(),
    currentPrice DECIMAL(18, 6) NOT NULL,
    commission DECIMAL(18, 2) DEFAULT 0,
    swap DECIMAL(18, 2) DEFAULT 0
);

CREATE INDEX IX_positionState_positionID ON trd.positionState(positionID);
CREATE INDEX IX_positionState_timestamp ON trd.positionState(timestamp);
CREATE INDEX IX_positionState_position_timestamp ON trd.positionState(positionID, timestamp);

-- ============================================
-- ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================

-- Composite indexes for common queries
CREATE INDEX IX_position_account_symbol ON trd.position(accountID, symbolID, positionStatus);
CREATE INDEX IX_position_openTime_status ON trd.position(openTime, positionStatus);
CREATE INDEX IX_account_balance_active ON trd.account(balance, isActive);

-- ============================================
-- FOREIGN KEY CONSTRAINTS (already included above)
-- ============================================

-- All foreign keys are already defined inline in table creation
-- This ensures referential integrity

GO

-- ============================================
-- SAMPLE DATA INSERTION (Optional)
-- ============================================

/*
-- Insert sample currencies
INSERT INTO trd.currency (currencyCode, currencyName) VALUES
('USD', 'US Dollar'),
('EUR', 'Euro'),
('GBP', 'British Pound'),
('JPY', 'Japanese Yen');

-- Insert sample client
INSERT INTO trd.client (clientCode, firstName, lastName, email) VALUES
('CLI001', 'John', 'Doe', 'john.doe@email.com');

-- Insert sample broker
INSERT INTO trd.broker (brokerCode, brokerName) VALUES
('BROK001', 'Demo Broker Inc.');

-- Insert sample platform
INSERT INTO trd.platform (platformCode, platformName) VALUES
('CTRADER', 'cTrader');

-- Insert sample account type
INSERT INTO trd.accountType (typeCode, typeName, leverage) VALUES
('STD', 'Standard Account', 100.00);

-- Insert sample symbol
INSERT INTO trd.symbol (symbolCode, symbolName, baseCurrencyID, quoteCurrencyID, pipSize, contractSize, minTradeSize, maxTradeSize) 
SELECT 'EURUSD', 'Euro/US Dollar', 
       (SELECT currencyID FROM trd.currency WHERE currencyCode = 'EUR'),
       (SELECT currencyID FROM trd.currency WHERE currencyCode = 'USD'),
       0.0001, 100000, 0.01, 100;
*/

PRINT 'Database schema created successfully.';
