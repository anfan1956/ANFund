
-- 2. Добавляем EventTypeID если нет
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = 'strategyExecution' 
               AND TABLE_SCHEMA = 'logs'
               AND COLUMN_NAME = 'EventTypeID')
BEGIN
    ALTER TABLE logs.strategyExecution 
    ADD EventTypeID INT NULL;
    
    PRINT 'Column EventTypeID added to logs.strategyExecution';
END
ELSE
BEGIN
    PRINT 'Column EventTypeID already exists in logs.strategyExecution';
END
GO

-- 3. Добавляем внешний ключ если нет
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
               WHERE CONSTRAINT_NAME = 'FK_strategyExecution_EventType'
               AND TABLE_SCHEMA = 'logs'
               AND TABLE_NAME = 'strategyExecution')
BEGIN
    ALTER TABLE logs.strategyExecution 
    ADD CONSTRAINT FK_strategyExecution_EventType 
    FOREIGN KEY (EventTypeID) REFERENCES algo.strategyEventsType(ID);
    
    PRINT 'Foreign key FK_strategyExecution_EventType added';
END
ELSE
BEGIN
    PRINT 'Foreign key FK_strategyExecution_EventType already exists';
END
GO