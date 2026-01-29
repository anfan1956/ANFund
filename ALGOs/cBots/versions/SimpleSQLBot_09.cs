using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;

namespace SimpleSQLBot
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SimpleSQLBot : Robot
    {
        [Parameter("Time Frame", DefaultValue = "Minute")]
        public TimeFrame SelectedTimeFrame { get; set; }

        [Parameter("Send to SQL", DefaultValue = true)]
        public bool SendToSql { get; set; }

        private const string ConnectionString = "Server=62.181.56.230;Database=cTrader;User Id=anfan;Password=Gisele12!;";
        private const string PRICE_FORMAT = "F6";
        private const string VOLUME_FORMAT = "F2";

        private DateTime _lastBarTime;

        protected override void OnStart()
        {
            Print($"=== POSITION LISTER STARTED ===");
            Print($"Start Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print($"Time Frame: {SelectedTimeFrame}");
            Print($"Account: {Account.Number}, Broker: {Account.BrokerName}");
            Print("");

            _lastBarTime = Server.Time;

            Print("=== BOT STARTED ===");
            ExecuteSignals();


        Print("Waiting for next bar to start processing...");
        }
        private void ExecuteSignals()
        {
            try
            {
                using SqlConnection conn = new(ConnectionString);
                conn.Open();

                using SqlCommand cmd = new("algo.sp_GetActiveSignal", conn);
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                using SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    int signalId = Convert.ToInt32(reader[0]);
                    string ticker = Convert.ToString(reader[1]);
                    double volume = Convert.ToDouble(reader[2]);
                    string direction = Convert.ToString(reader[3]);
                    double orderPrice = Convert.ToDouble(reader[4]);
                    double stopLoss = Convert.ToDouble(reader[5]);
                    double takeProfit = Convert.ToDouble(reader[6]);

                    //Print($"[{signalId}] Found: {ticker} {direction} {orderPrice:F5}");

                    TradeType tradeType = direction.ToLower() == "buy" ? TradeType.Buy : TradeType.Sell;

                    PlaceOrderAsync(ticker, volume, orderPrice, stopLoss, takeProfit,
                                   tradeType, signalId);
                }

                //Print("All signals processing started");
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }
        }

        private void PlaceOrderAsync(string symbol, double volume, double price,
                                   double stopLoss, double takeProfit,
                                   TradeType tradeType, int signalId)
        {
            if (!Symbols.Exists(symbol))
            {
                Print($"[{signalId}] Symbol not found");
                UpdateSignalStatus(signalId, "REJECTED");
                return;
            }

            var symbolObj = Symbols.GetSymbol(symbol);
            double currentPrice = tradeType == TradeType.Buy ? symbolObj.Bid : symbolObj.Ask;
            long volumeUnits = (long)symbolObj.QuantityToVolumeInUnits(volume);

            double priceDiff = Math.Abs(price - currentPrice);
            double minDiff = symbolObj.PipSize * 2;

            // Callback для обновления статуса
            void callback(TradeResult result)
            {
                if (result.IsSuccessful)
                {
                    string execType = result.PendingOrder != null ? "order" : "position";
                    string execId = result.PendingOrder?.Id.ToString() ?? result.Position?.Id.ToString();
                    UpdateSignalStatus(signalId, "ACCEPTED", execType, execId);
                }
                else
                {
                    UpdateSignalStatus(signalId, "REJECTED");
                }
            }

            if (priceDiff < minDiff)
            {
                ExecuteMarketOrderAsync(tradeType, symbol, volumeUnits,
                                      $"Signal_{signalId}", stopLoss, takeProfit, callback);
            }
            else if ((tradeType == TradeType.Buy && price < currentPrice) ||
                     (tradeType == TradeType.Sell && price > currentPrice))
            {
                PlaceLimitOrderAsync(tradeType, symbol, volumeUnits, price,
                                   $"Signal_{signalId}", stopLoss, takeProfit,
                                   ProtectionType.Absolute, callback);
            }
            else
            {
                PlaceStopOrderAsync(tradeType, symbol, volumeUnits, price,
                                  $"Signal_{signalId}", stopLoss, takeProfit,
                                  ProtectionType.Absolute, callback);
            }
        }

        private void UpdateSignalStatus(int signalId, string status,
                               string executionType = null, string executionId = null)
        {
            try
            {
                using SqlConnection conn = new(ConnectionString);
                conn.Open();

                using SqlCommand cmd = new("algo.sp_ProcessSignal", conn);
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@signalID", signalId);
                cmd.Parameters.AddWithValue("@status", status);
                cmd.Parameters.AddWithValue("@executionType", executionType ?? (object)DBNull.Value);
                cmd.Parameters.AddWithValue("@executionID", executionId ?? (object)DBNull.Value);

                cmd.ExecuteNonQuery();
                Print($"[Signal {signalId}] Status: {status}");
            }
            catch (Exception ex)
            {
                Print($"[Signal {signalId}] SQL error: {ex.Message}");
            }
        }

        protected override void OnBar()
        {
            try
            {
                DateTime currentBarTime = Server.Time;

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
            try
            {
                ExecuteSignals();
            }
            catch (Exception ex) 
            {
                Print($"Error in onTick{ex.Message}");
            }
            
        }


        private void ProcessDataCollection()
        {
            try
            {
                // 1. COLLECT EQUITY DATA (simple addition)
                CollectEquityData();

                // Get current positions
                var positions = Positions.ToArray();

                // Export to CSV
                ExportPositionsToFile(positions);

                // Get and execute SQL script
                if (SendToSql && positions.Length > 0)
                {
                    string sqlScript = GetSqlScript(positions);
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

        private void ExportPositionsToFile(Position[] positions)
        {
            try
            {
                string fileName = $"Positions_{Account.Number}_{Server.Time:yyyyMMdd_HHmmss}.csv";
                string folderPath = @"D:\TradingSystems\AlgoExport\Positions";
                string filePath = Path.Combine(folderPath, fileName);

                Directory.CreateDirectory(Path.GetDirectoryName(filePath));

                using (var writer = new StreamWriter(filePath, false, Encoding.UTF8))
                {
                    writer.WriteLine("Id,Symbol,TradeType,Volume,EntryPrice,CurrentPrice,StopLoss,TakeProfit,GrossProfit,NetProfit,Swap,Margin,Commission,OpenTime,Comment");

                    foreach (var position in positions)
                    {
                        writer.WriteLine(
                            $"{position.Id}," +
                            $"{position.SymbolName}," +
                            $"{position.TradeType}," +
                            $"{position.VolumeInUnits:F2}," +
                            $"{position.EntryPrice:F5}," +
                            $"{position.CurrentPrice:F5}," +
                            $"{(position.StopLoss.HasValue ? position.StopLoss.Value.ToString("F5") : "")}," +
                            $"{(position.TakeProfit.HasValue ? position.TakeProfit.Value.ToString("F5") : "")}," +
                            $"{position.GrossProfit:F2}," +
                            $"{position.NetProfit:F2}," +
                            $"{position.Swap:F2}," +
                            $"{position.Margin:F2}," +
                            $"{position.Commissions:F2}," +
                            $"{position.EntryTime:yyyy-MM-dd HH:mm:ss}," +
                            $"\"{position.Comment?.Replace("\"", "\"\"") ?? ""}\""
                        );
                    }
                }

                Print($"   Positions saved to: {filePath}");
            }
            catch (Exception ex)
            {
                Print($"   Error saving positions: {ex.Message}");
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
            Print("=== SQL SCRIPT ===");
            Print(sqlScript);
            Print("==================");

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
            SqlConnection connection = null;

            try
            {
                connection = new SqlConnection(ConnectionString);
                connection.Open();
                Print("Connection opened");

                using SqlCommand command = new(sqlScript, connection);
                using SqlDataReader reader = command.ExecuteReader();
                // Print dataset header
                Print("=== DATASET RESULTS ===");

                if (reader.HasRows)
                {
                    // Get column names
                    int fieldCount = reader.FieldCount;
                    string[] columnNames = new string[fieldCount];
                    for (int i = 0; i < fieldCount; i++)
                    {
                        columnNames[i] = reader.GetName(i);
                    }

                    // Print column names
                    Print($"Columns: {string.Join(", ", columnNames)}");
                    Print("------------------");

                    // Print rows
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
            finally
            {
                if (connection != null)
                {
                    if (connection.State == System.Data.ConnectionState.Open)
                    {
                        connection.Close();
                        Print("Connection closed");
                    }
                    connection.Dispose();
                }
            }
        }

        

        protected override void OnStop()
        {
            Print("=== POSITION LISTER STOPPED ===");
            Print($"Stop Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print("=================================");
        }

    }
    // Helper class to hold SQL account data
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
}

