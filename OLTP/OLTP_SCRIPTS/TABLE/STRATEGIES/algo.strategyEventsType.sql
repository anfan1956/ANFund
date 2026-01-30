-- 1. Создаём таблицу событий
IF OBJECT_ID('algo.strategyEventsType') IS NOT NULL 
    DROP TABLE algo.strategyEventsType;
GO

CREATE TABLE algo.strategyEventsType (
    ID INT PRIMARY KEY IDENTITY(1,1),
    eventTypeName NVARCHAR(50) NOT NULL UNIQUE,
    description NVARCHAR(255) NULL,
    created_date DATETIME DEFAULT GETUTCDATE()
);

INSERT INTO algo.strategyEventsType (eventTypeName, description) VALUES
--('start', 'Strategy started'),
--('stop', 'Strategy stopped'),
--('error', 'Strategy error'),
--('termination', 'Strategy terminated'), 
--('signal','Strategy logics trading signal');

PRINT 'Table algo.strategyEventsType created';
GO


ALTER TABLE logs.strategyExecution 
ALTER COLUMN signalTypeID INT NULL;
GO

PRINT 'Column signalTypeID changed to NULLABLE';