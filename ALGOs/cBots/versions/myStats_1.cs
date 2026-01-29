using cAlgo.API;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;


namespace myStats
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class PositionLister : Robot
    {
        [Parameter("Auto Export", DefaultValue = true)]
        public bool AutoExport { get; set; }

        [Parameter("Print to Log", DefaultValue = true)]
        public bool PrintToLog { get; set; }

        [Parameter("API URL", DefaultValue = "http://localhost:5066")]
        public string ApiUrl { get; set; }

        [Parameter("Send to API", DefaultValue = false)]
        public bool SendToApi { get; set; }

        private readonly string baseExportPath = @"D:\TradingSystems\fanfanTrader\AlgoExport";

        protected override void OnStart()
        {
            Print("=== POSITION LISTER STARTED ===");
            Print($"Start Time: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            Print("");

            try
            {
                // 1. Connect to API
                Print("1. Connecting to API...");
                var (success, statusCode, body) = ConnectToApi();
                Print($"   API Response Status: {statusCode}");

                // 2. Request signals from API
                Print("2. Requesting signals from API...");
                var apiCommands = GetApiCommands();

                // 3. Write commands to .csv file
                Print("3. Writing received commands to CSV file...");
                ExportApiCommandsToFile(apiCommands);

                // 4. Log commands
                Print("4. Logging received commands:");
                LogApiCommands(apiCommands);

                // 5. Read existing positions
                Print("5. Reading existing positions...");
                var positions = Positions.ToArray();

                // 6. Write positions to .csv file
                Print("6. Writing positions to CSV file...");
                ExportPositionsToFile(positions);

                // 7. Log positions
                Print("7. Logging positions:");
                LogPositions(positions);

                // 8. Write account information to separate file
                Print("8. Writing account information to file...");
                ExportAccountInfoToFile();

                // 9. Log account information
                Print("9. Logging account information:");
                LogAccountInfo();

                Print("");
                Print("=== ALL TASKS COMPLETED SUCCESSFULLY ===");
            }
            catch (Exception ex)
            {
                Print($"=== ERROR: {ex.Message} ===");
                Print($"Stack Trace: {ex.StackTrace}");
            }

            Print("");
            Print("=== POSITION LISTER FINISHED ===");

            // 10. Stop the bot
            Stop();
        }

        private (bool success, string statusCode, string body) ConnectToApi()
        {
            try
            {
                var request = new HttpRequest(new Uri($"{ApiUrl}/api/Trading"))
                {
                    Method = HttpMethod.Get
                };

                var response = Http.Send(request);
                return (response.IsSuccessful, response.StatusCode.ToString(), response.Body);
            }
            catch (Exception ex)
            {
                return (false, "ERROR", ex.Message);
            }
        }

        private List<ApiCommand> GetApiCommands()
        {
            var commands = new List<ApiCommand>();

            try
            {
                var request = new HttpRequest(new Uri($"{ApiUrl}/api/Trading"))
                {
                    Method = HttpMethod.Get
                };

                var response = Http.Send(request);

                if (response.IsSuccessful && !string.IsNullOrEmpty(response.Body))
                {
                    Print($"   Data received: {response.Body.Length} characters");

                    // Parse JSON response
                    try
                    {
                        commands = JsonConvert.DeserializeObject<List<ApiCommand>>(response.Body);
                        Print($"   Commands found: {commands?.Count ?? 0}");
                    }
                    catch (JsonException jsonEx)
                    {
                        Print($"   JSON parsing error: {jsonEx.Message}");
                        // Create one command with raw data
                        commands.Add(new ApiCommand
                        {
                            Id = 0,
                            Symbol = "RAW_DATA",
                            Quantity = 0,
                            Price = 0,
                            Side = "INFO",
                            Status = response.Body.Length > 100 ? string.Concat(response.Body.AsSpan(0, 100), "...") : response.Body
                        });
                    }
                }
                else
                {
                    Print($"   Error receiving commands: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Print($"   Error requesting commands: {ex.Message}");
            }

            return commands;
        }

        private void ExportApiCommandsToFile(List<ApiCommand> commands)
        {
            try
            {
                string fileName = $"API_Commands_{Account.Number}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string folderPath = Path.Combine(baseExportPath, "API Commands");
                string filePath = Path.Combine(folderPath, fileName);

                // Create directory if it doesn't exist
                Directory.CreateDirectory(Path.GetDirectoryName(filePath));

                using (var writer = new StreamWriter(filePath, false, Encoding.UTF8))
                {
                    // CSV header
                    writer.WriteLine("CommandID,Symbol,Quantity,Price,Side,Status,ReceiveTime");

                    // Data
                    foreach (var cmd in commands)
                    {
                        writer.WriteLine(
                            $"{cmd.Id}," +
                            $"{cmd.Symbol}," +
                            $"{cmd.Quantity}," +
                            $"{cmd.Price:F2}," +
                            $"{cmd.Side}," +
                            $"{cmd.Status}," +
                            $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}"
                        );
                    }
                }

                Print($"   Commands saved to: {filePath}");
            }
            catch (Exception ex)
            {
                Print($"   Error saving commands: {ex.Message}");
            }
        }

        private void LogApiCommands(List<ApiCommand> commands)
        {
            if (commands == null || commands.Count == 0)
            {
                Print("   No commands received from API");
                return;
            }

            Print("   ==============================================================");
            Print("   |                    RECEIVED COMMANDS                      |");
            Print("   |------------------------------------------------------------|");
            Print("   | Id      | Symbol  | Quantity | Price    | Side    | Status|");
            Print("   |------------------------------------------------------------|");

            foreach (var cmd in commands)
            {
                Print($"   | {cmd.Id,-7} | {cmd.Symbol,-7} | {cmd.Quantity,8} | {cmd.Price,8:F2} | {cmd.Side,-7} | {cmd.Status,-6} |");
            }

            Print("   ==============================================================");
        }

        private void ExportPositionsToFile(Position[] positions)
        {
            try
            {
                string fileName = $"Positions_{Account.Number}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string folderPath = Path.Combine(baseExportPath, "Positions");
                string filePath = Path.Combine(folderPath, fileName);

                // Create directory if it doesn't exist
                Directory.CreateDirectory(Path.GetDirectoryName(filePath));

                using (var writer = new StreamWriter(filePath, false, Encoding.UTF8))
                {
                    // CSV header
                    writer.WriteLine("Id,Symbol,TradeType,Volume,EntryPrice,CurrentPrice,StopLoss,TakeProfit,GrossProfit,NetProfit,Swap,Margin,OpenTime,Comment");

                    // Data
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

        private void LogPositions(Position[] positions)
        {
            Print($"   Total positions: {positions.Length}");

            if (positions.Length == 0)
            {
                Print("   No open positions");
                return;
            }

            Print("   ===================================================================================");
            Print("   |                              OPEN POSITIONS                                    |");
            Print("   |--------------------------------------------------------------------------------|");
            Print("   | Id      | Symbol  | Type | Volume  | Entry Price | Cur. Price | P&L   | Margin|");
            Print("   |--------------------------------------------------------------------------------|");

            foreach (var position in positions)
            {
                string tradeTypeStr = position.TradeType.ToString();
                string tradeTypeShort = tradeTypeStr.Length > 4 ? tradeTypeStr.Substring(0, 4) : tradeTypeStr;

                Print($"   | {position.Id,-7} | {position.SymbolName,-7} | {tradeTypeShort,-4} | {position.VolumeInUnits,7:F2} | {position.EntryPrice,11:F5} | {position.CurrentPrice,10:F5} | {position.NetProfit,5:F2} | {position.Margin,6:F2} |");
            }

            Print("   ===================================================================================");

            // Summary
            Print($"   Total P&L: {positions.Sum(p => p.NetProfit):F2}");
            Print($"   Total margin: {positions.Sum(p => p.Margin):F2}");
        }

        private void ExportAccountInfoToFile()
        {
            try
            {
                string fileName = $"AccountInfo_{Account.Number}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string folderPath = Path.Combine(baseExportPath, "Account Info");
                string filePath = Path.Combine(folderPath, fileName);

                // Create directory if it doesn't exist
                Directory.CreateDirectory(Path.GetDirectoryName(filePath));

                using (var writer = new StreamWriter(filePath, false, Encoding.UTF8))
                {
                    writer.WriteLine("Parameter,Value,ExportTime");
                    writer.WriteLine($"AccountNumber,{Account.Number},{DateTime.Now:yyyy-MM-dd HH:mm:ss}");
                    writer.WriteLine($"Broker,{Account.BrokerName},");
                    writer.WriteLine($"Balance,{Account.Balance:F2},");
                    writer.WriteLine($"Equity,{Account.Equity:F2},");
                    writer.WriteLine($"FreeMargin,{Account.FreeMargin:F2},");
                    writer.WriteLine($"UsedMargin,{Account.Margin:F2},");
                    writer.WriteLine($"MarginLevel,{Account.MarginLevel:F2}%,");
                    writer.WriteLine($"Currency,{Account.Asset.Name},");
                    writer.WriteLine($"AccountType,{Account.AccountType},");
                    writer.WriteLine($"Leverage,{Account.PreciseLeverage},");
                    writer.WriteLine($"PositionsCount,{Positions.Count},");
                    writer.WriteLine($"PendingOrdersCount,{PendingOrders.Count},");
                    writer.WriteLine($"UserId,{Account.UserId},");
                    writer.WriteLine($"ServerTime,{Server.Time:yyyy-MM-dd HH:mm:ss},");
                    writer.WriteLine($"TimeZone,{TimeZoneInfo.Local.DisplayName},");
                }

                Print($"   Account information saved to: {filePath}");
            }
            catch (Exception ex)
            {
                Print($"   Error saving account information: {ex.Message}");
            }
        }


        private void LogAccountInfo()
        {
            Print("   ==============================================================");
            Print("   |                    ACCOUNT INFORMATION                     |");
            Print("   |------------------------------------------------------------|");
            Print($"   | Account Number: {Account.Number,-45} |");
            Print($"   | Broker: {Account.BrokerName,-50} |");
            Print($"   | Balance: {Account.Balance,-48:F2} |");
            Print($"   | Equity: {Account.Equity,-48:F2} |");
            Print($"   | Free Margin: {Account.FreeMargin,-42:F2} |");
            Print($"   | Used Margin: {Account.Margin,-42:F2} |");
            Print($"   | Margin Level: {Account.MarginLevel,-43:F2}% |");
            Print($"   | Currency: {Account.Asset.Name,-46} |");
            Print($"   | Leverage: {Account.PreciseLeverage,-47} |");
            Print($"   | Open Positions: {Positions.Count,-42} |");
            Print($"   | Pending Orders: {PendingOrders.Count,-42} |");
            Print("   ==============================================================");
        }

        protected override void OnStop()
        {
            Print("Position Lister stopped");
        }

        // Class for API command deserialization
        public class ApiCommand
        {
            public int Id { get; set; }
            public string Symbol { get; set; }
            public int Quantity { get; set; }
            public double Price { get; set; }
            public string Side { get; set; }
            public string Status { get; set; }
        }
    }
}