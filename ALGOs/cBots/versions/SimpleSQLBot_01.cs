using cAlgo.API;
using System;
using System.Data.SqlClient;

namespace SimpleSQLBot
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SimpleSQLBot : Robot
    {
        private const string ConnectionString = "Server=62.181.56.230;Database=cTrader;User Id=anfan;Password=Gisele12!;";

        protected override void OnStart()
        {
            try
            {
                SqlConnection connection = null;

                try
                {
                    connection = new SqlConnection(ConnectionString);
                    connection.Open();

                    string sql = "INSERT INTO inf.testInfo (infMessage) VALUES ('Hello again #2, World!')";

                    using (SqlCommand command = new SqlCommand(sql, connection))
                    {
                        int rowsAffected = command.ExecuteNonQuery();

                        if (rowsAffected > 0)
                        {
                            Print("record inserted");
                        }
                    }
                }
                finally
                {
                    // Explicitly close connection
                    if (connection != null && connection.State == System.Data.ConnectionState.Open)
                    {
                        connection.Close();
                        Print("connection closed");
                    }

                    if (connection != null)
                    {
                        connection.Dispose();
                    }
                }

                Print("SQL operation completed successfully");
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }

            // Stop the bot
            Print("Stopping bot...");
            Stop();
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