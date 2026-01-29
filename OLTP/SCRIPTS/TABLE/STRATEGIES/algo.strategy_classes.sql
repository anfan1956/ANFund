-- ============================================
-- Window 1: Strategy Classes Table (Realistic Version)
-- ============================================

-- Drop if exists
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'algo.strategy_classes') AND type in (N'U'))
    DROP TABLE algo.strategy_classes;

-- Create strategy classes table
CREATE TABLE algo.strategy_classes (
    -- Identifier
    ID INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Basic Information
    class_name NVARCHAR(100) NOT NULL,                    -- Class name
    class_code NVARCHAR(30) NOT NULL UNIQUE,              -- Class code (English, no spaces)
    category NVARCHAR(50),                                -- Category: Trend, Reversal, Range, etc.
    
    -- Description
    description NVARCHAR(1000),                           -- Detailed description
    typical_instruments NVARCHAR(500),                    -- Typical instruments: Forex, Stocks, Crypto
    typical_timeframes NVARCHAR(200),                     -- Typical TFs: M1,M5,H1,H4
    
    -- Strategy Parameters
    required_data_frequency NVARCHAR(50) DEFAULT '1Min',  -- Required data frequency: Tick, 1Sec, 1Min, 5Min
    required_history_days INT DEFAULT 30,                 -- Required history in days
    typical_position_hold_time NVARCHAR(50),              -- Position hold time: Seconds, Minutes, Hours, Days
    
    -- Technical Requirements
    requires_realtime_data BIT DEFAULT 0,                 -- Requires real-time data
    requires_news_feed BIT DEFAULT 0,                     -- Requires news feed
    requires_multiple_instruments BIT DEFAULT 0,          -- Requires multiple instruments
    requires_options_data BIT DEFAULT 0,                  -- Requires options data
    requires_fundamental_data BIT DEFAULT 0,              -- Requires fundamental data
    
    -- Implementation Complexity
    implementation_complexity TINYINT DEFAULT 3,          -- 1=Low, 5=High
    backtesting_complexity TINYINT DEFAULT 3,             -- 1=Low, 5=High
    maintenance_complexity TINYINT DEFAULT 3,             -- 1=Low, 5=High
    
    -- Risk Profile
    risk_level TINYINT DEFAULT 3,                        -- Risk level: 1=Low, 5=High
    capital_requirements NVARCHAR(50),                   -- Capital requirements: Low, Medium, High
    drawdown_characteristics NVARCHAR(100),              -- Drawdown characteristics
    
    -- Feasibility for Current Setup
    feasible_with_current_setup BIT DEFAULT 1,           -- Possible with current infrastructure
    recommended_for_start BIT DEFAULT 0,                 -- Recommended for starting
    
    -- Status
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT CHK_risk_level CHECK (risk_level BETWEEN 1 AND 5),
    CONSTRAINT CHK_implementation_complexity CHECK (implementation_complexity BETWEEN 1 AND 5),
    CONSTRAINT CHK_backtesting_complexity CHECK (backtesting_complexity BETWEEN 1 AND 5),
    CONSTRAINT CHK_maintenance_complexity CHECK (maintenance_complexity BETWEEN 1 AND 5)
);

-- Indexes for performance
CREATE INDEX idx_strategy_classes_code ON algo.strategy_classes(class_code);
CREATE INDEX idx_strategy_classes_category ON algo.strategy_classes(category);
CREATE INDEX idx_strategy_classes_feasible ON algo.strategy_classes(feasible_with_current_setup);
CREATE INDEX idx_strategy_classes_recommended ON algo.strategy_classes(recommended_for_start);
CREATE INDEX idx_strategy_classes_active ON algo.strategy_classes(is_active);