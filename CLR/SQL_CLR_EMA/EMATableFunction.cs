using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class EMATableFunction
{
    private class EMAResult
    {
        public DateTime BarTime { get; set; }
        public double CloseValue { get; set; }
        public double EMA_5_SHORT { get; set; }
        public double EMA_9_MACD_SIGNAL { get; set; }
        public double EMA_20_SHORT { get; set; }
        public double EMA_50_MEDIUM { get; set; }
    }

    [SqlFunction(
        DataAccess = DataAccessKind.Read,
        FillRowMethodName = "FillRow",
        TableDefinition = "BarTime datetime, CloseValue float, EMA_5_SHORT float, EMA_9_MACD_SIGNAL float, EMA_20_SHORT float, EMA_50_MEDIUM float")]
    public static IEnumerable CalculateMultipleEMASeries(
        SqlInt32 tickerJID,
        SqlInt32 timeframeID,
        SqlDateTime fromTime)
    {
        var results = new List<EMAResult>();

        using (var connection = new System.Data.SqlClient.SqlConnection("context connection=true"))
        {
            connection.Open();

            string query = @"
                SELECT BarTime, CloseValue 
                FROM tms.bars
                WHERE TickerJID = @tickerJID 
                  AND timeframeID = @timeframeID
                  AND BarTime >= @fromTime
                ORDER BY BarTime";

            using var command = new System.Data.SqlClient.SqlCommand(query, connection);
            command.Parameters.AddWithValue("@tickerJID", tickerJID.Value);
            command.Parameters.AddWithValue("@timeframeID", timeframeID.Value);
            command.Parameters.AddWithValue("@fromTime", fromTime.Value);

            using var reader = command.ExecuteReader();
            double ema5 = 0, ema9 = 0, ema20 = 0, ema50 = 0;
            double alpha5 = 2.0 / (5 + 1);
            double alpha9 = 2.0 / (9 + 1);
            double alpha20 = 2.0 / (20 + 1);
            double alpha50 = 2.0 / (50 + 1);
            bool firstRow = true;

            while (reader.Read())
            {
                DateTime barTime = (DateTime)reader["BarTime"];
                double closeValue = Convert.ToDouble(reader["CloseValue"]);

                if (firstRow)
                {
                    ema5 = closeValue;
                    ema9 = closeValue;
                    ema20 = closeValue;
                    ema50 = closeValue;
                    firstRow = false;
                }
                else
                {
                    ema5 = (closeValue * alpha5) + (ema5 * (1 - alpha5));
                    ema9 = (closeValue * alpha9) + (ema9 * (1 - alpha9));
                    ema20 = (closeValue * alpha20) + (ema20 * (1 - alpha20));
                    ema50 = (closeValue * alpha50) + (ema50 * (1 - alpha50));
                }

                results.Add(new EMAResult
                {
                    BarTime = barTime,
                    CloseValue = closeValue,
                    EMA_5_SHORT = Math.Round(ema5, 8),
                    EMA_9_MACD_SIGNAL = Math.Round(ema9, 8),
                    EMA_20_SHORT = Math.Round(ema20, 8),
                    EMA_50_MEDIUM = Math.Round(ema50, 8)
                });
            }
        }

        return results;
    }

    public static void FillRow(
        object obj,
        out SqlDateTime barTime,
        out SqlDouble closeValue,
        out SqlDouble ema_5_short,
        out SqlDouble ema_9_macd_signal,
        out SqlDouble ema_20_short,
        out SqlDouble ema_50_medium)
    {
        EMAResult result = (EMAResult)obj;
        barTime = new SqlDateTime(result.BarTime);
        closeValue = new SqlDouble(result.CloseValue);
        ema_5_short = new SqlDouble(result.EMA_5_SHORT);
        ema_9_macd_signal = new SqlDouble(result.EMA_9_MACD_SIGNAL);
        ema_20_short = new SqlDouble(result.EMA_20_SHORT);
        ema_50_medium = new SqlDouble(result.EMA_50_MEDIUM);
    }
}