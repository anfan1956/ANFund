using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class MarketRegimeBulkProcedure  // ? то же имя класса
{
    [SqlProcedure]
    public static void CalculateMarketRegimeBulk(  // ? то же имя метода
        SqlInt32 timeGap,
        SqlInt32 filterTimeframeID,
        SqlInt32 filterTickerJID)
    {
        try
        {
            using (SqlConnection connection = new SqlConnection("context connection=true"))
            {
                connection.Open();

                CreateTempTables(connection);

                DataTable volatilityTable = CreateVolatilityDataTable();
                DataTable trendTable = CreateTrendDataTable();
                DataTable patternsTable = CreatePatternsDataTable();
                DataTable stopsTable = CreateStopsDataTable();
                DataTable finalTable = CreateFinalDataTable();

                ProcessDataWithBatching(connection, timeGap, filterTimeframeID, filterTickerJID,
                    ref volatilityTable, ref trendTable, ref patternsTable,
                    ref stopsTable, ref finalTable);

                BulkInsertTable(connection, volatilityTable, "#TempVolatility");
                BulkInsertTable(connection, trendTable, "#TempTrend");
                BulkInsertTable(connection, patternsTable, "#TempPatterns");
                BulkInsertTable(connection, stopsTable, "#TempStops");
                BulkInsertTable(connection, finalTable, "#TempFinal");

                MergeToMainTables(connection);
                CleanupTempTables(connection);

                SqlContext.Pipe?.Send("Optimized market regime calculation completed.");
            }
        }
        catch (Exception ex)
        {
            SqlContext.Pipe?.Send("Error in CalculateMarketRegimeOptimized: " + ex.Message);
            throw;
        }
    }

    private static void CreateTempTables(SqlConnection connection)
    {
        string[] createTables = new string[]
        {
            @"CREATE TABLE #TempVolatility (
                BarID bigint PRIMARY KEY,
                TickerJID int,
                TimeFrameID int,
                BarTime datetime,
                ATR_14 decimal(18,8),
                ATR_Percent decimal(8,4),
                Historical_Volatility_20 decimal(8,4))",

            @"CREATE TABLE #TempTrend (
                BarID bigint PRIMARY KEY,
                TickerJID int,
                TimeFrameID int,
                BarTime datetime,
                ADX_14 decimal(8,4),
                Plus_DI_14 decimal(8,4),
                Minus_DI_14 decimal(8,4))",

            @"CREATE TABLE #TempPatterns (
                BarID bigint PRIMARY KEY,
                TickerJID int,
                TimeFrameID int,
                BarTime datetime,
                Inside_Bar_Flag bit,
                Outside_Bar_Flag bit,
                Pin_Bar_Flag bit)",

            @"CREATE TABLE #TempStops (
                BarID bigint PRIMARY KEY,
                TickerJID int,
                TimeFrameID int,
                BarTime datetime,
                Chandelier_Exit_Long decimal(18,8),
                Chandelier_Exit_Short decimal(18,8))",

            @"CREATE TABLE #TempFinal (
                BarID bigint PRIMARY KEY,
                TickerJID int,
                TimeFrameID int,
                BarTime datetime,
                Primary_Regime tinyint,
                Regime_Confidence decimal(8,4),
                Regime_Change_Flag bit,
                Trend_Score decimal(8,4),
                Momentum_Score decimal(8,4),
                Volatility_Score decimal(8,4),
                Overall_Score decimal(8,4))"
        };

        foreach (string sql in createTables)
        {
            using (SqlCommand cmd = new SqlCommand(sql, connection))
            {
                cmd.ExecuteNonQuery();
            }
        }
    }

    private static DataTable CreateVolatilityDataTable()
    {
        DataTable table = new DataTable();
        table.Columns.Add("BarID", typeof(long));
        table.Columns.Add("TickerJID", typeof(int));
        table.Columns.Add("TimeFrameID", typeof(int));
        table.Columns.Add("BarTime", typeof(DateTime));
        table.Columns.Add("ATR_14", typeof(decimal));
        table.Columns.Add("ATR_Percent", typeof(decimal));
        table.Columns.Add("Historical_Volatility_20", typeof(decimal));
        return table;
    }

    private static DataTable CreateTrendDataTable()
    {
        DataTable table = new DataTable();
        table.Columns.Add("BarID", typeof(long));
        table.Columns.Add("TickerJID", typeof(int));
        table.Columns.Add("TimeFrameID", typeof(int));
        table.Columns.Add("BarTime", typeof(DateTime));
        table.Columns.Add("ADX_14", typeof(decimal));
        table.Columns.Add("Plus_DI_14", typeof(decimal));
        table.Columns.Add("Minus_DI_14", typeof(decimal));
        return table;
    }

    private static DataTable CreatePatternsDataTable()
    {
        DataTable table = new DataTable();
        table.Columns.Add("BarID", typeof(long));
        table.Columns.Add("TickerJID", typeof(int));
        table.Columns.Add("TimeFrameID", typeof(int));
        table.Columns.Add("BarTime", typeof(DateTime));
        table.Columns.Add("Inside_Bar_Flag", typeof(bool));
        table.Columns.Add("Outside_Bar_Flag", typeof(bool));
        table.Columns.Add("Pin_Bar_Flag", typeof(bool));
        return table;
    }

    private static DataTable CreateStopsDataTable()
    {
        DataTable table = new DataTable();
        table.Columns.Add("BarID", typeof(long));
        table.Columns.Add("TickerJID", typeof(int));
        table.Columns.Add("TimeFrameID", typeof(int));
        table.Columns.Add("BarTime", typeof(DateTime));
        table.Columns.Add("Chandelier_Exit_Long", typeof(decimal));
        table.Columns.Add("Chandelier_Exit_Short", typeof(decimal));
        return table;
    }

    private static DataTable CreateFinalDataTable()
    {
        DataTable table = new DataTable();
        table.Columns.Add("BarID", typeof(long));
        table.Columns.Add("TickerJID", typeof(int));
        table.Columns.Add("TimeFrameID", typeof(int));
        table.Columns.Add("BarTime", typeof(DateTime));
        table.Columns.Add("Primary_Regime", typeof(byte));
        table.Columns.Add("Regime_Confidence", typeof(decimal));
        table.Columns.Add("Regime_Change_Flag", typeof(bool));
        table.Columns.Add("Trend_Score", typeof(decimal));
        table.Columns.Add("Momentum_Score", typeof(decimal));
        table.Columns.Add("Volatility_Score", typeof(decimal));
        table.Columns.Add("Overall_Score", typeof(decimal));
        return table;
    }

    private static void ProcessDataWithBatching(SqlConnection connection,
        SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID,
        ref DataTable volatilityTable, ref DataTable trendTable, ref DataTable patternsTable,
        ref DataTable stopsTable, ref DataTable finalTable)
    {
        string query = BuildQuery(timeGap, filterTimeframeID, filterTickerJID);

        List<BarRecord> bars = new List<BarRecord>();

        using (SqlCommand cmd = new SqlCommand(query, connection))
        {
            AddParameters(cmd, timeGap, filterTimeframeID, filterTickerJID);

            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    bars.Add(new BarRecord
                    {
                        BarID = reader.GetInt64(0),
                        TickerJID = reader.GetInt32(1),
                        TimeframeID = reader.GetInt32(2),
                        BarTime = reader.GetDateTime(3),
                        Open = reader.IsDBNull(4) ? 0 : (decimal)Convert.ToDouble(reader.GetValue(4)),
                        High = reader.IsDBNull(5) ? 0 : (decimal)Convert.ToDouble(reader.GetValue(5)),
                        Low = reader.IsDBNull(6) ? 0 : (decimal)Convert.ToDouble(reader.GetValue(6)),
                        Close = reader.IsDBNull(7) ? 0 : (decimal)Convert.ToDouble(reader.GetValue(7))
                    });
                }
            }
        }

        var barHistory = new Dictionary<string, List<BarData>>();
        var trueRangeHistory = new Dictionary<string, Queue<decimal>>();
        var plusDMHistory = new Dictionary<string, Queue<decimal>>();
        var minusDMHistory = new Dictionary<string, Queue<decimal>>();
        var dxHistory = new Dictionary<string, Queue<decimal>>();
        var logReturnsHistory = new Dictionary<string, Queue<decimal>>();
        var highHistory22 = new Dictionary<string, Queue<decimal>>();
        var lowHistory22 = new Dictionary<string, Queue<decimal>>();
        var atrHistory22 = new Dictionary<string, Queue<decimal>>();
        var regimeHistory = new Dictionary<string, byte>();

        int batchCounter = 0;
        const int batchSize = 10000;
        int totalBars = bars.Count;
        int processed = 0;

        foreach (var bar in bars)
        {
            string groupKey = bar.TickerJID + "_" + bar.TimeframeID;

            if (!barHistory.ContainsKey(groupKey))
            {
                barHistory[groupKey] = new List<BarData>();
                trueRangeHistory[groupKey] = new Queue<decimal>();
                plusDMHistory[groupKey] = new Queue<decimal>();
                minusDMHistory[groupKey] = new Queue<decimal>();
                dxHistory[groupKey] = new Queue<decimal>();
                logReturnsHistory[groupKey] = new Queue<decimal>();
                highHistory22[groupKey] = new Queue<decimal>();
                lowHistory22[groupKey] = new Queue<decimal>();
                atrHistory22[groupKey] = new Queue<decimal>();
                regimeHistory[groupKey] = 0;
            }

            BarData prevBar = null;
            if (barHistory[groupKey].Count > 0)
            {
                prevBar = barHistory[groupKey][barHistory[groupKey].Count - 1];
            }

            decimal prevClose = (prevBar != null) ? prevBar.Close : bar.Close;
            decimal trueRange = CalculateTrueRange(bar.High, bar.Low, prevClose);

            decimal plusDM = 0;
            decimal minusDM = 0;
            if (prevBar != null)
            {
                decimal upMove = bar.High - prevBar.High;
                decimal downMove = prevBar.Low - bar.Low;

                if (upMove > downMove && upMove > 0)
                    plusDM = upMove;
                else if (downMove > upMove && downMove > 0)
                    minusDM = downMove;
            }

            barHistory[groupKey].Add(new BarData
            {
                BarTime = bar.BarTime,
                Open = bar.Open,
                High = bar.High,
                Low = bar.Low,
                Close = bar.Close,
                TrueRange = trueRange
            });

            trueRangeHistory[groupKey].Enqueue(trueRange);
            plusDMHistory[groupKey].Enqueue(plusDM);
            minusDMHistory[groupKey].Enqueue(minusDM);

            if (trueRangeHistory[groupKey].Count > 14) trueRangeHistory[groupKey].Dequeue();
            if (plusDMHistory[groupKey].Count > 14) plusDMHistory[groupKey].Dequeue();
            if (minusDMHistory[groupKey].Count > 14) minusDMHistory[groupKey].Dequeue();

            decimal atr14 = CalculateSMA(trueRangeHistory[groupKey], 14);
            decimal smoothedPlusDM = CalculateSMA(plusDMHistory[groupKey], 14);
            decimal smoothedMinusDM = CalculateSMA(minusDMHistory[groupKey], 14);

            decimal plusDI14 = atr14 > 0 ? (smoothedPlusDM / atr14) * 100 : 0;
            decimal minusDI14 = atr14 > 0 ? (smoothedMinusDM / atr14) * 100 : 0;

            decimal dx = 0;
            if (plusDI14 + minusDI14 > 0)
            {
                dx = Math.Abs(plusDI14 - minusDI14) / (plusDI14 + minusDI14) * 100;
            }

            dxHistory[groupKey].Enqueue(dx);
            if (dxHistory[groupKey].Count > 14) dxHistory[groupKey].Dequeue();
            decimal adx14 = CalculateSMA(dxHistory[groupKey], 14);

            decimal logReturn = 0;
            if (prevBar != null && prevBar.Close > 0)
            {
                logReturn = (decimal)Math.Log((double)(bar.Close / prevBar.Close));
            }

            logReturnsHistory[groupKey].Enqueue(logReturn);
            if (logReturnsHistory[groupKey].Count > 20) logReturnsHistory[groupKey].Dequeue();
            decimal historicalVolatility = CalculateHistoricalVolatility(logReturnsHistory[groupKey]);

            bool insideBarFlag = false;
            bool outsideBarFlag = false;
            bool pinBarFlag = false;
            if (prevBar != null)
            {
                insideBarFlag = bar.High <= prevBar.High && bar.Low >= prevBar.Low;
                outsideBarFlag = bar.High > prevBar.High && bar.Low < prevBar.Low;

                decimal bodySize = Math.Abs(bar.Close - bar.Open);
                decimal upperShadow = bar.High - Math.Max(bar.Open, bar.Close);
                decimal lowerShadow = Math.Min(bar.Open, bar.Close) - bar.Low;

                pinBarFlag = (upperShadow > 2 * bodySize && lowerShadow < bodySize / 2) ||
                             (lowerShadow > 2 * bodySize && upperShadow < bodySize / 2);
            }

            highHistory22[groupKey].Enqueue(bar.High);
            lowHistory22[groupKey].Enqueue(bar.Low);
            atrHistory22[groupKey].Enqueue(trueRange);

            if (highHistory22[groupKey].Count > 22) highHistory22[groupKey].Dequeue();
            if (lowHistory22[groupKey].Count > 22) lowHistory22[groupKey].Dequeue();
            if (atrHistory22[groupKey].Count > 22) atrHistory22[groupKey].Dequeue();

            decimal chandelierExitLong = 0;
            decimal chandelierExitShort = 0;
            if (highHistory22[groupKey].Count >= 22 && atrHistory22[groupKey].Count >= 22)
            {
                decimal highestHigh = GetMax(highHistory22[groupKey]);
                decimal lowestLow = GetMin(lowHistory22[groupKey]);
                decimal atr22 = CalculateSMA(atrHistory22[groupKey], 22);

                chandelierExitLong = highestHigh - (atr22 * 3);
                chandelierExitShort = lowestLow + (atr22 * 3);
            }

            decimal trendScore = CalculateTrendScore(adx14, plusDI14, minusDI14);
            decimal volatilityScore = CalculateVolatilityScore(atr14, bar.Close, historicalVolatility);
            decimal patternScore = CalculatePatternScore(insideBarFlag, outsideBarFlag, pinBarFlag);
            decimal overallScore = (trendScore * 0.4m) + (volatilityScore * 0.3m) + (patternScore * 0.3m);

            byte primaryRegime = DeterminePrimaryRegime(trendScore, volatilityScore, plusDI14, minusDI14);
            decimal regimeConfidence = CalculateRegimeConfidence(trendScore, volatilityScore);

            bool regimeChangeFlag = false;
            if (regimeHistory[groupKey] != primaryRegime)
            {
                regimeChangeFlag = true;
                regimeHistory[groupKey] = primaryRegime;
            }

            AddToDataTables(  volatilityTable,   trendTable,   patternsTable,
                  stopsTable,   finalTable, bar, atr14, bar.Close > 0 ? (atr14 / bar.Close) * 100 : 0,
                historicalVolatility, adx14, plusDI14, minusDI14, insideBarFlag, outsideBarFlag,
                pinBarFlag, chandelierExitLong, chandelierExitShort, primaryRegime,
                regimeConfidence, regimeChangeFlag, trendScore, trendScore,
                volatilityScore, overallScore);

            if (barHistory[groupKey].Count > 100)
            {
                barHistory[groupKey].RemoveAt(0);
            }

            batchCounter++;
            processed++;

            if (batchCounter >= batchSize)
            {
                BulkInsertTable(connection, volatilityTable, "#TempVolatility");
                BulkInsertTable(connection, trendTable, "#TempTrend");
                BulkInsertTable(connection, patternsTable, "#TempPatterns");
                BulkInsertTable(connection, stopsTable, "#TempStops");
                BulkInsertTable(connection, finalTable, "#TempFinal");

                volatilityTable.Clear();
                trendTable.Clear();
                patternsTable.Clear();
                stopsTable.Clear();
                finalTable.Clear();

                batchCounter = 0;
                SqlContext.Pipe?.Send($"Processed {processed} of {totalBars} bars.");
            }
        }

        SqlContext.Pipe?.Send($"Completed processing {totalBars} bars.");
    }


    private static void ProcessGroup(SqlConnection connection, string groupKey, List<BarRecord> bars,
        ref DataTable volatilityTable, ref DataTable trendTable, ref DataTable patternsTable,
        ref DataTable stopsTable, ref DataTable finalTable)
    {
        string[] parts = groupKey.Split('_');
        int tickerJID = int.Parse(parts[0]);
        int timeframeID = int.Parse(parts[1]);

        var barHistory = new List<BarData>();
        var trueRangeCache = new SMACache(14);
        var plusDMCache = new SMACache(14);
        var minusDMCache = new SMACache(14);
        var dxCache = new SMACache(14);
        var logReturnsHistory = new Queue<decimal>();
        var highHistory22 = new Queue<decimal>();
        var lowHistory22 = new Queue<decimal>();
        var atrCache22 = new SMACache(22);
        byte lastRegime = 0;

        foreach (var bar in bars)
        {
            BarData prevBar = null;
            if (barHistory.Count > 0)
            {
                prevBar = barHistory[barHistory.Count - 1];
            }

            decimal prevClose = (prevBar != null) ? prevBar.Close : bar.Close;
            decimal trueRange = CalculateTrueRange(bar.High, bar.Low, prevClose);

            decimal plusDM = 0;
            decimal minusDM = 0;
            if (prevBar != null)
            {
                decimal upMove = bar.High - prevBar.High;
                decimal downMove = prevBar.Low - bar.Low;

                if (upMove > downMove && upMove > 0)
                    plusDM = upMove;
                else if (downMove > upMove && downMove > 0)
                    minusDM = downMove;
            }

            barHistory.Add(new BarData
            {
                BarTime = bar.BarTime,
                Open = bar.Open,
                High = bar.High,
                Low = bar.Low,
                Close = bar.Close,
                TrueRange = trueRange
            });

            trueRangeCache.Add(trueRange);
            plusDMCache.Add(plusDM);
            minusDMCache.Add(minusDM);

            decimal atr14 = trueRangeCache.GetSMA();
            decimal smoothedPlusDM = plusDMCache.GetSMA();
            decimal smoothedMinusDM = minusDMCache.GetSMA();

            decimal plusDI14 = atr14 > 0 ? (smoothedPlusDM / atr14) * 100 : 0;
            decimal minusDI14 = atr14 > 0 ? (smoothedMinusDM / atr14) * 100 : 0;

            decimal dx = 0;
            if (plusDI14 + minusDI14 > 0)
            {
                dx = Math.Abs(plusDI14 - minusDI14) / (plusDI14 + minusDI14) * 100;
            }

            dxCache.Add(dx);
            decimal adx14 = dxCache.GetSMA();

            decimal logReturn = 0;
            if (prevBar != null && prevBar.Close > 0)
            {
                logReturn = (decimal)Math.Log((double)(bar.Close / prevBar.Close));
            }

            logReturnsHistory.Enqueue(logReturn);
            if (logReturnsHistory.Count > 20) logReturnsHistory.Dequeue();
            decimal historicalVolatility = CalculateHistoricalVolatility(logReturnsHistory);

            bool insideBarFlag = false;
            bool outsideBarFlag = false;
            bool pinBarFlag = false;
            if (prevBar != null)
            {
                insideBarFlag = bar.High <= prevBar.High && bar.Low >= prevBar.Low;
                outsideBarFlag = bar.High > prevBar.High && bar.Low < prevBar.Low;

                decimal bodySize = Math.Abs(bar.Close - bar.Open);
                decimal upperShadow = bar.High - Math.Max(bar.Open, bar.Close);
                decimal lowerShadow = Math.Min(bar.Open, bar.Close) - bar.Low;

                pinBarFlag = (upperShadow > 2 * bodySize && lowerShadow < bodySize / 2) ||
                             (lowerShadow > 2 * bodySize && upperShadow < bodySize / 2);
            }

            highHistory22.Enqueue(bar.High);
            lowHistory22.Enqueue(bar.Low);
            atrCache22.Add(trueRange);

            if (highHistory22.Count > 22) highHistory22.Dequeue();
            if (lowHistory22.Count > 22) lowHistory22.Dequeue();

            decimal chandelierExitLong = 0;
            decimal chandelierExitShort = 0;
            if (highHistory22.Count >= 22 && atrCache22.Count >= 22)
            {
                decimal highestHigh = GetMax(highHistory22);
                decimal lowestLow = GetMin(lowHistory22);
                decimal atr22 = atrCache22.GetSMA();

                chandelierExitLong = highestHigh - (atr22 * 3);
                chandelierExitShort = lowestLow + (atr22 * 3);
            }

            decimal trendScore = CalculateTrendScore(adx14, plusDI14, minusDI14);
            decimal volatilityScore = CalculateVolatilityScore(atr14, bar.Close, historicalVolatility);
            decimal patternScore = CalculatePatternScore(insideBarFlag, outsideBarFlag, pinBarFlag);
            decimal overallScore = (trendScore * 0.4m) + (volatilityScore * 0.3m) + (patternScore * 0.3m);

            byte primaryRegime = DeterminePrimaryRegime(trendScore, volatilityScore, plusDI14, minusDI14);
            decimal regimeConfidence = CalculateRegimeConfidence(trendScore, volatilityScore);

            bool regimeChangeFlag = false;
            if (lastRegime != primaryRegime)
            {
                regimeChangeFlag = true;
                lastRegime = primaryRegime;
            }

            lock (volatilityTable)
            {
                AddToDataTables(volatilityTable, trendTable, patternsTable,
                    stopsTable, finalTable, bar, atr14, bar.Close > 0 ? (atr14 / bar.Close) * 100 : 0,
                    historicalVolatility, adx14, plusDI14, minusDI14, insideBarFlag, outsideBarFlag,
                    pinBarFlag, chandelierExitLong, chandelierExitShort, primaryRegime,
                    regimeConfidence, regimeChangeFlag, trendScore, trendScore,
                    volatilityScore, overallScore);
            }

            if (barHistory.Count > 100)
            {
                barHistory.RemoveAt(0);
            }
        }
    }
    private static void AddToDataTables(DataTable volatilityTable, DataTable trendTable,
        DataTable patternsTable, DataTable stopsTable, DataTable finalTable,
        BarRecord bar, decimal atr14, decimal atrPercent, decimal histVol,
        decimal adx14, decimal plusDI14, decimal minusDI14,
        bool insideBar, bool outsideBar, bool pinBar,
        decimal chandelierLong, decimal chandelierShort,
        byte primaryRegime, decimal confidence, bool changeFlag,
        decimal trendScore, decimal momentumScore, decimal volatilityScore, decimal overallScore)
    {
        // Volatility
        DataRow volRow = volatilityTable.NewRow();
        volRow["BarID"] = bar.BarID;
        volRow["TickerJID"] = bar.TickerJID;
        volRow["TimeFrameID"] = bar.TimeframeID;
        volRow["BarTime"] = bar.BarTime;
        volRow["ATR_14"] = atr14;
        volRow["ATR_Percent"] = atrPercent;
        volRow["Historical_Volatility_20"] = histVol;
        volatilityTable.Rows.Add(volRow);

        // Trend
        DataRow trendRow = trendTable.NewRow();
        trendRow["BarID"] = bar.BarID;
        trendRow["TickerJID"] = bar.TickerJID;
        trendRow["TimeFrameID"] = bar.TimeframeID;
        trendRow["BarTime"] = bar.BarTime;
        trendRow["ADX_14"] = adx14;
        trendRow["Plus_DI_14"] = plusDI14;
        trendRow["Minus_DI_14"] = minusDI14;
        trendTable.Rows.Add(trendRow);

        // Patterns
        DataRow patternRow = patternsTable.NewRow();
        patternRow["BarID"] = bar.BarID;
        patternRow["TickerJID"] = bar.TickerJID;
        patternRow["TimeFrameID"] = bar.TimeframeID;
        patternRow["BarTime"] = bar.BarTime;
        patternRow["Inside_Bar_Flag"] = insideBar;
        patternRow["Outside_Bar_Flag"] = outsideBar;
        patternRow["Pin_Bar_Flag"] = pinBar;
        patternsTable.Rows.Add(patternRow);

        // Stops
        DataRow stopRow = stopsTable.NewRow();
        stopRow["BarID"] = bar.BarID;
        stopRow["TickerJID"] = bar.TickerJID;
        stopRow["TimeFrameID"] = bar.TimeframeID;
        stopRow["BarTime"] = bar.BarTime;
        stopRow["Chandelier_Exit_Long"] = chandelierLong;
        stopRow["Chandelier_Exit_Short"] = chandelierShort;
        stopsTable.Rows.Add(stopRow);

        // Final
        DataRow finalRow = finalTable.NewRow();
        finalRow["BarID"] = bar.BarID;
        finalRow["TickerJID"] = bar.TickerJID;
        finalRow["TimeFrameID"] = bar.TimeframeID;
        finalRow["BarTime"] = bar.BarTime;
        finalRow["Primary_Regime"] = primaryRegime;
        finalRow["Regime_Confidence"] = confidence;
        finalRow["Regime_Change_Flag"] = changeFlag;
        finalRow["Trend_Score"] = trendScore;
        finalRow["Momentum_Score"] = momentumScore;
        finalRow["Volatility_Score"] = volatilityScore;
        finalRow["Overall_Score"] = overallScore;
        finalTable.Rows.Add(finalRow);
    }

    private static void BulkInsertTable(SqlConnection connection, DataTable table, string tableName)
    {
        if (table.Rows.Count == 0) return;

        using (SqlCommand cmd = new SqlCommand())
        {
            cmd.Connection = connection;
            cmd.CommandText = $"INSERT INTO {tableName} SELECT * FROM @tvp";

            SqlParameter tvpParam = new SqlParameter("@tvp", SqlDbType.Structured);
            tvpParam.Value = table;

            // Определяем TypeName внутри метода
            string typeName = "";
            switch (tableName)
            {
                case "#TempVolatility": typeName = "dbo.MarketRegimeVolatilityTVP"; break;
                case "#TempTrend": typeName = "dbo.MarketRegimeTrendTVP"; break;
                case "#TempPatterns": typeName = "dbo.MarketRegimePatternsTVP"; break;
                case "#TempStops": typeName = "dbo.MarketRegimeStopsTVP"; break;
                case "#TempFinal": typeName = "dbo.MarketRegimeFinalTVP"; break;
                default: throw new ArgumentException($"Unknown table: {tableName}");
            }

            tvpParam.TypeName = typeName;
            cmd.Parameters.Add(tvpParam);
            cmd.ExecuteNonQuery();
        }
    }

    private static void MergeToMainTables(SqlConnection connection)
    {
        string[] mergeQueries = new string[]
        {
            @"MERGE tms.MarketRegime_Volatility AS target
              USING #TempVolatility AS source
              ON target.BarID = source.BarID
              WHEN MATCHED THEN
                UPDATE SET target.ATR_14 = source.ATR_14,
                           target.ATR_Percent = source.ATR_Percent,
                           target.Historical_Volatility_20 = source.Historical_Volatility_20,
                           target.CreatedDate = GETDATE()
              WHEN NOT MATCHED THEN
                INSERT (BarID, TickerJID, BarTime, TimeFrameID,
                        ATR_14, ATR_Percent, Historical_Volatility_20)
                VALUES (source.BarID, source.TickerJID, source.BarTime, source.TimeFrameID,
                        source.ATR_14, source.ATR_Percent, source.Historical_Volatility_20);",

            @"MERGE tms.MarketRegime_Trend AS target
              USING #TempTrend AS source
              ON target.BarID = source.BarID
              WHEN MATCHED THEN
                UPDATE SET target.ADX_14 = source.ADX_14,
                           target.Plus_DI_14 = source.Plus_DI_14,
                           target.Minus_DI_14 = source.Minus_DI_14,
                           target.CreatedDate = GETDATE()
              WHEN NOT MATCHED THEN
                INSERT (BarID, TickerJID, BarTime, TimeFrameID,
                        ADX_14, Plus_DI_14, Minus_DI_14)
                VALUES (source.BarID, source.TickerJID, source.BarTime, source.TimeFrameID,
                        source.ADX_14, source.Plus_DI_14, source.Minus_DI_14);",

            @"MERGE tms.MarketRegime_Patterns AS target
              USING #TempPatterns AS source
              ON target.BarID = source.BarID
              WHEN MATCHED THEN
                UPDATE SET target.Inside_Bar_Flag = source.Inside_Bar_Flag,
                           target.Outside_Bar_Flag = source.Outside_Bar_Flag,
                           target.Pin_Bar_Flag = source.Pin_Bar_Flag,
                           target.CreatedDate = GETDATE()
              WHEN NOT MATCHED THEN
                INSERT (BarID, TickerJID, BarTime, TimeFrameID,
                        Inside_Bar_Flag, Outside_Bar_Flag, Pin_Bar_Flag)
                VALUES (source.BarID, source.TickerJID, source.BarTime, source.TimeFrameID,
                        source.Inside_Bar_Flag, source.Outside_Bar_Flag, source.Pin_Bar_Flag);",

            @"MERGE tms.MarketRegime_Stops AS target
              USING #TempStops AS source
              ON target.BarID = source.BarID
              WHEN MATCHED THEN
                UPDATE SET target.Chandelier_Exit_Long = source.Chandelier_Exit_Long,
                           target.Chandelier_Exit_Short = source.Chandelier_Exit_Short,
                           target.CreatedDate = GETDATE()
              WHEN NOT MATCHED THEN
                INSERT (BarID, TickerJID, BarTime, TimeFrameID,
                        Chandelier_Exit_Long, Chandelier_Exit_Short)
                VALUES (source.BarID, source.TickerJID, source.BarTime, source.TimeFrameID,
                        source.Chandelier_Exit_Long, source.Chandelier_Exit_Short);",

            @"MERGE tms.MarketRegime_Final AS target
              USING #TempFinal AS source
              ON target.BarID = source.BarID
              WHEN MATCHED THEN
                UPDATE SET target.Primary_Regime = source.Primary_Regime,
                           target.Regime_Confidence = source.Regime_Confidence,
                           target.Regime_Change_Flag = source.Regime_Change_Flag,
                           target.Trend_Score = source.Trend_Score,
                           target.Momentum_Score = source.Momentum_Score,
                           target.Volatility_Score = source.Volatility_Score,
                           target.Overall_Score = source.Overall_Score,
                           target.CreatedDate = GETDATE()
              WHEN NOT MATCHED THEN
                INSERT (BarID, TickerJID, BarTime, TimeFrameID,
                        Primary_Regime, Regime_Confidence, Regime_Change_Flag,
                        Trend_Score, Momentum_Score, Volatility_Score, Overall_Score)
                VALUES (source.BarID, source.TickerJID, source.BarTime, source.TimeFrameID,
                        source.Primary_Regime, source.Regime_Confidence, source.Regime_Change_Flag,
                        source.Trend_Score, source.Momentum_Score, source.Volatility_Score, source.Overall_Score);"
        };

        foreach (string sql in mergeQueries)
        {
            using (SqlCommand cmd = new SqlCommand(sql, connection))
            {
                cmd.ExecuteNonQuery();
            }
        }
    }

    private static void CleanupTempTables(SqlConnection connection)
    {
        string[] dropTables = new string[]
        {
            "DROP TABLE #TempVolatility",
            "DROP TABLE #TempTrend",
            "DROP TABLE #TempPatterns",
            "DROP TABLE #TempStops",
            "DROP TABLE #TempFinal"
        };

        foreach (string sql in dropTables)
        {
            try
            {
                using (SqlCommand cmd = new SqlCommand(sql, connection))
                {
                    cmd.ExecuteNonQuery();
                }
            }
            catch { }
        }
    }

    // =========== HELPER METHODS (same as before) ===========

    private static decimal CalculateTrueRange(decimal high, decimal low, decimal prevClose)
    {
        decimal range1 = high - low;
        decimal range2 = Math.Abs(high - prevClose);
        decimal range3 = Math.Abs(low - prevClose);

        return Math.Max(range1, Math.Max(range2, range3));
    }

    private static decimal CalculateSMA(Queue<decimal> values, int period)
    {
        if (values.Count < period)
            return 0;

        decimal sum = 0;
        foreach (decimal value in values)
        {
            sum += value;
        }

        return sum / period;
    }

    private static decimal CalculateHistoricalVolatility(Queue<decimal> logReturns)
    {
        if (logReturns.Count < 2)
            return 0;

        decimal mean = 0;
        foreach (decimal r in logReturns)
            mean += r;
        mean /= logReturns.Count;

        decimal variance = 0;
        foreach (decimal r in logReturns)
        {
            variance += (r - mean) * (r - mean);
        }
        variance /= (logReturns.Count - 1);

        return (decimal)Math.Sqrt((double)variance) * (decimal)Math.Sqrt(252) * 100;
    }

    private static decimal GetMax(Queue<decimal> values)
    {
        decimal max = decimal.MinValue;
        foreach (decimal value in values)
        {
            if (value > max)
                max = value;
        }
        return max;
    }

    private static decimal GetMin(Queue<decimal> values)
    {
        decimal min = decimal.MaxValue;
        foreach (decimal value in values)
        {
            if (value < min)
                min = value;
        }
        return min;
    }

    private static decimal CalculateTrendScore(decimal adx, decimal plusDI, decimal minusDI)
    {
        if (adx <= 0)
            return 0.5m;

        decimal adxComponent = Math.Min(adx / 60m, 1m);
        decimal directionComponent = 0.5m;
        decimal diDiff = Math.Abs(plusDI - minusDI);

        if (diDiff > 0)
        {
            directionComponent = 0.5m + (Math.Min(diDiff / 40m, 0.5m) * Math.Sign(plusDI - minusDI));
        }

        decimal score = (adxComponent * 0.6m) + (directionComponent * 0.4m);
        return Math.Max(0m, Math.Min(1m, score));
    }

    private static decimal CalculateVolatilityScore(decimal atr, decimal close, decimal histVol)
    {
        decimal atrPercentScore = 0.5m;
        if (close > 0)
        {
            decimal atrPercent = (atr / close) * 100;
            atrPercentScore = Math.Min(atrPercent / 5m, 1m);
        }

        decimal histVolScore = Math.Min(histVol / 20m, 1m);

        return (atrPercentScore + histVolScore) / 2m;
    }

    private static decimal CalculatePatternScore(bool insideBar, bool outsideBar, bool pinBar)
    {
        decimal score = 0.5m;

        if (insideBar)
            score -= 0.2m;
        if (outsideBar)
            score += 0.1m;
        if (pinBar)
            score += 0.15m;

        return Math.Max(0m, Math.Min(1m, score));
    }

    private static byte DeterminePrimaryRegime(decimal trendScore, decimal volatilityScore,
                                              decimal plusDI, decimal minusDI)
    {
        if (volatilityScore > 0.7m)
            return 4;

        if (volatilityScore < 0.3m)
            return 5;

        if (trendScore > 0.7m)
        {
            return plusDI > minusDI ? (byte)1 : (byte)2;
        }

        if (trendScore < 0.4m)
            return 3;

        if (Math.Abs(plusDI - minusDI) > 10)
        {
            return plusDI > minusDI ? (byte)1 : (byte)2;
        }

        return 3;
    }

    private static decimal CalculateRegimeConfidence(decimal trendScore, decimal volatilityScore)
    {
        decimal trendConf = Math.Abs(trendScore - 0.5m) * 2m;
        decimal volConf = Math.Abs(volatilityScore - 0.5m) * 2m;

        return (trendConf + volConf) / 2m;
    }

    private static string BuildQuery(SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        string query = @"SELECT 
                b.ID as BarID,
                b.TickerJID,
                b.timeframeID,
                b.BarTime,
                b.OpenValue,
                b.HighValue,
                b.LowValue,
                b.CloseValue
            FROM tms.bars b WITH (NOLOCK)
            WHERE 1=1";

        if (!timeGap.IsNull)
            query += " AND b.BarTime > DATEADD(MINUTE, -@timeGap, GETUTCDATE())";

        if (!filterTimeframeID.IsNull)
            query += " AND b.timeframeID = @filterTimeframeID";

        if (!filterTickerJID.IsNull)
            query += " AND b.TickerJID = @filterTickerJID";

        return query;
    }

    private static void AddParameters(SqlCommand command, SqlInt32 timeGap,
        SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        if (!timeGap.IsNull)
            command.Parameters.AddWithValue("@timeGap", timeGap.Value);

        if (!filterTimeframeID.IsNull)
            command.Parameters.AddWithValue("@filterTimeframeID", filterTimeframeID.Value);

        if (!filterTickerJID.IsNull)
            command.Parameters.AddWithValue("@filterTickerJID", filterTickerJID.Value);
    }

    // =========== HELPER CLASSES ===========

    private class BarRecord
    {
        public long BarID { get; set; }
        public int TickerJID { get; set; }
        public int TimeframeID { get; set; }
        public DateTime BarTime { get; set; }
        public decimal Open { get; set; }
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
    }

    private class BarData
    {
        public DateTime BarTime { get; set; }
        public decimal Open { get; set; }
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
        public decimal TrueRange { get; set; }
    }
    private class SMACache
    {
        private Queue<decimal> values = new Queue<decimal>();
        private decimal sum = 0;
        private int period;

        public SMACache(int period) { this.period = period; }

        public void Add(decimal value)
        {
            values.Enqueue(value);
            sum += value;

            if (values.Count > period)
            {
                sum -= values.Dequeue();
            }
        }

        public decimal GetSMA()
        {
            if (values.Count < period) return 0;
            return sum / period;
        }

        public int Count => values.Count;
    }

}