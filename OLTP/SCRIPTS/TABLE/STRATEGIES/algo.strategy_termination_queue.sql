use cTrader
go


-- Drop if exists
IF OBJECT_ID('algo.strategy_termination_queue', 'U') IS NOT NULL
    DROP TABLE algo.strategy_termination_queue;

-- Create termination queue table
CREATE TABLE algo.strategy_termination_queue (
    id INT PRIMARY KEY IDENTITY(1,1),
    config_id INT NOT NULL FOREIGN KEY REFERENCES algo.configurationSets(ID),
    terminate BIT NOT NULL DEFAULT 1,
    requested_at DATETIME DEFAULT GETUTCDATE(),
    terminated_at DATETIME NULL,
    

);

-- Drop index if exists
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_strategy_termination_queue_config')
    DROP INDEX IX_strategy_termination_queue_config ON algo.strategy_termination_queue;

-- Create index for fast lookup
CREATE INDEX IX_strategy_termination_queue_config 
ON algo.strategy_termination_queue(config_id, terminate) 
WHERE terminated_at IS NULL;
