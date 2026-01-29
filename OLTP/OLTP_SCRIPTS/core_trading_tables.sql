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


-- Table: trd.client
CREATE TABLE trd.client (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    clientCode VARCHAR(20) NOT NULL UNIQUE,
    firstName NVARCHAR(100) NOT NULL,
    lastName NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    phone NVARCHAR(50)
    );


-- Table: trd.broker
CREATE TABLE trd.broker (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    brokerCode VARCHAR(20) NOT NULL UNIQUE,
    brokerName NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    phone NVARCHAR(50),
    website NVARCHAR(255)

);

-- Table: trd.platform
CREATE TABLE trd.platform (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    platformCode VARCHAR(20) NOT NULL UNIQUE,
    platformName NVARCHAR(100) NOT NULL,
    platformVersion VARCHAR(20)
);

-- Table: trd.accountType
CREATE TABLE trd.accountType (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    typeCode VARCHAR(20) NOT NULL UNIQUE,
    typeName NVARCHAR(100) NOT NULL,
    description NVARCHAR(500),
    leverage DECIMAL(10, 2),
    minDeposit DECIMAL(18, 2)
);

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
    assetID INT NOT NULL FOREIGN KEY REFERENCES ref.asset(ID),
    volume DECIMAL(18, 2) NOT NULL,
    margin DECIMAL(18, 2) NOT NULL,
    direction CHAR(4) NOT NULL CHECK (direction IN ('BUY', 'SELL')),    
    CONSTRAINT UQ_position_account_ticket UNIQUE (accountID, positionTicket)
);

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


-- Table: trd.positionState
CREATE TABLE trd.positionState (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    positionID INT NOT NULL FOREIGN KEY REFERENCES trd.position(ID),
    timestamp DATETIME NOT NULL DEFAULT GETDATE(),
    currentPrice DECIMAL(18, 6) NOT NULL,
    commission DECIMAL(18, 2) DEFAULT 0,
    swap DECIMAL(18, 2) DEFAULT 0
);

