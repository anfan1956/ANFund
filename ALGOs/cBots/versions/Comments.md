**SymbolExporter.cs**

Импортирует символы из cTrader

| Ticker   | OriginalSymbol              | Unit | LotSize | PipSize |
|:---------|:----------------------------|:----:|:-------:|:-------:|
| BNZL.L   | Bunzl_(BNZL.L)              | EUR  | 1       | 0       |
| BRBY.L   | Burberry_Group_(BRBY.L)     | EUR  | 1       | 0       |
| BWP.AX   | BWP_Trust_(BWP.AX)          | USD  | 1       | 0       |
| COK.DE   | Cancom_SE_(COK.DE)          | EUR  | 1       | 0       |


**SimpeSQLBot**
Makes SQL connection to cTrader and insert 
a record into inf.testInfo "Hello again, World!"


**SimpleSQLBot_2**
Makes a connection and runs the query
declare @broker VARCHAR(MAX) = <account.broker>
    , @account varchar(50) = <account.accountNumber>;

declare @accountID  int = trd.account_ID(@account), 
	@brokerid int  = trd.broker_id(@broker);
select @accountID as currentAccountID, @brokerID as currentBrokerID

**SimpleSQLBot_3**
Creates connection, extracts positions and parses it over the tables

**SimpleSQLBot_4**

Добавлен метод OnBar, каждуй бар передает данные о позиции
Перестает при выключении бота

**SimpleSQLBot_5**
helper class AccountData
collect and post equity, netProfit, grossProfit added to positionState

**SimpleSQLBot_6**
added methods to place order


