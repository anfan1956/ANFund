use cTrader
go

-- ============================================
-- CREATE TRD.POSITION TABLE
-- ============================================

IF OBJECT_ID('trd.position', 'U') IS NOT NULL
    DROP TABLE trd.position;

GO

-- Table 1: Position master table
CREATE TABLE trd.position (
    id INT PRIMARY KEY,                           -- cTrader position ID
    assetID INT NOT NULL,                         -- Foreign key to ref.asset
    volume DECIMAL(18, 2) NOT NULL,               -- Trade volume
    price DECIMAL(18, 5) NOT NULL,                -- Entry price
    direction NVARCHAR(10) NOT NULL,              -- 'BUY' or 'SELL'
--    timestamp DATETIME NOT NULL,                  -- Entry time
--    created DATETIME DEFAULT GETDATE(),
    
    -- Foreign key constraint
    FOREIGN KEY (assetID) REFERENCES ref.asset(ID)
);

GO

-- ============================================
-- CREATE TRD.POSITIONTRADE TABLE
-- ============================================

IF OBJECT_ID('trd.positionTrade', 'U') IS NOT NULL
    DROP TABLE trd.positionTrade;

GO

-- Table 2: Position price history
CREATE TABLE trd.positionTrade (
    tradeID INT IDENTITY(1,1) PRIMARY KEY,
    positionID INT NOT NULL,
    timestamp DATETIME NOT NULL,
    price DECIMAL(18, 5) NOT NULL,
    
    -- Foreign key constraint
    FOREIGN KEY (positionID) REFERENCES trd.position(id)
);

GO

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Drop indexes if they exist
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_position_asset' AND object_id = OBJECT_ID('trd.position'))
    DROP INDEX idx_position_asset ON trd.position;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_position_timestamp' AND object_id = OBJECT_ID('trd.position'))
    DROP INDEX idx_position_timestamp ON trd.position;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_positionTrade_position' AND object_id = OBJECT_ID('trd.positionTrade'))
    DROP INDEX idx_positionTrade_position ON trd.positionTrade;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_positionTrade_timestamp' AND object_id = OBJECT_ID('trd.positionTrade'))
    DROP INDEX idx_positionTrade_timestamp ON trd.positionTrade;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_asset_ticker' AND object_id = OBJECT_ID('ref.asset'))
    DROP INDEX idx_asset_ticker ON ref.asset;

GO

-- Indexes for trd.position
CREATE INDEX idx_position_asset ON trd.position(assetID);
CREATE INDEX idx_position_timestamp ON trd.position(timestamp);

GO

-- Indexes for trd.positionTrade
CREATE INDEX idx_positionTrade_position ON trd.positionTrade(positionID);
CREATE INDEX idx_positionTrade_timestamp ON trd.positionTrade(timestamp);

GO

-- Index for ref.asset
CREATE INDEX idx_asset_ticker ON ref.asset(ticker);

GO

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify schemas
SELECT 'Schema Created: ' + name AS Verification
FROM sys.schemas 
WHERE name IN ('trd', 'ref', 'rep')
ORDER BY name;

GO

-- Verify tables
SELECT 
    CONCAT(s.name, '.', t.name) AS TableCreated
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('trd', 'ref', 'rep')
ORDER BY s.name, t.name;

GO

-- Show all assets
SELECT * FROM ref.asset ORDER BY ticker;

GO

-- Test the function
SELECT 
    'EURUSD' AS Ticker,
    ref.GetAssetID('EURUSD') AS AssetID,
    'Test Asset' AS TestTicker,
    ref.GetAssetID('TEST123') AS NewAssetID;

GO

-- Test foreign key relationship
SELECT 
    p.id,
    a.ticker,
    p.volume,
    p.price,
    p.direction,
    p.timestamp
FROM trd.position p
INNER JOIN ref.asset a ON p.assetID = a.ID
WHERE 1=0;  -- Returns no data, just tests the join

GO

-- Show table structures
EXEC sp_help 'ref.asset';
EXEC sp_help 'trd.position';
EXEC sp_help 'trd.positionTrade';

GO