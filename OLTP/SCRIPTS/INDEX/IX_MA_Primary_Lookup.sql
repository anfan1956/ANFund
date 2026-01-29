USE cTrader
GO


--создать правильный индекс
USE cTrader
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MA_Primary_Lookup' AND object_id = OBJECT_ID('tms.MA'))
    DROP INDEX IX_MA_Primary_Lookup ON tms.MA
GO

CREATE INDEX IX_MA_Primary_Lookup 
    ON tms.MA (TickerJID, TimeFrameID, BarTime DESC)
    INCLUDE (MA5, MA20, MA50, MA100, MA200);
GO
