use cTrader
GO

if OBJECT_ID('fin.equity') is not null drop table fin.equity
go
create Table fin.equity (
    ID int not null IDENTITY PRIMARY KEY,
    accountID int not null CONSTRAINT fk_account_equity FOREIGN key REFERENCES trd.account (ID),
    amount money not null, 
    equityDate DATETIME NOT NULL DEFAULT(GETDATE()), 
    marginUsed money,
    marginFree money,
    marginLevel NUMERIC (18, 6)
)
GO


if OBJECT_ID('fin.equity_p') is not null drop PROC fin.equity_p
GO
create PROCEDURE fin.equity_p 
     @account NVARCHAR(50)                  -- account number in our case
    , @broker NVARCHAR(100)                  -- Pepperstone in our case
    , @platformCode NVARCHAR(20)            -- cTrader
    , @platformVersion NVARCHAR(20)         -- 5.5.13.46616
    , @amount money
    , @marginUsed money
    , @marginFree money
    , @marginLevel NUMERIC (18, 6)
as
BEGIN
    declare 
    @accountID int = trd.Account_id(@account, @broker, @platformCode, @platformVersion);
    BEGIN try
        insert  into fin.equity (accountID, amount, marginUsed, marginFree, marginLevel)
        VALUES (@accountID, @amount, @marginUsed, @marginFree, @marginLevel)
        select 'success'
    end try
    BEGIN catch 
        select ERROR_MESSAGE();
    end catch
END
go

declare 
      @account NVARCHAR(50)                 -- account number in our case
    , @broker NVARCHAR(100)                 -- Pepperstone in our case
    , @platformCode NVARCHAR(20)            -- cTrader
    , @platformVersion NVARCHAR(20)         -- 5.5.13.46616
    , @amount money
    , @marginUsed money
    , @marginFree money
    , @marginLevel NUMERIC (18, 6)

exec fin.equity_p       
        @account 
        , @broker 
        , @platformCode
        , @platformVersion
        , @amount 
        , @marginUsed
        , @marginFree
        , @marginLevel