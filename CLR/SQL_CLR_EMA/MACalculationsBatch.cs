using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class MACalculationsBatch
{
    [SqlFunction(
        DataAccess = DataAccessKind.Read,
        FillRowMethodName = "FillRowMA",
        TableDefinition = "BarID bigint, TickerJID int, TimeFrameID int, BarTime datetime, " +
                 "MA5 decimal(18,8), MA8 decimal(18,8), MA20 decimal(18,8), " +
                 "MA30 decimal(18,8), MA50 decimal(18,8), MA100 decimal(18,8), " +
                 "MA200 decimal(18,8), MA500 decimal(18,8), MA21_FIB decimal(18,8), " +
                 "MA55_FIB decimal(18,8), MA144_FIB decimal(18,8), MA233_FIB decimal(18,8), " +
                 "MA195_NYSE decimal(18,8), MA390_NYSE decimal(18,8)",
        IsDeterministic = false,
        IsPrecise = false,
        SystemDataAccess = SystemDataAccessKind.None)]

    public static IEnumerable CalculateAllMASeriesBatch(
    SqlInt32 timeGap,
    SqlInt32 filterTimeframeID,
    SqlInt32 filterTickerJID)
    {
        List<MABatchResult> results = new(1000000);

        try
        {
            using SqlConnection connection = new("context connection=true");
            connection.Open();

            string barsQuery = BuildBarsQueryMA(timeGap, filterTimeframeID, filterTickerJID);

            using SqlCommand cmdBars = new(barsQuery, connection);
            AddQueryParametersMA(cmdBars, timeGap, filterTimeframeID, filterTickerJID);
            cmdBars.CommandTimeout = 0;

            using SqlDataReader readerBars = cmdBars.ExecuteReader();

            // Периоды MA
            int[] periods = [5, 8, 20, 30, 50, 100, 200, 500, 21, 55, 144, 233, 195, 390];

            // Предварительно рассчитываем 1/period для ускорения (умножение быстрее деления)
            decimal[] periodReciprocals = new decimal[periods.Length];
            for (int i = 0; i < periods.Length; i++)
            {
                periodReciprocals[i] = 1.0m / periods[i];
            }

            // Используем List вместо Queue - быстрее для доступа по индексу
            Dictionary<(int, int), List<decimal>> priceHistory = [];
            Dictionary<(int, int), decimal[]> currentMAs = [];
            Dictionary<(int, int), decimal[]> periodSums = []; // Храним суммы для каждого периода
            Dictionary<(int, int), int[]> periodCounts = [];   // Текущее количество элементов для каждого периода

            while (readerBars.Read())
            {
                long barID = readerBars.GetInt64(0);
                int tickerID = readerBars.GetInt32(1);
                int tfID = readerBars.GetInt32(2);
                DateTime barTime = readerBars.GetDateTime(3);

                decimal closeValue = 0;
                if (!readerBars.IsDBNull(4))
                {
                    object value = readerBars.GetValue(4);
                    closeValue = Convert.ToDecimal(value);
                }

                var groupKey = (tickerID, tfID);

                // Инициализируем структуры для группы
                if (!priceHistory.TryGetValue(groupKey, out List<decimal> history))
                {
                    history = new List<decimal>(500); // Предварительный размер
                    priceHistory[groupKey] = history;
                    currentMAs[groupKey] = new decimal[periods.Length];
                    periodSums[groupKey] = new decimal[periods.Length];
                    periodCounts[groupKey] = new int[periods.Length];
                }

                // Добавляем текущую цену в историю
                history.Add(closeValue);

                // Обновляем суммы и счетчики для каждого периода
                decimal[] sums = periodSums[groupKey];
                int[] counts = periodCounts[groupKey];
                decimal[] maValues = currentMAs[groupKey];

                for (int i = 0; i < periods.Length; i++)
                {
                    int period = periods[i];

                    // Обновляем счетчик (но не больше периода)
                    if (counts[i] < period)
                    {
                        counts[i]++;
                    }

                    // Добавляем новое значение к сумме
                    sums[i] += closeValue;

                    // Если история превысила период, вычитаем самое старое значение
                    if (history.Count > period)
                    {
                        // Получаем значение, которое выходит из окна
                        decimal oldValue = history[history.Count - period - 1];
                        sums[i] -= oldValue;
                    }

                    // Рассчитываем MA через умножение (быстрее чем деление)
                    maValues[i] = sums[i] / counts[i]; // Или: sums[i] * periodReciprocals[i] если periods фиксированы
                }

                // Ограничиваем размер истории (храним только последние 500 значений)
                if (history.Count > 500)
                {
                    history.RemoveAt(0);
                }

                results.Add(new MABatchResult
                {
                    BarID = barID,
                    TickerJID = tickerID,
                    TimeframeID = tfID,
                    BarTime = barTime,
                    CloseValue = closeValue,
                    MA5 = maValues[0],
                    MA8 = maValues[1],
                    MA20 = maValues[2],
                    MA30 = maValues[3],
                    MA50 = maValues[4],
                    MA100 = maValues[5],
                    MA200 = maValues[6],
                    MA500 = maValues[7],
                    MA21_FIB = maValues[8],
                    MA55_FIB = maValues[9],
                    MA144_FIB = maValues[10],
                    MA233_FIB = maValues[11],
                    MA195_NYSE = maValues[12],
                    MA390_NYSE = maValues[13]
                });
            }
        }
        catch (Exception ex)
        {
            SqlContext.Pipe?.Send($"Error in CalculateAllMASeriesBatch: {ex.Message}");
            throw;
        }

        return results;
    }

    private static string BuildBarsQueryMA(SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        string query = @"
            SELECT 
                b.ID as BarID,
                b.TickerJID,
                b.timeframeID,
                b.BarTime,
                b.CloseValue
            FROM tms.bars b
            WHERE 1=1";

        if (!timeGap.IsNull)
            query += " AND b.BarTime > DATEADD(MINUTE, -@timeGap, GETUTCDATE())";

        if (!filterTimeframeID.IsNull)
            query += " AND b.timeframeID = @filterTimeframeID";

        if (!filterTickerJID.IsNull)
            query += " AND b.TickerJID = @filterTickerJID";

        query += " ORDER BY b.TickerJID, b.timeframeID, b.BarTime";

        return query;
    }

    private static void AddQueryParametersMA(SqlCommand command, SqlInt32 timeGap,
                                           SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        if (!timeGap.IsNull)
            command.Parameters.AddWithValue("@timeGap", timeGap.Value);

        if (!filterTimeframeID.IsNull)
            command.Parameters.AddWithValue("@filterTimeframeID", filterTimeframeID.Value);

        if (!filterTickerJID.IsNull)
            command.Parameters.AddWithValue("@filterTickerJID", filterTickerJID.Value);
    }

    public static void FillRowMA(
        object obj,
        out SqlInt64 BarID,
        out SqlInt32 tickerJID,
        out SqlInt32 timeframeID,
        out SqlDateTime barTime,
        out SqlDecimal ma5,
        out SqlDecimal ma8,
        out SqlDecimal ma20,
        out SqlDecimal ma30,
        out SqlDecimal ma50,
        out SqlDecimal ma100,
        out SqlDecimal ma200,
        out SqlDecimal ma500,
        out SqlDecimal ma21_fib,
        out SqlDecimal ma55_fib,
        out SqlDecimal ma144_fib,
        out SqlDecimal ma233_fib,
        out SqlDecimal ma195_nyse,
        out SqlDecimal ma390_nyse)
    {
        MABatchResult result = (MABatchResult)obj;

        BarID = result.BarID;
        tickerJID = result.TickerJID;
        timeframeID = result.TimeframeID;
        barTime = result.BarTime;
        ma5 = result.MA5;
        ma8 = result.MA8;
        ma20 = result.MA20;
        ma30 = result.MA30;
        ma50 = result.MA50;
        ma100 = result.MA100;
        ma200 = result.MA200;
        ma500 = result.MA500;
        ma21_fib = result.MA21_FIB;
        ma55_fib = result.MA55_FIB;
        ma144_fib = result.MA144_FIB;
        ma233_fib = result.MA233_FIB;
        ma195_nyse = result.MA195_NYSE;
        ma390_nyse = result.MA390_NYSE;
    }

    private class MABatchResult
    {
        public long BarID { get; set; }
        public int TickerJID { get; set; }
        public int TimeframeID { get; set; }
        public DateTime BarTime { get; set; }
        public decimal CloseValue { get; set; }
        public decimal MA5 { get; set; }
        public decimal MA8 { get; set; }
        public decimal MA20 { get; set; }
        public decimal MA30 { get; set; }
        public decimal MA50 { get; set; }
        public decimal MA100 { get; set; }
        public decimal MA200 { get; set; }
        public decimal MA500 { get; set; }
        public decimal MA21_FIB { get; set; }
        public decimal MA55_FIB { get; set; }
        public decimal MA144_FIB { get; set; }
        public decimal MA233_FIB { get; set; }
        public decimal MA195_NYSE { get; set; }
        public decimal MA390_NYSE { get; set; }
    }
}