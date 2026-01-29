using cAlgo.API;
using System;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;

namespace SimpleSQLBot
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SimpleSQLBot : Robot
    {
        private const string ConnectionString = "Server=62.181.56.230;Database=cTrader;User Id=anfan;Password=Gisele12!;";

        private readonly string baseExportPath = @"D:\TradingSystems\fanfanTrader\AlgoExport";
        protected override void OnStart()
        {
            try
            {
                // 1. Write account information to separate file
                Print("1. Writing account information to file...");
                ExportAccountInfoToFile();

                // Get positions
                var positions = Positions.ToArray();

                // Export to CSV (keep existing functionality)
                ExportPositionsToFile(positions);

                // Get and execute SQL script
                string sqlScript = GetSqlScript(positions);
                ExecuteSql(sqlScript);
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }

            Print("Stopping bot...");
            Stop();
        }

        //private string GetSqlScript()
        //{
        //    return @"
        //        INSERT INTO inf.testInfo (infMessage)
        //        VALUES ('Message # ' + CAST(NEXT VALUE FOR inf.testSequence AS NVARCHAR(50)))
        //        select @@ROWCOUNT as rowsInserted;";
        //}

        private string GetSqlScript(Position[] positions)
        {
            string broker = Account.BrokerName;
            string accountNumber = Account.Number.ToString();

            // Get the SQL VALUES string from positions
            string positionsValues = GetTradingPositions(positions);

            string sqlScript = $@"
        declare @positions trd.PositionDataTableType
        insert into @positions values 
        {positionsValues}
        
        declare @broker VARCHAR(MAX) = '{broker.Replace("'", "''")}'
            , @account varchar(50) = '{accountNumber}';

        declare @accountID  int = trd.account_ID(@account), 
            @brokerid int  = trd.broker_id(@broker);
        
        select @accountID as currentAccountID, @brokerID as currentBrokerID;
        
        exec trd.positions_p @positions, @broker, @account;";

            // Print the complete SQL script
            Print("=== SQL SCRIPT ===");
            Print(sqlScript);
            Print("==================");

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

        private void ExportPositionsToFile(Position[] positions)
        {
            try
            {
                string fileName = $"Positions_{Account.Number}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string folderPath = Path.Combine(baseExportPath, "Positions");
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

        protected override void OnTick()
        {
            // This bot only runs once on start
        }

        protected override void OnStop()
        {
            Print("SimpleSQLBot stopped");
        }
    }
}