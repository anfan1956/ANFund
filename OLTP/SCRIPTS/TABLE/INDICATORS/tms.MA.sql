USE [cTrader]
GO

-- First check if table exists and drop it if it does
IF OBJECT_ID('tms.MA') IS NOT NULL    DROP TABLE tms.MA;

GO

-- Create table for MA values
CREATE TABLE tms.MA
(
    ID BIGINT constraint PK_MA PRIMARY KEY		constraint FK_MA_Bars foreign key references tms.bars(ID),                   
    TickerJID INT NOT NULL ,                       
    BarTime DATETIME NOT NULL,                    
    TimeFrameID INT NOT NULL	constraint  FK_MA_TimeFrames foreign key references tms.TimeFrames(ID),                 
    
    -- Simple Moving Averages (MA)
    MA5 DECIMAL(18,8) NULL,                       -- MA 5 - very short-term trend
    MA8 DECIMAL(18,8) NULL,                       -- MA 5 - very short-term trend
    MA20 DECIMAL(18,8) NULL,                      -- MA 20 - short-term trend
    MA30 DECIMAL(18,8) NULL,                      -- MA 30 - short/medium-term trend
    MA50 DECIMAL(18,8) NULL,                      -- MA 50 - medium-term trend
    MA100 DECIMAL(18,8) NULL,                     -- MA 100 - long-term trend
    MA200 DECIMAL(18,8) NULL,                     -- MA 200 - primary trend
    
    -- Fibonacci-based MAs
    MA21_FIB DECIMAL(18,8) NULL,                  -- MA 21 - Fibonacci level
    MA55_FIB DECIMAL(18,8) NULL,                  -- MA 55 - Fibonacci level
    MA144_FIB DECIMAL(18,8) NULL,                 -- MA 144 - Fibonacci level
    MA233_FIB DECIMAL(18,8) NULL,                 -- MA 233 - Fibonacci level
    
    -- NYSE session based MAs
    MA195_NYSE DECIMAL(18,8) NULL,                -- MA 195 - NYSE session (195 trading days/year)
    MA390_NYSE DECIMAL(18,8) NULL,                -- MA 390 - NYSE session (2 years)
    MA500 DECIMAL(18,8) NULL,                     -- MA 500 - long-term institutional level
    
    CreatedDate DATETIME DEFAULT GETDATE(),
    
    -- Reference to master ticker table
    CONSTRAINT FK_MA_AssetMaster_TickerJID FOREIGN KEY (TickerJID) 
        REFERENCES ref.assetMasterTable(ID),
    
    -- Uniqueness: one bar - one MA record
    CONSTRAINT UQ_MA_Bar UNIQUE (TickerJID,TimeFrameID, BarTime)
);
GO



-- Create optimized indexes for performance
PRINT 'Creating indexes for tms.MA...';

-- Main index for queries by ticker and time
CREATE INDEX IX_MA_Ticker_TimeFrame_Time 
ON tms.MA(TickerJID, TimeFrameID, BarTime DESC)
INCLUDE (MA5, MA20, MA50, MA200);
GO

-- Index for time-based queries
CREATE INDEX IX_MA_BarTime_Desc 
ON tms.MA(BarTime DESC)
INCLUDE (TickerJID, TimeFrameID);
GO

-- Composite index for analytical queries
CREATE INDEX IX_MA_Ticker_TimeFrame_Composite 
ON tms.MA(TickerJID, TimeFrameID, BarTime DESC)
INCLUDE (MA100, MA200, MA144_FIB, MA233_FIB);
GO

-- Index for foreign key queries
CREATE INDEX IX_MA_ID 
ON tms.MA(ID)
INCLUDE (TickerJID, TimeFrameID, BarTime);
GO

-- Additional index for Fibonacci MAs
CREATE INDEX IX_MA_Fibonacci 
ON tms.MA(TickerJID, TimeFrameID)
INCLUDE (MA21_FIB, MA55_FIB, MA144_FIB, MA233_FIB, BarTime);
GO

PRINT 'All indexes created successfully!';
GO

-- Check table structure
PRINT '=== TABLE STRUCTURE ===';
SELECT 
    c.column_id,
    c.name as ColumnName,
    TYPE_NAME(c.user_type_id) as DataType,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('tms.MA')
ORDER BY c.column_id;
GO
