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
                using SqlConnection connection = new(ConnectionString);
                connection.Open();

                string sql = "INSERT INTO inf.testInfo (infMessage) VALUES ('Hello again, World!')";

                using SqlCommand command = new(sql, connection);
                int rowsAffected = command.ExecuteNonQuery();

                if (rowsAffected > 0)
                {
                    Print("record inserted");
                }
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }
        }

        protected override void OnTick()
        {
            // This bot only runs once on start
        }

        protected override void OnStop()
        {
            // Cleanup if needed
        }
    }
}