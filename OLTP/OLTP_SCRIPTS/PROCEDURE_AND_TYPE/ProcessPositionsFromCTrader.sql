USE [cTrader]
GO

/****** Object:  UserDefinedTableType [trd].[PositionDataTableType]    

	D:\TradingSystems\OLTP\OLTP\ProcessPositionsFromCTrader.sql
Script Date: 25.12.2025 19:40:00 ******/

if object_id('trd.ProcessPositionsFromCTrader') is not null drop proc trd.ProcessPositionsFromCTrader
if type_id('trd.PositionDataTableType') is not null drop type trd.PositionDataTableType
CREATE TYPE [trd].[PositionDataTableType] AS TABLE(
    [Id] NVARCHAR(20),
    [Symbol] NVARCHAR(50),
    [TradeType] NVARCHAR(10),
    [Volume] NVARCHAR(20),
    [EntryPrice] NVARCHAR(20),
    [CurrentPrice] NVARCHAR(20),
    [StopLoss] NVARCHAR(20),
    [TakeProfit] NVARCHAR(20),
    [GrossProfit] NVARCHAR(20),
    [NetProfit] NVARCHAR(20),
    [Swap] NVARCHAR(20),
    [Margin] NVARCHAR(20),
    [OpenTime] NVARCHAR(20),
    [Comment] NVARCHAR(MAX)
)
GO

