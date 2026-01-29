use cTrader
go

-- 2. Now drop table if exists
IF OBJECT_ID('algo.strategyTracker') IS NOT NULL
    DROP TABLE algo.strategyTracker;
GO

-- 3. Create table
CREATE TABLE algo.strategyTracker (
    ID INT IDENTITY(1,1) PRIMARY KEY,  
    configID INT NOT NULL CONSTRAINT FK_tracker_configs FOREIGN KEY (configID) REFERENCES algo.configurationSets(ID),
    timeStarted DATETIME DEFAULT GETUTCDATE(), 
    modified DATETIME DEFAULT GETUTCDATE(),
    timeClosed DATETIME NULL
);
GO

-- 5. Drop index if exists
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_strategyTracker_configID')
    DROP INDEX IX_strategyTracker_configID ON algo.strategyTracker;
GO

-- 6. Create index
CREATE INDEX IX_strategyTracker_configID 
ON algo.strategyTracker(configID) 
WHERE timeClosed IS NULL;