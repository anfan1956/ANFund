-- Check what foreign keys exist
SELECT 
    fk.name AS constraint_name,
    OBJECT_NAME(fk.parent_object_id) AS referencing_table,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_table
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) LIKE '%strategy%' 
   OR OBJECT_NAME(fk.referenced_object_id) LIKE '%strategy%'
ORDER BY referencing_table;

-- ============ DROP TABLES IN CORRECT ORDER ============


-- 1. Drop tables with foreign keys referencing strategy_configurations
IF OBJECT_ID('algo.strategy_executions', 'U') IS NOT NULL
    DROP TABLE algo.strategy_executions;

IF OBJECT_ID('algo.strategies_positions', 'U') IS NOT NULL
    DROP TABLE algo.strategies_positions;

-- 2. Now drop strategy_configurations
IF OBJECT_ID('algo.strategy_configurations', 'U') IS NOT NULL
    DROP TABLE algo.strategy_configurations;

-- 3. Drop tables that reference strategies
IF OBJECT_ID('algo.strategies', 'U') IS NOT NULL
    DROP TABLE algo.strategies;

-- 4. Drop tables that reference ConfigurationSets
IF OBJECT_ID('algo.ConfigurationSets', 'U') IS NOT NULL
    DROP TABLE algo.ConfigurationSets;

-- 5. Drop independent tables
IF OBJECT_ID('algo.ParameterSets', 'U') IS NOT NULL
    DROP TABLE algo.ParameterSets;

IF OBJECT_ID('algo.strategy_classes', 'U') IS NOT NULL
    DROP TABLE algo.strategy_classes;

-- ============ CREATE TABLES ============
-- 1. Create independent tables first
CREATE TABLE algo.strategy_classes (
    ID INT PRIMARY KEY IDENTITY(1,1),
    class_name NVARCHAR(200) NOT NULL,
    class_code NVARCHAR(60) NOT NULL,
    category NVARCHAR(100) NULL,
    description NVARCHAR(2000) NULL,
    typical_instruments NVARCHAR(1000) NULL,
    typical_timeframes NVARCHAR(400) NULL,
    required_data_frequency NVARCHAR(100) NULL DEFAULT '1Min',
    required_history_days INT NULL DEFAULT 30,
    typical_position_hold_time NVARCHAR(100) NULL,
    requires_realtime_data BIT NULL DEFAULT 0,
    requires_news_feed BIT NULL DEFAULT 0,
    requires_multiple_instruments BIT NULL DEFAULT 0,
    requires_options_data BIT NULL DEFAULT 0,
    requires_fundamental_data BIT NULL DEFAULT 0,
    implementation_complexity TINYINT NULL DEFAULT 3,
    backtesting_complexity TINYINT NULL DEFAULT 3,
    maintenance_complexity TINYINT NULL DEFAULT 3,
    risk_level TINYINT NULL DEFAULT 3,
    capital_requirements NVARCHAR(100) NULL,
    drawdown_characteristics NVARCHAR(200) NULL,
    feasible_with_current_setup BIT NULL DEFAULT 1,
    recommended_for_start BIT NULL DEFAULT 0,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);

CREATE TABLE algo.ParameterSets (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ParameterSetJson NVARCHAR(MAX) NOT NULL,
	ParameterValuesHash AS CAST(HASHBYTES('SHA2_256', ParameterSetJson) AS VARBINARY(32)) PERSISTED,
    CreatedAt DATETIME DEFAULT GETDATE(),
	    CONSTRAINT UQ_ParameterSets 
        UNIQUE (ParameterValuesHash),
    CONSTRAINT CHK_ParameterSetJson_IsJson CHECK (ISJSON(ParameterSetJson) = 1)
);

-- 2. Create tables that reference the above
CREATE TABLE algo.ConfigurationSets (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ParameterSetId INT NOT NULL,
    ParameterValuesJson NVARCHAR(MAX) NOT NULL,
    ParameterValuesHash AS CAST(HASHBYTES('SHA2_256', ParameterValuesJson) AS VARBINARY(32)) PERSISTED,
    CreatedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_ConfigurationSets_ParameterSets 
        FOREIGN KEY (ParameterSetId) 
        REFERENCES algo.ParameterSets(Id),
    CONSTRAINT UQ_ConfigurationSets 
        UNIQUE (parameterSetID, ParameterValuesHash),
    CONSTRAINT CHK_ParameterValuesJson_IsJson 
        CHECK (ISJSON(ParameterValuesJson) = 1)
);

CREATE TABLE algo.strategies (
    ID INT PRIMARY KEY IDENTITY(1,1),
    strategy_name NVARCHAR(200) NOT NULL,
    strategy_code NVARCHAR(60) NOT NULL,
    strategy_class_id INT NOT NULL,
    logic_description NVARCHAR(2000) NULL,
    created_by NVARCHAR(200) DEFAULT SUSER_SNAME(),
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    ParameterSetId INT NULL,
    CONSTRAINT FK_strategies_strategy_classes FOREIGN KEY (strategy_class_id) REFERENCES algo.strategy_classes(ID),
    CONSTRAINT FK_strategies_ParameterSets FOREIGN KEY (ParameterSetId) REFERENCES algo.ParameterSets(Id)
);

-- 3. Create tables that reference multiple others last
CREATE TABLE algo.strategy_configurations (
    ID INT PRIMARY KEY IDENTITY(1,1),
    strategy_id INT NOT NULL,
    instrument_symbol NVARCHAR(40) NOT NULL,
    instrument_jid INT NULL,
    primary_timeframe_id INT NOT NULL,
    secondary_timeframe_id INT NULL,
    parameters_json NVARCHAR(MAX) NULL,
    trading_start_time TIME NULL,
    trading_end_time TIME NULL,
    trade_days_mask TINYINT NULL DEFAULT 31,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    ConfigurationSetId INT NULL,
    CONSTRAINT FK_strategy_configurations_strategies FOREIGN KEY (strategy_id) REFERENCES algo.strategies(ID),
    CONSTRAINT FK_strategy_configurations_ConfigurationSets FOREIGN KEY (ConfigurationSetId) REFERENCES algo.ConfigurationSets(Id)
);


CREATE TABLE algo.strategies_positions (
    trade_uuid NVARCHAR(50) PRIMARY KEY,      -- UUID сделки = первичный ключ (уникален)
    strategy_configuration_id INT NOT NULL 
        FOREIGN KEY REFERENCES algo.strategy_configurations(ID)
);

-- “олько один индекс дл€ поиска по стратегии
CREATE INDEX idx_strategies_config ON algo.strategies_positions(strategy_configuration_id);