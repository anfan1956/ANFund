using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;


namespace SimpleSQLBot
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SimpleSQLBot : Robot
    {
        [Parameter("Time Frame", DefaultValue = "Minute")]
        public TimeFrame SelectedTimeFrame { get; set; }

        [Parameter("SL Default, %", DefaultValue = 3, MinValue = 1, Step = 1)]
        public int SlDefault { get; set; }
        [Parameter("TP Default, %", DefaultValue = 5, MinValue = 1, Step = 1)]
        public int TpDefault { get; set; }

        [Parameter("Send to SQL", DefaultValue = true)]
        public bool SendToSql { get; set; }

        [Parameter("Signal TF (ms)", DefaultValue = 500, MinValue = 100, MaxValue = 5000)]
        public int SignalTfMs { get; set; }

        private System.Threading.Timer _signalTimer;
        private volatile bool _isProcessing = false;
        private readonly object _lockObject = new();

        // ADD THESE TWO LINES HERE:
        private readonly Dictionary<long, PositionInfo> _activePositions = new();
        private readonly object _positionsLock = new();

        private const string ConnectionString = "Server=62.181.56.230;Database=cTrader;User Id=anfan;Password=Gisele12!;";
        private const string PRICE_FORMAT = "F6";
        private const string VOLUME_FORMAT = "F2";
        private DateTime _lastBarTime;
        private ConnectionManager _connectionManager;

        protected override void OnStart()
        {
            try
            {
                _connectionManager = new ConnectionManager(ConnectionString);
                _connectionManager.Open();
                Print("SQL Connection opened successfully");
            }
            catch (Exception ex)
            {
                Print($"ERROR: {ex.Message}");
                Stop();
                return;
            }


            Print($"=== POSITION LISTER STARTED ===");
            Print($"Start Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print($"Time Frame: {SelectedTimeFrame}");
            Print($"Account: {Account.Number}, Broker: {Account.BrokerName}");
            Print("");

            _lastBarTime = Server.Time;

            Print("=== BOT STARTED ===");
            ExecuteSignals();

            // Запускаем таймер сигналов
            _signalTimer = new System.Threading.Timer(
                TimerCallback,
                null,
                0,              // Начальная задержка (0 = сразу)
                SignalTfMs);    // Интервал повторения

            Print($"Signal timer started with interval: {SignalTfMs}ms");


            Print("Waiting for next bar to start processing...");
        }

        private void TimerCallback(object state)
        {
            // Защита от повторного входа
            if (_isProcessing)
            {
                return; // Пропускаем, если уже обрабатываем
            }

            lock (_lockObject)
            {
                if (_isProcessing) return;
                _isProcessing = true;
            }

            try
            {
                // Используем BeginInvokeOnMainThread для выполнения в основном потоке cAlgo
                BeginInvokeOnMainThread(() =>
                {
                    try
                    {
                        ExecuteSignals();
                        // ДОБАВЬТЕ ЭТУ СТРОКУ:
                        CheckTradingChanges();
                    }
                    catch (Exception ex)
                    {
                        Print($"Error in timer callback: {ex.Message}");
                    }
                    finally
                    {
                        _isProcessing = false;
                    }
                });
            }
            catch (Exception ex)
            {
                Print($"Error invoking on main thread: {ex.Message}");
                _isProcessing = false;
            }
        }


        private void ExecuteSignals()
        {
            try
            {
                using SqlCommand cmd = new("algo.sp_GetActiveSignal", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                using SqlDataReader reader = cmd.ExecuteReader();

                while (reader.Read())
                {
                    int signalId = Convert.ToInt32(reader[0]);
                    string ticker = Convert.ToString(reader[1]);
                    double volume = Convert.ToDouble(reader[2]);
                    string direction = Convert.ToString(reader[3]);
                    double? orderPrice = reader.IsDBNull(4) ? (double?)null : Convert.ToDouble(reader[4]);
                    double stopLoss = reader.IsDBNull(5) ? 0 : Convert.ToDouble(reader[5]);
                    double takeProfit = reader.IsDBNull(6) ? 0 : Convert.ToDouble(reader[6]);
                    Guid positionLabel = reader.GetGuid(7);
                    TradeType tradeType = direction.ToLower() == "buy" ? TradeType.Buy : TradeType.Sell;

                    PlaceOrderAsync(ticker, volume, orderPrice, stopLoss, takeProfit,
                           tradeType, signalId, positionLabel);

                }
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }
        }

        private void PlaceOrderAsync(string symbol, double volume, double? price,
                                   double stopLoss, double takeProfit,
                                   TradeType tradeType, int signalId, Guid Label)
        {
            if (!Symbols.Exists(symbol))
            {
                Print($"[{signalId}] Symbol not found");
                UpdateSignalStatus(Label, "REJECTED");
                return;
            }

            var symbolObj = Symbols.GetSymbol(symbol);
            double currentPrice = tradeType == TradeType.Buy ? symbolObj.Bid : symbolObj.Ask;
            double volumeUnits = symbolObj.QuantityToVolumeInUnits(volume);
            Print($"double volumeUnites: {volumeUnits}");

            void callback(TradeResult result)
            {
                if (result.IsSuccessful)
                {
                    string execType = result.PendingOrder != null ? "order" : "position";
                    string execId = result.PendingOrder?.Id.ToString() ?? result.Position?.Id.ToString();

                    Print($"=== TradeResult Callback ===");
                    Print($"UUID: {Label}, Success: {result.IsSuccessful}");

                    if (result.Position != null)
                    {
                        Print($"Position opened: ID={result.Position.Id}");
                        // ДОБАВЬТЕ ЭТУ СТРОЧКУ:
                        TrackNewPosition(result.Position, Label);
                    }

                    if (result.PendingOrder != null)
                    {
                        Print($"PendingOrder created: ID={result.PendingOrder.Id}");
                    }

                    // Вызываем с UUID вместо signalId
                    UpdateSignalStatus(Label, "ACCEPTED", execType, execId);
                }
                else
                {
                    Print($"=== TradeResult FAILED ===");
                    Print($"UUID: {Label}, Error: {result.Error}");

                    // Вызываем с UUID вместо signalId
                    UpdateSignalStatus(Label, "REJECTED");
                }
            }

            double ThePrice = tradeType == TradeType.Buy ? symbolObj.Bid : symbolObj.Ask;
            double slPips = stopLoss > 0 ? Math.Abs(ThePrice - stopLoss) / symbolObj.PipSize : ThePrice * SlDefault /100/ symbolObj.PipSize ;
            double tpPips = takeProfit > 0 ? Math.Abs(takeProfit - currentPrice) / symbolObj.PipSize : ThePrice * TpDefault /100/ symbolObj.PipSize;
            double priceDiff = price.HasValue ? Math.Abs(price.Value - currentPrice) : 0;
            double minDiff = symbolObj.PipSize * 2;
            string PositionLabel = Label.ToString();

            if (price == null || priceDiff < minDiff)
            {
                Print($"[{PositionLabel}] NULL or less then mindif price detected, placing MARKET ORDER");
                ExecuteMarketOrderAsync(tradeType, symbol, volumeUnits,
                                      $"{PositionLabel}", slPips, tpPips, callback);
            }
            else
            {
                if ((tradeType == TradeType.Buy && price.Value < currentPrice) ||
                         (tradeType == TradeType.Sell && price.Value > currentPrice))
                {
                    PlaceLimitOrderAsync(tradeType, symbol, volumeUnits, price.Value,
                                       $"{PositionLabel}", stopLoss, takeProfit,
                                       ProtectionType.Absolute, callback);
                }
                else
                {
                    PlaceStopOrderAsync(tradeType, symbol, volumeUnits, price.Value,
                                      $"{PositionLabel}", stopLoss, takeProfit,
                                      ProtectionType.Absolute, callback);
                }
            }
        }

        private void UpdateSignalStatus(Guid uuid, string status,
                               string executionType = null, string executionId = null)
        {
            try
            {
                using SqlCommand cmd = new("algo.sp_ProcessSignal", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                // Теперь основной параметр - @uuid, а не @signalID
                cmd.Parameters.AddWithValue("@uuid", uuid.ToString());
                cmd.Parameters.AddWithValue("@status", status);
                cmd.Parameters.AddWithValue("@executionType", executionType ?? (object)DBNull.Value);
                cmd.Parameters.AddWithValue("@executionID", executionId ?? (object)DBNull.Value);

                cmd.ExecuteNonQuery();
                Print($"[Signal {uuid}] Status updated: {status}");
            }
            catch (Exception ex)
            {
                Print($"[Signal {uuid}] SQL error: {ex.Message}");
            }
        }

        protected override void OnBar()
        {
            Print($"New Bar Started: ");
            try
            {
                DateTime currentBarTime = Server.Time;
                Print($"New Bar Started: {currentBarTime}");

                // Process on every new bar
                if (currentBarTime > _lastBarTime)
                {
                    Print($"=== PROCESSING BAR: {currentBarTime:yyyy-MM-dd HH:mm:ss} ===");
                    Print($"Time Frame: {SelectedTimeFrame}");

                    ProcessDataCollection();

                    _lastBarTime = currentBarTime;
                    //ExecuteSignals();

                    Print($"=== BAR PROCESSING COMPLETED ===");
                    Print("");


                }
            }
            catch (Exception ex)
            {
                Print($"Error in OnBar: {ex.Message}");
            }
        }

        protected override void OnTick()
        {
            //try
            //{
            //    ExecuteSignals();
            //}
            //catch (Exception ex)
            //{
            //    Print($"Error in onTick{ex.Message}");
            //}
        }


        private void ProcessDataCollection()
        {
            try
            {
                // 1. COLLECT EQUITY DATA (simple addition)
                CollectEquityData();

                // Get current positions
                var positions = Positions.ToArray();

                // Get and execute SQL script
                if (SendToSql && positions.Length > 0)
                {
                    string sqlScript = GetSqlScript(positions);
                    //Print($"sqlScript: {sqlScript}");
                    ExecuteSql(sqlScript);
                }
                else if (positions.Length == 0)
                {
                    Print("No positions to process");
                }
                else
                {
                    Print("SQL integration disabled");
                }

                Print("Data collection completed");
            }
            catch (Exception ex)
            {
                Print($"Error in ProcessDataCollection: {ex.Message}");
            }
        }

        private void CollectEquityData()
        {
            try
            {
                // Get account data
                var accountData = GetSqlAccountData();

                // Get current equity values
                decimal equity = (decimal)Account.Equity;
                decimal marginUsed = (decimal)Account.Margin;
                decimal marginFree = (decimal)Account.FreeMargin;
                decimal marginLevel = Account.MarginLevel > 0 ? (decimal)Account.MarginLevel / 100 : 0;


                // Create SQL script
                string sqlScript = GetEquitySqlScript(accountData, equity, marginUsed, marginFree, marginLevel);

                // Execute the SQL
                ExecuteSql(sqlScript);

                Print($"Equity collected: {equity:F2}");
            }
            catch (Exception ex)
            {
                Print($"Error collecting equity: {ex.Message}");
            }
        }

        private static string GetTradingPositions(Position[] positions)
        {
            StringBuilder sqlValues = new();

            // Add header row
            sqlValues.AppendLine("('Id','Symbol','TradeType','Volume','EntryPrice','CurrentPrice','StopLoss','TakeProfit','GrossProfit','NetProfit','Swap','Margin','Commission','OpenTime','Comment'), ");
          
            // Add position data
            for (int i = 0; i < positions.Length; i++)
            {
                var position = positions[i];
                string openTime = position.EntryTime.ToString("yyyy-MM-dd:HH:mm:ss");

                sqlValues.Append($"('{position.Id}',");
                sqlValues.Append($"'{position.SymbolName?.Replace("'", "''") ?? ""}',");
                sqlValues.Append($"'{position.TradeType}',");
                sqlValues.Append($"'{position.VolumeInUnits:F2}',");
                sqlValues.Append($"'{position.EntryPrice:F5}',");
                sqlValues.Append($"'{position.CurrentPrice:F5}',");
                sqlValues.Append($"'{position.StopLoss?.ToString("F5") ?? ""}',");
                sqlValues.Append($"'{position.TakeProfit?.ToString("F5") ?? ""}',");
                sqlValues.Append($"'{position.GrossProfit:F2}',");
                sqlValues.Append($"'{position.NetProfit:F2}',");
                sqlValues.Append($"'{position.Swap:F2}',");
                sqlValues.Append($"'{position.Margin:F2}',");
                sqlValues.Append($"'{position.Commissions:F2}',");
                sqlValues.Append($"'{openTime}',");
                sqlValues.Append($"'{position.Comment?.Replace("'", "''") ?? ""}')");

                if (i < positions.Length - 1)
                    sqlValues.AppendLine(", ");
                else
                    sqlValues.AppendLine();
            }
            
            return sqlValues.ToString();
        }

        private SqlAccountData GetSqlAccountData()
        {
            return new SqlAccountData
            {
                Broker = Account.BrokerName,
                AccountNumber = Account.Number.ToString(),
                PlatformCode = "cTrader",
                PlatformVersion = PlatformVersion
            };
        }

        private static string PlatformVersion
        {
            get
            {
                try
                {
                    // cAlgo doesn't have a direct property for platform version
                    // You might need to hardcode this or find another way to get it
                    // For now, we'll use a placeholder
                    return "5.5.13.46616"; // Example version from your SQL script
                }
                catch
                {
                    return "Unknown";
                }
            }
        }

        private string GetSqlScript(Position[] positions)
        {
            var accountData = GetSqlAccountData();

            // Get the SQL VALUES string from positions
            string positionsValues = GetTradingPositions(positions);

            string sqlScript = $@"
        declare @positions trd.PositionDataTableType
        insert into @positions values 
        {positionsValues}
        
        declare @broker VARCHAR(MAX) = '{accountData.Broker.Replace("'", "''")}'
            , @account varchar(50) = '{accountData.AccountNumber}'
            , @platformCode NVARCHAR(20) = '{accountData.PlatformCode}'
            , @platformVersion NVARCHAR(20) = '{accountData.PlatformVersion}';

        declare @accountID  int = trd.account_ID(@account, @broker, @platformCode, @platformVersion);
        
        select @accountID as currentAccountID;
        
        exec trd.positions_p @positions, @broker, @account, @platformCode, @platformVersion;";

            // Print the complete SQL script
            //Print("=== SQL SCRIPT ===");
            //Print(sqlScript);
            //Print("==================");

            return sqlScript;
        }

        private static string GetEquitySqlScript(SqlAccountData accountData, decimal amount, decimal marginUsed, decimal marginFree, decimal marginLevel)
        {
            string sqlScript = $@"
        exec fin.equity_p 
            @account = '{accountData.AccountNumber}'
            , @broker = '{accountData.Broker.Replace("'", "''")}'
            , @platformCode = '{accountData.PlatformCode}'
            , @platformVersion = '{accountData.PlatformVersion}'
            , @amount = {amount:F2}
            , @marginUsed = {marginUsed:F2}
            , @marginFree = {marginFree:F2}
            , @marginLevel = {marginLevel:F6};";

            return sqlScript;
        }

        private void ExecuteSql(string sqlScript)
        {
            if (_connectionManager == null)
            {
                Print("Connection manager not initialized");
                return;
            }

            try
            {
                using SqlCommand command = new(sqlScript, _connectionManager.GetConnection());
                using SqlDataReader reader = command.ExecuteReader();
                //Print($"sqlScript: {sqlScript}");
                Print("=== DATASET RESULTS ===");

                if (reader.HasRows)
                {
                    int fieldCount = reader.FieldCount;
                    string[] columnNames = new string[fieldCount];
                    for (int i = 0; i < fieldCount; i++)
                    {
                        columnNames[i] = reader.GetName(i);
                    }

                    Print($"Columns: {string.Join(", ", columnNames)}");
                    Print("------------------");

                    int rowNumber = 0;
                    while (reader.Read())
                    {
                        rowNumber++;
                        string rowData = $"Row {rowNumber}: ";
                        for (int i = 0; i < fieldCount; i++)
                        {
                            object value = reader[i];
                            rowData += $"{columnNames[i]} = {value}, ";
                        }
                        Print(rowData.TrimEnd(',', ' '));
                    }

                    Print($"Total rows: {rowNumber}");
                }
                else
                {
                    Print("No rows returned");
                }

                Print("=====================");
            }
            catch (Exception ex)
            {
                Print($"Error executing SQL: {ex.Message}");
            }
        }

        private void CheckTradingChanges()
        {
    try
    {
        lock (_positionsLock)
        {
            // Get all positions currently open in cTrader
            var currentPositions = Positions.ToDictionary(p => p.Id);
            
            // Find positions we're tracking that are no longer in cTrader
            var positionsToRemove = new List<long>();
            
            foreach (var kvp in _activePositions)
            {
                var positionId = kvp.Key;
                var positionInfo = kvp.Value;


                        int currentPositionId = (int)positionId;
                        if (!currentPositions.ContainsKey(currentPositionId))
                        {
                    // Position was closed
                    positionsToRemove.Add(positionId);
                    
                    // Determine closure reason
                    var closureReason = GetClosureReason(positionInfo);
                    
                    // Log closure to SQL
                    LogTradeEvent(positionInfo, closureReason, "Close");
                    
                    Print($"Position {positionId} closed. Reason: {closureReason}");
                }
            }
            
            // Remove closed positions from tracking
            foreach (var positionId in positionsToRemove)
            {
                _activePositions.Remove(positionId);
            }
        }
    }
    catch (Exception ex)
    {
        Print($"Error checking closed positions: {ex.Message}");
    }
}

        private void TrackNewPosition(Position position, Guid label)
        {
            lock (_positionsLock)
            {
                if (!_activePositions.ContainsKey(position.Id))
                {
                    var positionInfo = new PositionInfo
                    {
                        PositionId = position.Id,
                        Label = label,
                        Symbol = position.SymbolName,
                        TradeType = position.TradeType,
                        EntryPrice = position.EntryPrice,
                        Volume = position.VolumeInUnits,
                        EntryTime = position.EntryTime,
                        StopLoss = position.StopLoss,
                        TakeProfit = position.TakeProfit
                    };

                    _activePositions[position.Id] = positionInfo;

                    Print($"Started tracking position {position.Id} with label {label}");

                    // Log opening event
                    LogTradeEvent(positionInfo, "Open", "Open");
                }
            }
        }
        private string GetClosureReason(PositionInfo positionInfo)
        {
            try
            {
                Position foundPosition = null;
                foreach (Position pos in Positions)
                {
                    if (pos.Id == positionInfo.PositionId)
                    {
                        foundPosition = pos;
                        break;
                    }
                }

                // If position not found in current positions, it's closed
                if (foundPosition == null)
                {
                    return "CLOSED";
                }

                // Get symbol for pip calculations
                var symbol = Symbols.GetSymbol(foundPosition.SymbolName);
                if (symbol == null) return "UNKNOWN";

                double pipSize = symbol.PipSize;

                // Check if it was stopped out
                if (foundPosition.StopLoss.HasValue)
                {
                    double difference = Math.Abs(positionInfo.EntryPrice - foundPosition.CurrentPrice);
                    double slDifference = Math.Abs(positionInfo.EntryPrice - foundPosition.StopLoss.Value);

                    // If price is close to stop loss, assume SL was hit
                    if (Math.Abs(difference - slDifference) <= pipSize * 2)
                    {
                        return "STOP_LOSS";
                    }
                }

                // Check if take profit was hit
                if (foundPosition.TakeProfit.HasValue)
                {
                    double difference = Math.Abs(positionInfo.EntryPrice - foundPosition.CurrentPrice);
                    double tpDifference = Math.Abs(positionInfo.EntryPrice - foundPosition.TakeProfit.Value);

                    if (Math.Abs(difference - tpDifference) <= pipSize * 2)
                    {
                        return "TAKE_PROFIT";
                    }
                }

                // Check gross profit for manual closure
                if (foundPosition.GrossProfit > 0)
                    return "MANUAL_CLOSE_PROFIT";
                else if (foundPosition.GrossProfit < 0)
                    return "MANUAL_CLOSE_LOSS";

                return "MANUAL_CLOSE";
            }
            catch (Exception)
            {
                return "UNKNOWN";
            }
        }
        private void LogTradeEvent(PositionInfo positionInfo, string eventType, string category)
        {
            try
            {
                double price = 0;
                double volume = positionInfo.Volume;
                string profitXml = "<Profit></Profit>";

                if (category == "Close")
                {
                    // For close events, get data from history
                    HistoricalTrade closedTrade = null;
                    foreach (HistoricalTrade trade in History)
                    {
                        if (trade.PositionId == positionInfo.PositionId)
                        {
                            closedTrade = trade;
                            break;
                        }
                    }

                    if (closedTrade == null)
                    {
                        Print($"No historical trade found for position {positionInfo.PositionId}");
                        return;
                    }

                    price = closedTrade.ClosingPrice;

                    // Prepare profit XML for close events
                    profitXml = $@"<Profit>
    <Gross>{closedTrade.GrossProfit:F2}</Gross>
    <Net>{closedTrade.NetProfit:F2}</Net>
    <Swap>{closedTrade.Swap:F2}</Swap>
    <Commission>{closedTrade.Commissions:F2}</Commission>
</Profit>";
                }
                else if (category == "Open")
                {
                    // For open events, use entry price
                    price = positionInfo.EntryPrice;
                }

                // Determine correct values for SQL tables
                string tradeTypeName = "marketOrder"; // Always market order for this bot
                string sqlEventName = category == "Open" ? "Signal" : ConvertClosureReason(eventType);
                string direction = positionInfo.TradeType == TradeType.Buy ? "long" : "short";

                // Create DataTable for trade events - NEW structure without currencyID
                DataTable eventsTable = new ();
                eventsTable.Columns.Add("tradeUUID", typeof(Guid));
                eventsTable.Columns.Add("eventName", typeof(string));
                eventsTable.Columns.Add("category", typeof(string));
                eventsTable.Columns.Add("direction", typeof(string));
                eventsTable.Columns.Add("accountNumber", typeof(string));
                eventsTable.Columns.Add("brokerName", typeof(string));
                eventsTable.Columns.Add("platformCode", typeof(string));
                eventsTable.Columns.Add("platformVersion", typeof(string));
                eventsTable.Columns.Add("symbol", typeof(string));
                eventsTable.Columns.Add("volume", typeof(decimal));
                eventsTable.Columns.Add("price", typeof(decimal));
                eventsTable.Columns.Add("slPrice", typeof(decimal));
                eventsTable.Columns.Add("tpPrice", typeof(decimal));
                eventsTable.Columns.Add("tradeTypeName", typeof(string));
                eventsTable.Columns.Add("profitInfo", typeof(string));

                DataRow row = eventsTable.NewRow();
                row["tradeUUID"] = positionInfo.Label;
                row["eventName"] = sqlEventName;
                row["category"] = category;
                row["direction"] = direction;
                row["accountNumber"] = Account.Number.ToString();
                row["brokerName"] = Account.BrokerName;
                row["platformCode"] = "cTrader";
                row["platformVersion"] = PlatformVersion;
                // currencyID removed
                row["symbol"] = positionInfo.Symbol;
                row["volume"] = Convert.ToDecimal(volume);
                row["price"] = Convert.ToDecimal(price);
                row["slPrice"] = positionInfo.StopLoss.HasValue ?
                    Convert.ToDecimal(positionInfo.StopLoss.Value) : 0;
                row["tpPrice"] = positionInfo.TakeProfit.HasValue ?
                    Convert.ToDecimal(positionInfo.TakeProfit.Value) : 0;
                row["tradeTypeName"] = tradeTypeName;
                row["profitInfo"] = profitXml;

                eventsTable.Rows.Add(row);

                // Call the stored procedure
                using SqlCommand cmd = new("algo.sp_LogTradeEvents", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter param = cmd.Parameters.AddWithValue("@events", eventsTable);
                param.SqlDbType = SqlDbType.Structured;
                param.TypeName = "algo.TradeEventTableType";

                int rowsAffected = cmd.ExecuteNonQuery();
                Print($"Logged trade event for position {positionInfo.PositionId}: {category} - {sqlEventName}, rows affected: {rowsAffected}");
            }
            catch (Exception ex)
            {
                Print($"Error logging trade event: {ex.Message}");
            }
        }

        private static string ConvertClosureReason(string closureReason)
        {
            // Convert bot closure reason to SQL event names
            return closureReason switch
            {
                "STOP_LOSS" => "StopLoss",
                "TAKE_PROFIT" => "TakeProfit",
                "MANUAL_CLOSE_PROFIT" => "ManualClose",
                "MANUAL_CLOSE_LOSS" => "ManualClose",
                "MANUAL_CLOSE" => "ManualClose",
                "CLOSED" => "ManualClose", // Default for closed positions
                _ => "ManualClose"
            };
        }

        private double GetFinalProfitForPosition(long positionId)
        {
            try
            {
                // Ищем позицию в истории торгов
                foreach (HistoricalTrade trade in History)
                {
                    if (trade.PositionId == positionId)
                    {
                        return trade.NetProfit;
                    }
                }

                return 0;
            }
            catch (Exception)
            {
                return 0;
            }
        }
        protected override void OnStop()
        {
            if (_connectionManager != null)
            {
                _connectionManager.Close();
                Print("SQL Connection closed");
            }
            Print("=== POSITION LISTER STOPPED ===");
            Print($"Stop Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print("=================================");

            _signalTimer?.Dispose();

        }
    }

    public class SqlAccountData
    {
        public string Broker { get; set; }
        public string AccountNumber { get; set; }
        public string PlatformCode { get; set; }
        public string PlatformVersion { get; set; }
    }
    // Добавьте этот класс в конце файла (после класса SqlAccountData)

    public class SqlSignal
    {
        public int SignalID { get; set; }
        public string Ticker { get; set; }
        public double Volume { get; set; }
        public string Direction { get; set; }
        public double OrderPrice { get; set; }
        public double? StopLoss { get; set; }
        public double? TakeProfit { get; set; }
        public DateTime SignalTime { get; set; }
        public string Status { get; set; }
        public DateTime? Expiry { get; set; }
    }
    // Add this class AFTER SqlSignal class

    public class PositionInfo
    {
        public long PositionId { get; set; }
        public Guid Label { get; set; }
        public string Symbol { get; set; }
        public TradeType TradeType { get; set; }
        public double EntryPrice { get; set; }
        public double Volume { get; set; }
        public DateTime EntryTime { get; set; }
        public double? StopLoss { get; set; }
        public double? TakeProfit { get; set; }
        public string Status { get; set; } = "OPEN";
    }

    public class ConnectionManager
    {
        private SqlConnection _connection;
        private readonly string _connectionString;

        public ConnectionManager(string connectionString)
        {
            _connectionString = connectionString;
        }

        public SqlConnection GetConnection()
        {
            if (_connection == null || _connection.State != ConnectionState.Open)
            {
                // Open if not already open
                Open();
            }
            return _connection;
        }

        public void Open()
        {
            try
            {
                _connection = new SqlConnection(_connectionString);
                _connection.Open();
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to open SQL connection: {ex.Message}");
            }
        }

        public void Close()
        {
            if (_connection != null)
            {
                if (_connection.State == ConnectionState.Open)
                {
                    _connection.Close();
                }
                _connection.Dispose();
                _connection = null;
            }
        }
    }
}









