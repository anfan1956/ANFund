IF TYPE_ID('trd.PositionStateTableType') IS NOT NULL
    DROP TYPE trd.PositionStateTableType
GO

CREATE TYPE trd.PositionStateTableType AS TABLE
(
    positionID INT NOT NULL,
    timestamp DATETIME NOT NULL,
    currentPrice DECIMAL(18, 5),
    commission DECIMAL(18, 2),
    swap DECIMAL(18, 2),
    stopLoss DECIMAL(18, 5) NULL,
    takeProfit DECIMAL(18, 5) NULL,
    netProfit DECIMAL(18, 2),
    grossProfit DECIMAL(18, 2)
)
GO

PRINT 'Type trd.PositionStateTableType created successfully.';