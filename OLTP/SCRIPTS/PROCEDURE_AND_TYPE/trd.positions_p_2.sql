use cTrader
go

if OBJECT_ID('trd.positions_p') is not null drop PROCEDURE trd.positions_p
if type_id('trd.PositionDataTableType') is not null drop type trd.PositionDataTableType
go

CREATE TYPE [trd].[PositionDataTableType] AS TABLE(
    [positionLabel] UNIQUEIDENTIFIER, -- UUID из Label
    [positionTicket] NVARCHAR(20),    -- Ticket из cTrader
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
    [Commission] NVARCHAR(20),
    [OpenTime] NVARCHAR(20)
    -- Comment удален
)
go

CREATE PROCEDURE trd.positions_p 
    @positions trd.PositionDataTableType READONLY
    , @broker VARCHAR(max)
    , @account VARCHAR(max)
    , @platformCode NVARCHAR(20)
as
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @accountID int = trd.account_ID(@account, @broker, @platformCode);

BEGIN TRY
    BEGIN TRANSACTION
    
    -- 1. Вставляем/обновляем позиции
    ;with s (accountID, positionLabel, positionTicket, assetID, volume, margin, direction, openTime, openPrice) as (
        select @accountID, p.positionLabel, p.positionTicket, sm.assetID, p.Volume, p.Margin, p.TradeType
            , try_cast(stuff(p.OpenTime, 11, 1, ' ') as datetime)
            , p.EntryPrice
        from @positions p
            join ref.SymbolMapping sm on sm.Symbol = p.Symbol
    )
    merge trd.POSITION as t using s
    on  1=1
        and t.positionLabel = s.positionLabel
        and t.accountid = s.accountid
        and t.assetID = s.assetID
    when not MATCHed then 
        insert (accountID, positionLabel, positionTicket, assetID, volume, margin, direction, openTime, openPrice)
        VALUES (accountID, positionLabel, positionTicket, assetID, volume, margin, direction, openTime, openPrice)
    when MATCHED then
        update set
            positionTicket = s.positionTicket,
            volume = s.volume,
            margin = s.margin,
            openPrice = s.openPrice;

    -- 2. Записываем состояние позиций
    ;with s (positionID, currentPrice, commission, swap, stopLoss, takeProfit, netProfit, grossProfit) as (
        select pn.ID, p.CurrentPrice, p.Commission, p.Swap, p.StopLoss, p.TakeProfit, p.NetProfit, p.GrossProfit
        from @positions p
            join trd.position pn on pn.positionLabel = p.positionLabel 
                and pn.accountID = @accountID
                and pn.closeTime IS NULL -- Только открытые позиции
    )
    insert into trd.positionState (positionID, currentPrice, commission, swap, stopLoss, takeProfit, netProfit, grossProfit)
    select 
        positionID,
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(currentPrice)), ''),'.') AS NUMERIC(18,6)),
        COALESCE(TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(commission)), ''), '.') AS NUMERIC(18,6)), 0),
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(swap)), ''),'.') AS NUMERIC(18,6)),
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(stopLoss)), ''),'.') AS NUMERIC(18,6)),
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(takeProfit)), ''),'.') AS NUMERIC(18,6)),
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(netProfit)), ''),'.') AS money),
        TRY_CAST(NULLIF(NULLIF(LTRIM(RTRIM(grossProfit)), ''),'.') AS money)
    from s;

    -- 3. ОЧИСТКА: Удаляем историю закрытых позиций
    DELETE ps
    FROM trd.positionState ps
    INNER JOIN trd.POSITION p ON p.ID = ps.positionID
    WHERE p.accountID = @accountID
      AND p.closeTime IS NOT NULL;  -- Только закрытые позиции
    
    -- Можно также удалить сами закрытые позиции из trd.POSITION если они больше не нужны
    -- DELETE FROM trd.POSITION WHERE accountID = @accountID AND closeTime IS NOT NULL;

    COMMIT TRANSACTION;
    
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
        
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    
    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    RETURN -1;
END CATCH;
GO



-- Сначала удалить positionState, потом position
--DELETE FROM trd.positionState;
--DELETE FROM trd.position;


---- Тестовый вызов
--declare @positions trd.PositionDataTableType
--insert into @positions values 
--('11111111-2222-3333-4444-555555555555', '179365202', 'NAS100', 'Buy', '0.1', '25306.4', '25683.5', '', '', '37.71', '31.65', '-6.06', '126.53', '', '2025-12-12:15:29:12')

--declare @broker VARCHAR(MAX) = 'Pepperstone'
--    , @account varchar(50) = '5161801'
--    , @platformCode NVARCHAR(20) = 'cTrader'
--    , @platformVersion NVARCHAR(20) = '5.5.13.46616';

--declare @accountID  int = trd.account_ID(@account, @broker, @platformCode, @platformVersion);
    
--select @accountID as currentAccountID;

--exec trd.positions_p @positions, @broker, @account, @platformCode, @platformVersion;

--select * from trd.position;
--select * from trd.positionState;