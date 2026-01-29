

-- Drop tables in correct order (child first, then parent)
IF OBJECT_ID('logs.strategyExecution') IS NOT NULL
    DROP TABLE [logs].[strategyExecution]
GO

IF OBJECT_ID('algo.strategySignalType') IS NOT NULL
    DROP TABLE [algo].[strategySignalType]
GO

-- Create strategySignalType table
CREATE TABLE algo.strategySignalType
(
    ID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_algo_strategySignalType PRIMARY KEY CLUSTERED,
    TypeName NVARCHAR(20) NOT NULL CONSTRAINT UQ_algo_strategySignalType_TypeName UNIQUE,
    Description NVARCHAR(200) NULL,
    created_date DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_date DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
)
GO

-- Populate strategySignalType table with our three values
INSERT INTO [algo].[strategySignalType] (TypeName, Description)
VALUES 
    ('BUY', 'place buy market order'),
    ('SELL', 'place sell market order'),
    ('DROP', 'place close market order')
GO

