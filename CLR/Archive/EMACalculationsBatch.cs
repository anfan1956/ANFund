using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class EMACalculationsBatch
{
    /// <summary>
    /// Пакетный расчет всех EMA для таблицы tms.EMA
    /// </summary>
    [SqlFunction(
    DataAccess = DataAccessKind.Read,
    FillRowMethodName = "FillRowBatch",
    TableDefinition = "TickerJID int, TimeFrameID int, BarTime datetime, " +
                 "EMA_5_SHORT decimal(18,8), EMA_9_MACD_SIGNAL decimal(18,8), " +
                 "EMA_12_MACD_FAST decimal(18,8), EMA_20_SHORT decimal(18,8), " +
                 "EMA_26_MACD_SLOW decimal(18,8), EMA_50_MEDIUM decimal(18,8), " +
                 "EMA_100_LONG decimal(18,8), EMA_200_LONG decimal(18,8), " +
                 "EMA_21_FIBO decimal(18,8), EMA_55_FIBO decimal(18,8), " +
                 "EMA_144_FIBO decimal(18,8), EMA_233_FIBO decimal(18,8), " +
                 "EMA_8_SHORT decimal(18,8)", 
    IsDeterministic = false,
    IsPrecise = false,
    SystemDataAccess = SystemDataAccessKind.None)]
    public static IEnumerable CalculateAllEMASeriesBatch(
    SqlInt32 timeGap,
    SqlInt32 filterTimeframeID,
    SqlInt32 filterTickerJID,
    SqlBoolean useExistingEMA)
    {
        List<EMABatchResult> results = [];

        try
        {
            using SqlConnection connection = new("context connection=true");
            connection.Open();

            // ВАЖНО: Проверка логики при useExistingEMA = 0
            if (useExistingEMA.IsFalse)
            {
                // При useExistingEMA = 0 должны быть указаны все фильтры как NULL
                // для полного пересчета всей таблицы
                if (!timeGap.IsNull || !filterTimeframeID.IsNull || !filterTickerJID.IsNull)
                {
                    SqlContext.Pipe?.Send("Warning: When useExistingEMA = 0, all filters should be NULL for full table recalculation.");
                }
            }

            // Словарь для хранения последних EMA из таблицы tms.EMA
            Dictionary<string, decimal[]> lastEMAsFromTable = [];

            if (useExistingEMA.IsTrue)
            {
                // Запрос для получения последних EMA из tms.EMA для каждой группы
                string getLastEMAQuery = @"
                        WITH LastEMA AS (
                            SELECT 
                                TickerJID,
                                TimeFrameID,
                                EMA_5_SHORT,
                                EMA_9_MACD_SIGNAL,
                                EMA_12_MACD_FAST,
                                EMA_20_SHORT,
                                EMA_26_MACD_SLOW,
                                EMA_50_MEDIUM,
                                EMA_100_LONG,
                                EMA_200_LONG,
                                EMA_21_FIBO,
                                EMA_55_FIBO,
                                EMA_144_FIBO,
                                EMA_233_FIBO,
                                EMA_8_SHORT,
                                ROW_NUMBER() OVER (
                                    PARTITION BY TickerJID, TimeFrameID 
                                    ORDER BY BarTime DESC
                                ) as rn
                            FROM tms.EMA
                        )
                        SELECT 
                            TickerJID,
                            TimeFrameID,
                            EMA_5_SHORT,
                            EMA_9_MACD_SIGNAL,
                            EMA_12_MACD_FAST,
                            EMA_20_SHORT,
                            EMA_26_MACD_SLOW,
                            EMA_50_MEDIUM,
                            EMA_100_LONG,
                            EMA_200_LONG,
                            EMA_21_FIBO,
                            EMA_55_FIBO,
                            EMA_144_FIBO,
                            EMA_233_FIBO,
                            EMA_8_SHORT
                        FROM LastEMA
                        WHERE rn = 1";

                using SqlCommand cmdLastEMA = new(getLastEMAQuery, connection);
                using SqlDataReader readerLastEMA = cmdLastEMA.ExecuteReader();
                while (readerLastEMA.Read())
                {
                    int tickerID = readerLastEMA.GetInt32(0);
                    int tfID = readerLastEMA.GetInt32(1);
                    string groupKey = GetGroupKey(tickerID, tfID);

                    decimal[] emaValues = new decimal[13];
                    for (int i = 0; i < 13; i++)
                    {
                        emaValues[i] = readerLastEMA.IsDBNull(i + 2) ? 0 :
                                       Convert.ToDecimal(readerLastEMA.GetValue(i + 2));
                    }

                    lastEMAsFromTable[groupKey] = emaValues;
                }
            }

            // Получение баров для расчета
            string barsQuery = BuildBarsQuery(timeGap, filterTimeframeID, filterTickerJID);

            using SqlCommand cmdBars = new(barsQuery, connection);
            AddQueryParameters(cmdBars, timeGap, filterTimeframeID, filterTickerJID);
            cmdBars.CommandTimeout = 0;

            using SqlDataReader readerBars = cmdBars.ExecuteReader();
            Dictionary<string, decimal[]> currentEMAs = [];
            Dictionary<string, bool> groupProcessedFlags = [];

            int[] periods = [5, 9, 12, 20, 26, 50, 100, 200, 21, 55, 144, 233, 8];

            while (readerBars.Read())
            {
                int tickerID = readerBars.GetInt32(0);
                int tfID = readerBars.GetInt32(1);
                DateTime barTime = readerBars.GetDateTime(2);
                decimal closeValue = readerBars.IsDBNull(3) ? 0 :
                                     Convert.ToDecimal(readerBars.GetValue(3));

                string groupKey = GetGroupKey(tickerID, tfID);

                if (!currentEMAs.ContainsKey(groupKey))
                {
                    decimal[] initialEMAs;

                    if (useExistingEMA.IsTrue && lastEMAsFromTable.ContainsKey(groupKey))
                    {
                        // Используем существующие EMA из таблицы
                        initialEMAs = (decimal[])lastEMAsFromTable[groupKey].Clone();
                        groupProcessedFlags[groupKey] = true;
                    }
                    else
                    {
                        // Первая свеча в истории для этой группы
                        initialEMAs = new decimal[13];
                        for (int i = 0; i < 13; i++)
                        {
                            initialEMAs[i] = closeValue; // Начальное значение = Close
                        }
                        groupProcessedFlags[groupKey] = false;
                    }

                    currentEMAs[groupKey] = initialEMAs;
                }

                decimal[] emaValues = currentEMAs[groupKey];

                if (groupProcessedFlags[groupKey])
                {
                    // Расчет всех EMA
                    for (int i = 0; i < 13; i++)
                    {
                        emaValues[i] = CalculateEMA(closeValue, emaValues[i], periods[i]);
                    }
                }
                else
                {
                    // Первая свеча - EMA уже равны Close
                    groupProcessedFlags[groupKey] = true;
                }

                // Добавляем результат
                results.Add(new EMABatchResult
                {
                    TickerJID = tickerID,
                    TimeframeID = tfID,
                    BarTime = barTime,
                    CloseValue = closeValue,
                    EMA_5_SHORT = emaValues[0],
                    EMA_9_MACD_SIGNAL = emaValues[1],
                    EMA_12_MACD_FAST = emaValues[2],
                    EMA_20_SHORT = emaValues[3],
                    EMA_26_MACD_SLOW = emaValues[4],
                    EMA_50_MEDIUM = emaValues[5],
                    EMA_100_LONG = emaValues[6],
                    EMA_200_LONG = emaValues[7],
                    EMA_21_FIBO = emaValues[8],
                    EMA_55_FIBO = emaValues[9],
                    EMA_144_FIBO = emaValues[10],
                    EMA_233_FIBO = emaValues[11],
                    EMA_8_SHORT = emaValues[12]
                });

                // Обновляем текущие EMA для следующей итерации
                currentEMAs[groupKey] = emaValues;
            }
        }
        catch (Exception ex)
        {
            SqlContext.Pipe?.Send($"Error in CalculateAllEMASeriesBatch: {ex.Message}");
            throw;
        }

        return results;
    }

    /// <summary>
    /// Вспомогательный метод для расчета EMA с использованием decimal
    /// </summary>
    private static decimal CalculateEMA(decimal currentPrice, decimal previousEMA, int period)
    {
        if (period <= 0) return currentPrice;

        decimal k = 2.0m / (period + 1);
        return (currentPrice * k) + (previousEMA * (1 - k));
    }

    /// <summary>
    /// Генерация ключа группы
    /// </summary>
    private static string GetGroupKey(int tickerID, int timeframeID)
    {
        return $"{tickerID}_{timeframeID}";
    }

    /// <summary>
    /// Построение SQL запроса для получения баров
    /// </summary>
    private static string BuildBarsQuery(SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        string query = @"
            SELECT 
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

    /// <summary>
    /// Добавление параметров в SQL команду
    /// </summary>
    private static void AddQueryParameters(SqlCommand command, SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        if (!timeGap.IsNull)
            command.Parameters.AddWithValue("@timeGap", timeGap.Value);

        if (!filterTimeframeID.IsNull)
            command.Parameters.AddWithValue("@filterTimeframeID", filterTimeframeID.Value);

        if (!filterTickerJID.IsNull)
            command.Parameters.AddWithValue("@filterTickerJID", filterTickerJID.Value);
    }

    /// <summary>
    /// Метод для заполнения строки результата
    /// </summary>
    public static void FillRowBatch(
        object obj,  // ? 1-й параметр (обязательный)

        // 16 выходных параметров для 16 колонок:
        out SqlInt32 tickerJID,  // ? 2-й
        out SqlInt32 timeframeID,  // ? 3-й
        out SqlDateTime barTime,  // ? 4-й
        out SqlDecimal ema_5_short,  // ? 5-й
        out SqlDecimal ema_9_macd_signal,  // ? 6-й
        out SqlDecimal ema_12_macd_fast,  // ? 7-й
        out SqlDecimal ema_20_short,  // ? 8-й
        out SqlDecimal ema_26_macd_slow,  // ? 9-й
        out SqlDecimal ema_50_medium,  // ? 10-й
        out SqlDecimal ema_100_long,  // ? 11-й
        out SqlDecimal ema_200_long,  // ? 12-й
        out SqlDecimal ema_21_fibo,  // ? 13-й
        out SqlDecimal ema_55_fibo,  // ? 14-й
        out SqlDecimal ema_144_fibo,  // ? 15-й
        out SqlDecimal ema_233_fibo,  // ? 16-й
        out SqlDecimal ema_8_short)  // ? 17-й параметр
    {
        if (obj == null)
            throw new ArgumentNullException(nameof(obj));

        EMABatchResult result = (EMABatchResult)obj;

        tickerJID = result.TickerJID;
        timeframeID = result.TimeframeID;
        barTime = result.BarTime;
        ema_5_short = result.EMA_5_SHORT;
        ema_9_macd_signal = result.EMA_9_MACD_SIGNAL;
        ema_12_macd_fast = result.EMA_12_MACD_FAST;
        ema_20_short = result.EMA_20_SHORT;
        ema_26_macd_slow = result.EMA_26_MACD_SLOW;
        ema_50_medium = result.EMA_50_MEDIUM;
        ema_100_long = result.EMA_100_LONG;
        ema_200_long = result.EMA_200_LONG;
        ema_21_fibo = result.EMA_21_FIBO;
        ema_55_fibo = result.EMA_55_FIBO;
        ema_144_fibo = result.EMA_144_FIBO;
        ema_233_fibo = result.EMA_233_FIBO;
        ema_8_short = result.EMA_8_SHORT; // ? последнее значение
    }

    /// <summary>
    /// Внутренний класс для хранения результатов расчета
    /// </summary>
    private class EMABatchResult
    {
        public int TickerJID { get; set; }  // ? 1
        public int TimeframeID { get; set; }  // ? 2
        public DateTime BarTime { get; set; }  // ? 3
        public decimal CloseValue { get; set; } // ? Только для расчетов, не выводится!

        public decimal EMA_5_SHORT { get; set; }  // ? 4
        public decimal EMA_9_MACD_SIGNAL { get; set; }  // ? 5
        public decimal EMA_12_MACD_FAST { get; set; }  // ? 6
        public decimal EMA_20_SHORT { get; set; }  // ? 7
        public decimal EMA_26_MACD_SLOW { get; set; }  // ? 8
        public decimal EMA_50_MEDIUM { get; set; }  // ? 9
        public decimal EMA_100_LONG { get; set; }  // ? 10
        public decimal EMA_200_LONG { get; set; }  // ? 11
        public decimal EMA_21_FIBO { get; set; }  // ? 12
        public decimal EMA_55_FIBO { get; set; }  // ? 13
        public decimal EMA_144_FIBO { get; set; }  // ? 14
        public decimal EMA_233_FIBO { get; set; }  // ? 15
        public decimal EMA_8_SHORT { get; set; }  // ? 16
    }
}