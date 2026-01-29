-- Check if column exists and add if not
IF OBJECT_ID('algo.tradingSignals') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.columns 
        WHERE object_id = OBJECT_ID('algo.tradingSignals') 
        AND name = 'signalTypeID'
    )
    BEGIN
        ALTER TABLE [algo].[tradingSignals]
        ADD signalTypeID INT NULL
        
        PRINT 'Column signalTypeID added to algo.tradingSignals'
    END
    ELSE
    BEGIN
        PRINT 'Column signalTypeID already exists in algo.tradingSignals'
    END
END
ELSE
BEGIN
    PRINT 'Table algo.tradingSignals does not exist'
END
GO

-- Add foreign key constraint if column exists
IF OBJECT_ID('algo.tradingSignals') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM sys.columns 
        WHERE object_id = OBJECT_ID('algo.tradingSignals') 
        AND name = 'signalTypeID'
    )
    BEGIN
        IF NOT EXISTS (
            SELECT 1 
            FROM sys.foreign_keys 
            WHERE parent_object_id = OBJECT_ID('algo.tradingSignals')
            AND name = 'FK_tradingSignals_signalTypeID'
        )
        BEGIN
            ALTER TABLE [algo].[tradingSignals]
            ADD CONSTRAINT FK_tradingSignals_signalTypeID 
            FOREIGN KEY (signalTypeID) REFERENCES [algo].[strategySignalType](ID)
            
            PRINT 'Foreign key FK_tradingSignals_signalTypeID added'
        END
        ELSE
        BEGIN
            PRINT 'Foreign key FK_tradingSignals_signalTypeID already exists'
        END
    END
END
GO