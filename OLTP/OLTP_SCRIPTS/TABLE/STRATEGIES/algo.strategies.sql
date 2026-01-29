-- ============================================
-- Table: algo.strategies - Core strategy table (3NF compliant)
-- ============================================

-- Drop if exists
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'algo.strategies') AND type in (N'U'))
    DROP TABLE algo.strategies;

-- Create strategies table
CREATE TABLE algo.strategies (
    -- Primary key
    ID INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Strategy definition
    strategy_name NVARCHAR(100) NOT NULL,                    -- Strategy name
    strategy_code NVARCHAR(30) NOT NULL UNIQUE,              -- Unique strategy code
    
    -- Strategy type (classification)
    strategy_class_id INT NOT NULL,                          -- FK to strategy_classes.ID
    
    -- Core strategy logic (independent of instruments/timeframes)
    logic_description NVARCHAR(1000),                        -- Strategy logic description
    entry_conditions NVARCHAR(500),                          -- Entry conditions
    exit_conditions NVARCHAR(500),                           -- Exit conditions
    
    -- Audit
    created_by NVARCHAR(100) DEFAULT SYSTEM_USER,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    -- Foreign keys
    CONSTRAINT FK_strategies_strategy_class 
        FOREIGN KEY (strategy_class_id) 
        REFERENCES algo.strategy_classes(ID)
);

-- Indexes
CREATE INDEX idx_strategies_code ON algo.strategies(strategy_code);
CREATE INDEX idx_strategies_class ON algo.strategies(strategy_class_id);

