using cAlgo.API;
using System;
using System.Data.SqlClient;
using System.IO;
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

                //get sql script and execute it
                string sqlScript = GetSqlScript();
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

        private string GetSqlScript()
        {
            string broker = Account.BrokerName;
            string accountNumber = Account.Number.ToString();

            string sqlScript = $@"
        declare @broker VARCHAR(MAX) = '{broker.Replace("'", "''")}'
            , @account varchar(50) = '{accountNumber}';

        declare @accountID  int = trd.account_ID(@account), 
            @brokerid int  = trd.broker_id(@broker);
        select @accountID as currentAccountID, @brokerID as currentBrokerID;";

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

                using (SqlCommand command = new SqlCommand(sqlScript, connection))
                {
                    using (SqlDataReader reader = command.ExecuteReader())
                    {
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
                }
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