/****** Object:  StoredProcedure [trd].[ProcessPositionsFromCTrader]    Script Date: 25.12.2025 19:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [trd].[ProcessPositionsFromCTrader]
    @positionsData [trd].[PositionDataTableType] READONLY,
    @accountNumber VARCHAR(50),
    @brokerCode VARCHAR(20),
    @brokerName NVARCHAR(100),
    @platformCode VARCHAR(20) = 'CTRADER',
    @platformName NVARCHAR(100) = 'cTrader Platform',
    @accountTypeCode VARCHAR(20) = 'STANDARD',
    @clientCode VARCHAR(20) = NULL,
    @firstName NVARCHAR(100) = NULL,
    @lastName NVARCHAR(100) = NULL,
    @email NVARCHAR(255) = NULL,
    @currencyCode CHAR(3) = 'USD',
    @serverTime DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @accountID INT;
    DECLARE @brokerID INT;
    DECLARE @platformID INT;
    DECLARE @clientID INT;
    DECLARE @currencyID INT;
    DECLARE @accountTypeID INT;
    DECLARE @transactionID UNIQUEIDENTIFIER = NEWID();
    
    -- Начало транзакции
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- 1. Получаем или создаем БРОКЕРА
        SELECT @brokerID = ID FROM trd.broker WHERE brokerCode = @brokerCode;
        
        IF @brokerID IS NULL
        BEGIN
            INSERT INTO trd.broker (brokerCode, brokerName, email)
            VALUES (@brokerCode, @brokerName, 
                    ISNULL(@email, LOWER(@brokerCode) + '@broker.com'));
            
            SET @brokerID = SCOPE_IDENTITY();
--            PRINT 'Создан новый брокер: ' + @brokerName + ' (ID: ' + CAST(@brokerID AS VARCHAR) + ')';
        END
        
        -- 2. Получаем или создаем ПЛАТФОРМУ
        SELECT @platformID = ID FROM trd.platform WHERE platformCode = @platformCode;
        
        IF @platformID IS NULL
        BEGIN
            INSERT INTO trd.platform (platformCode, platformName, platformVersion)
            VALUES (@platformCode, @platformName, '4.0');
            
            SET @platformID = SCOPE_IDENTITY();
        END
        
        -- 3. Получаем или создаем ВАЛЮТУ
        SELECT @currencyID = ID FROM trd.currency WHERE currencyCode = @currencyCode;
        
        IF @currencyID IS NULL
        BEGIN
            INSERT INTO trd.currency (currencyCode, currencyName)
            VALUES (@currencyCode, 
                    CASE @currencyCode 
                        WHEN 'USD' THEN 'US Dollar'
                        WHEN 'EUR' THEN 'Euro'
                        WHEN 'GBP' THEN 'British Pound'
                        ELSE @currencyCode
                    END);
            
            SET @currencyID = SCOPE_IDENTITY();
        END
        
        -- 4. Получаем или создаем ТИП СЧЕТА
        SELECT @accountTypeID = ID FROM trd.accountType WHERE typeCode = @accountTypeCode;
        
        IF @accountTypeID IS NULL
        BEGIN
            INSERT INTO trd.accountType (typeCode, typeName, leverage, minDeposit)
            VALUES (@accountTypeCode, 
                    CASE @accountTypeCode 
                        WHEN 'STANDARD' THEN 'Standard Account'
                        WHEN 'ECN' THEN 'ECN Account'
                        WHEN 'MICRO' THEN 'Micro Account'
                        ELSE @accountTypeCode
                    END, 
                    100.00, 100.00);
            
            SET @accountTypeID = SCOPE_IDENTITY();
        END
        
        -- 5. Получаем или создаем КЛИЕНТА (если предоставлены данные)
        IF @clientCode IS NOT NULL AND @firstName IS NOT NULL AND @lastName IS NOT NULL AND @email IS NOT NULL
        BEGIN
            SELECT @clientID = ID FROM trd.client WHERE clientCode = @clientCode;
            
            IF @clientID IS NULL
            BEGIN
                INSERT INTO trd.client (clientCode, firstName, lastName, email, phone)
                VALUES (@clientCode, @firstName, @lastName, @email, NULL);
                
                SET @clientID = SCOPE_IDENTITY();
            END
        END
        ELSE
        BEGIN
            -- Используем дефолтного клиента
            SELECT @clientID = ID FROM trd.client WHERE clientCode = 'DEFAULT';
            
            IF @clientID IS NULL
            BEGIN
                INSERT INTO trd.client (clientCode, firstName, lastName, email)
                VALUES ('DEFAULT', 'Trading', 'System', 'system@trader.com');
                
                SET @clientID = SCOPE_IDENTITY();
            END
        END
        
        -- 6. Получаем или создаем СЧЕТ
        SELECT @accountID = ID 
        FROM trd.account 
        WHERE accountNumber = @accountNumber 
          AND brokerID = @brokerID 
          AND platformID = @platformID;
        
        IF @accountID IS NULL
        BEGIN
            INSERT INTO trd.account (accountNumber, accountTypeID, platformID, brokerID, clientID, currencyID, modifiedDate)
            VALUES (@accountNumber, @accountTypeID, @platformID, @brokerID, @clientID, @currencyID, GETDATE());
            
            SET @accountID = SCOPE_IDENTITY();
            PRINT 'Создан новый счет: ' + @accountNumber + ' (ID: ' + CAST(@accountID AS VARCHAR) + ')';
        END
        ELSE
        BEGIN
            -- Обновляем дату модификации существующего счета
            UPDATE trd.account 
            SET modifiedDate = GETDATE() 
            WHERE ID = @accountID;
        END
        
        -- 7. Обрабатываем ПОЗИЦИИ
        DECLARE @positionCount INT = 0;
        DECLARE @processedCount INT = 0;
        
        SELECT @positionCount = COUNT(*) FROM @positionsData;
        PRINT 'Начинаем обработку ' + CAST(@positionCount AS VARCHAR) + ' позиций...';
        
        -- Создаем временную таблицу для хранения ID активов
        CREATE TABLE #AssetIDs (
            Symbol NVARCHAR(50),
            AssetID INT
        );
        
        -- Сначала получаем/создаем все активы
        INSERT INTO #AssetIDs (Symbol, AssetID)
        SELECT DISTINCT 
            pd.Symbol,
            ref.GetAssetID(pd.Symbol) -- Используем существующую функцию
        FROM @positionsData pd;
        
        -- Создаем недостающие активы
        INSERT INTO ref.asset (ticker, name, unit, lot_size, pip_size, created_date)
        SELECT 
            a.Symbol,
            a.Symbol,
            'PIPS',
            100000,
            0.0001,
            GETDATE()
        FROM #AssetIDs a
        WHERE a.AssetID IS NULL;
        
        -- Обновляем ID созданных активов
        UPDATE a
        SET a.AssetID = ra.ID
        FROM #AssetIDs a
        INNER JOIN ref.asset ra ON a.Symbol = ra.ticker
        WHERE a.AssetID IS NULL;
        
        -- Теперь обрабатываем каждую позицию
        DECLARE position_cursor CURSOR FOR
        SELECT 
            pd.Id,
            pd.Symbol,
            pd.TradeType,
            pd.Volume,
            pd.EntryPrice,
            pd.CurrentPrice,
            pd.StopLoss,
            pd.TakeProfit,
            pd.GrossProfit,
            pd.NetProfit,
            pd.Swap,
            pd.Margin,
            pd.OpenTime,
            pd.Comment,
            a.AssetID
        FROM @positionsData pd
        INNER JOIN #AssetIDs a ON pd.Symbol = a.Symbol;
        
        DECLARE @positionId BIGINT;
        DECLARE @symbol NVARCHAR(50);
        DECLARE @tradeType NVARCHAR(10);
        DECLARE @volume DECIMAL(18, 2);
        DECLARE @entryPrice DECIMAL(18, 5);
        DECLARE @currentPrice DECIMAL(18, 5);
        DECLARE @stopLoss DECIMAL(18, 5);
        DECLARE @takeProfit DECIMAL(18, 5);
        DECLARE @grossProfit DECIMAL(18, 2);
        DECLARE @netProfit DECIMAL(18, 2);
        DECLARE @swap DECIMAL(18, 2);
        DECLARE @margin DECIMAL(18, 2);
        DECLARE @openTime DATETIME;
        DECLARE @comment NVARCHAR(MAX);
        DECLARE @assetID INT;
        
        OPEN position_cursor;
        
        FETCH NEXT FROM position_cursor INTO 
            @positionId, @symbol, @tradeType, @volume, @entryPrice, @currentPrice,
            @stopLoss, @takeProfit, @grossProfit, @netProfit, @swap, @margin,
            @openTime, @comment, @assetID;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @direction CHAR(4);
            DECLARE @positionTicket VARCHAR(50) = CAST(@positionId AS VARCHAR(50));
            
            -- Определяем направление
            IF UPPER(@tradeType) LIKE '%BUY%'
                SET @direction = 'BUY';
            ELSE IF UPPER(@tradeType) LIKE '%SELL%'
                SET @direction = 'SELL';
            ELSE
                SET @direction = 'BUY'; -- По умолчанию
            
            -- Проверяем существование позиции
            DECLARE @existingPositionID INT;
            SELECT @existingPositionID = ID 
            FROM trd.position 
            WHERE accountID = @accountID 
                AND positionTicket = @positionTicket;
            
            IF @existingPositionID IS NULL
            BEGIN
                -- Новая позиция
                INSERT INTO trd.position (accountID, positionTicket, assetID, volume, margin, direction)
                VALUES (@accountID, @positionTicket, @assetID, @volume, @margin, @direction);
                
                SET @existingPositionID = SCOPE_IDENTITY();
                
                -- Запись об открытии
                INSERT INTO trd.positionStartFinish (positionID, openPrice, openTime, openBalance)
                VALUES (@existingPositionID, @entryPrice, @openTime, @netProfit);
                
                -- Текущее состояние
                INSERT INTO trd.positionState (positionID, timestamp, currentPrice, commission, swap)
                VALUES (@existingPositionID, 
                        ISNULL(@serverTime, GETDATE()), 
                        @currentPrice, 
                        (@grossProfit - @netProfit), 
                        @swap);
                
                SET @processedCount = @processedCount + 1;
            END
            ELSE
            BEGIN
                -- Обновляем существующую позицию
                UPDATE trd.position
                SET volume = @volume,
                    margin = @margin,
                    direction = @direction
                WHERE ID = @existingPositionID;
                
                -- Добавляем новое состояние
                INSERT INTO trd.positionState (positionID, timestamp, currentPrice, commission, swap)
                VALUES (@existingPositionID, 
                        ISNULL(@serverTime, GETDATE()), 
                        @currentPrice, 
                        (@grossProfit - @netProfit), 
                        @swap);
                
                -- Если позиция закрылась (нет в новых данных), но была в базе ранее
                -- Это нужно обрабатывать отдельно, если требуется
            END
            
            FETCH NEXT FROM position_cursor INTO 
                @positionId, @symbol, @tradeType, @volume, @entryPrice, @currentPrice,
                @stopLoss, @takeProfit, @grossProfit, @netProfit, @swap, @margin,
                @openTime, @comment, @assetID;
        END
        
        CLOSE position_cursor;
        DEALLOCATE position_cursor;
        
        -- Очищаем временные таблицы
        DROP TABLE #AssetIDs;
        
        -- 8. Обновляем информацию об аккаунте (баланс, маржа и т.д.)
        -- Здесь можно добавить расчеты на основе позиций
        -- Например: общий P&L, использованная маржа и т.д.
        
        -- 9. Логируем успешное выполнение
        INSERT INTO inf.testInfo (infMessage, modified)
        VALUES ('Processed ' + CAST(@processedCount AS VARCHAR(10)) + 
                ' positions for account ' + @accountNumber + 
                ' (Broker: ' + @brokerName + ')', GETDATE());
        
        -- Фиксируем транзакцию
        COMMIT TRANSACTION;
        
        PRINT 'Обработка завершена успешно!';
        PRINT 'Обработано позиций: ' + CAST(@processedCount AS VARCHAR(10));
        PRINT 'Номер счета: ' + @accountNumber;
        PRINT 'Брокер: ' + @brokerName;
        PRINT 'Transaction ID: ' + CAST(@transactionID AS VARCHAR(50));
        
        -- Возвращаем результат
        SELECT 
            @transactionID AS TransactionID,
            @accountID AS AccountID,
            @brokerID AS BrokerID,
            @processedCount AS PositionsProcessed,
            'SUCCESS' AS Status,
            GETDATE() AS ProcessedTime;
        
    END TRY
    BEGIN CATCH
        -- Откатываем транзакцию при ошибке
        ROLLBACK TRANSACTION;
        
        DECLARE @errorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @errorProcedure NVARCHAR(128) = ERROR_PROCEDURE();
        DECLARE @errorLine INT = ERROR_LINE();
        
        -- Логируем ошибку
        INSERT INTO inf.testInfo (infMessage, modified)
        VALUES ('ERROR in ProcessPositionsFromCTrader: ' + @errorMessage + 
                ' | Procedure: ' + ISNULL(@errorProcedure, 'N/A') + 
                ' | Line: ' + CAST(@errorLine AS VARCHAR(10)), GETDATE());
        
        -- Возвращаем ошибку
        SELECT 
            @transactionID AS TransactionID,
            NULL AS AccountID,
            NULL AS BrokerID,
            0 AS PositionsProcessed,
            'ERROR: ' + @errorMessage AS Status,
            GETDATE() AS ProcessedTime;
        
        PRINT 'Ошибка: ' + @errorMessage;
        PRINT 'Процедура: ' + ISNULL(@errorProcedure, 'N/A');
        PRINT 'Строка: ' + CAST(@errorLine AS VARCHAR(10));
    END CATCH
END
GO

/****** Object:  StoredProcedure [trd].[GetAccountInfo]    Script Date: 25.12.2025 19:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [trd].[GetAccountInfo]
    @accountNumber VARCHAR(50),
    @brokerCode VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.ID AS AccountID,
        a.accountNumber,
        at.typeCode AS AccountTypeCode,
        at.typeName AS AccountTypeName,
        p.platformCode,
        p.platformName,
        b.brokerCode,
        b.brokerName,
        c.currencyCode,
        c.currencyName,
        cl.firstName + ' ' + cl.lastName AS ClientName,
        cl.email AS ClientEmail,
        a.modifiedDate,
        (SELECT COUNT(*) FROM trd.position WHERE accountID = a.ID) AS OpenPositions
    FROM trd.account a
    LEFT JOIN trd.accountType at ON a.accountTypeID = at.ID
    LEFT JOIN trd.platform p ON a.platformID = p.ID
    LEFT JOIN trd.broker b ON a.brokerID = b.ID
    LEFT JOIN trd.currency c ON a.currencyID = c.ID
    LEFT JOIN trd.client cl ON a.clientID = cl.ID
    WHERE a.accountNumber = @accountNumber
      AND (@brokerCode IS NULL OR b.brokerCode = @brokerCode);
END
GO

/****** Object:  StoredProcedure [trd].[GetPositionSummary]    Script Date: 25.12.2025 19:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [trd].[GetPositionSummary]
    @accountNumber VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        p.ID AS PositionID,
        p.positionTicket,
        a.ticker AS Symbol,
        p.direction,
        p.volume,
        p.margin,
        psf.openPrice,
        ps.openTime,
        ps.currentPrice,
        ps.timestamp AS LastUpdate,
        (SELECT TOP 1 currentPrice FROM trd.positionState 
         WHERE positionID = p.ID ORDER BY timestamp DESC) AS LatestPrice
    FROM trd.account acc
    INNER JOIN trd.position p ON acc.ID = p.accountID
    INNER JOIN ref.asset a ON p.assetID = a.ID
    LEFT JOIN trd.positionStartFinish psf ON p.ID = psf.positionID
    LEFT JOIN (SELECT positionID, MAX(timestamp) AS maxTime 
               FROM trd.positionState GROUP BY positionID) latest 
        ON p.ID = latest.positionID
    LEFT JOIN trd.positionState ps ON p.ID = ps.positionID AND latest.maxTime = ps.timestamp
    WHERE acc.accountNumber = @accountNumber
    ORDER BY p.direction, a.ticker;
END
GO

PRINT 'Процедуры успешно созданы!';
PRINT '';
PRINT 'Структура:';
PRINT '1. Создан UserDefinedTableType: trd.PositionDataTableType';
PRINT '2. Создана процедура: trd.ProcessPositionsFromCTrader - основная процедура обработки';
PRINT '3. Создана процедура: trd.GetAccountInfo - получение информации об аккаунте';
PRINT '4. Создана процедура: trd.GetPositionSummary - сводка по позициям';
PRINT '';
PRINT 'Пример вызова из cTrader бота:';
PRINT '---------------------------------------';
PRINT 'DECLARE @positions AS trd.PositionDataTableType;';
PRINT 'INSERT INTO @positions VALUES (12345, ''EURUSD'', ''Buy'', 10000, 1.12345, 1.12500, NULL, NULL, 150, 125, 0.5, 1000, ''2025-12-25 10:00:00'', ''Test position'');';
PRINT 'EXEC trd.ProcessPositionsFromCTrader ';
PRINT '    @positionsData = @positions,';
PRINT '    @accountNumber = ''123456789'',';
PRINT '    @brokerCode = ''ICMARKETS'',';
PRINT '    @brokerName = ''IC Markets'',';
PRINT '    @clientCode = ''CLIENT001'',';
PRINT '    @firstName = ''John'',';
PRINT '    @lastName = ''Doe'',';
PRINT '    @email = ''john.doe@email.com'';';
PRINT '---------------------------------------';