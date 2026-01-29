**SymbolExporter.cs**

Импортирует символы из cTrader

| Ticker | OriginalSymbol          | Unit | LotSize | PipSize |
| :----- | :---------------------- | :--: | :-----: | :-----: |
| BNZL.L | Bunzl\_(BNZL.L)         | EUR  |    1    |    0    |
| BRBY.L | Burberry*Group*(BRBY.L) | EUR  |    1    |    0    |
| BWP.AX | BWP*Trust*(BWP.AX)      | USD  |    1    |    0    |
| COK.DE | Cancom*SE*(COK.DE)      | EUR  |    1    |    0    |

**SimpeSQLBot**
Makes SQL connection to cTrader and insert
a record into inf.testInfo "Hello again, World!"

**SimpleSQLBot_2**
Makes a connection and runs the query
declare @broker VARCHAR(MAX) = <account.broker>
, @account varchar(50) = <account.accountNumber>;

declare @accountID int = trd.account_ID(@account),
@brokerid int = trd.broker_id(@broker);
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

**SimpleSQLBot_7**
думаю, что то же . последняя работающая версия

**SimpleSQLBot_08**
working version: Takes multisignal from SQL and places order onStart()

**SimpleSQLBot_09**
working: takes multisignal from SQL and places order onTick()

**SimpleSQLBot_10**
w: takes multisygnal from SQL, openes single thread connection and places order onTick()

**SimpleSQLBot_11**
loging opening and closing positions
Stopped before modifying.

**SimpleSQLBot_12**
1 accountinfo
2.positions
3.equity
4.executes trades on signals
5.logs tradeevents

**SimpleSQLBot_13**
1 accountinfo
2.positions - корректция - только открытые позиции. модифицирована процедура trd.positions_p_2.sql
3.equity
4.executes trades on signals
5.logs tradeevents

**SimpleSQLBot_14**
all events with positions and orders

**SimpleSQLBot_15**
all events with positions and orders 
collect historical data for the second timeframe
update data on new bar
