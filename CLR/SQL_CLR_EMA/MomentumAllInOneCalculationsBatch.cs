using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class MomentumAllInOneCalculationsBatch
{
    [SqlFunction(
        DataAccess = DataAccessKind.Read,
        FillRowMethodName = "FillRowMomentumAll",
        TableDefinition = "BarID bigint, TickerJID int, TimeFrameID int, BarTime datetime, " +
                         "RSI_14 decimal(8,4), RSI_7 decimal(8,4), RSI_21 decimal(8,4), " +
                         "RSI_ZScore decimal(8,4), RSI_Percentile decimal(8,4), " +
                         "RSI_Slope_5 decimal(8,4), Stoch_K_14 decimal(8,4), " +
                         "Stoch_D_14 decimal(8,4), Stoch_Slope decimal(8,4), " +
                         "ROC_14 decimal(12,6), ROC_7 decimal(12,6), " +
                         "Momentum_Score decimal(8,4), Overbought_Flag bit, " +
                         "Oversold_Flag bit",
        IsDeterministic = false,
        IsPrecise = false,
        SystemDataAccess = SystemDataAccessKind.None)]
    public static System.Collections.IEnumerable CalculateAllMomentumBatch(
        SqlInt32 timeGap,
        SqlInt32 filterTimeframeID,
        SqlInt32 filterTickerJID)
    {
        List<MomentumAllResult> results = new(1000000);

        try
        {
            using SqlConnection connection = new("context connection=true");
            connection.Open();

            // Çàïðîñ äëÿ ÂÑÅÕ äàííûõ: High, Low, Close
            string barsQuery = BuildBarsQuery(timeGap, filterTimeframeID, filterTickerJID);

            using SqlCommand cmdBars = new(barsQuery, connection);
            AddQueryParameters(cmdBars, timeGap, filterTimeframeID, filterTickerJID);
            cmdBars.CommandTimeout = 0;

            using SqlDataReader readerBars = cmdBars.ExecuteReader();

            // Äâå èñòîðèè: closes äëÿ RSI/ROC, bars äëÿ Stochastic
            Dictionary<(int, int), List<decimal>> closeHistory = [];
            Dictionary<(int, int), List<BarData>> barHistory = [];

            while (readerBars.Read())
            {
                long BarID = readerBars.GetInt64(0);
                int tickerID = readerBars.GetInt32(1);
                int tfID = readerBars.GetInt32(2);
                DateTime barTime = readerBars.GetDateTime(3);
                decimal high = readerBars.IsDBNull(4) ? 0 : Convert.ToDecimal(readerBars.GetValue(4));
                decimal low = readerBars.IsDBNull(5) ? 0 : Convert.ToDecimal(readerBars.GetValue(5));
                decimal close = readerBars.IsDBNull(6) ? 0 : Convert.ToDecimal(readerBars.GetValue(6));

                var groupKey = (tickerID, tfID);

                // Èñòîðèÿ äëÿ RSI è ROC (òîëüêî close)
                if (!closeHistory.TryGetValue(groupKey, out List<decimal> closes))
                {
                    closes = new List<decimal>(50);
                    closeHistory[groupKey] = closes;
                }
                closes.Add(close);
                if (closes.Count > 50) closes.RemoveAt(0);

                // Èñòîðèÿ äëÿ Stochastic (high, low, close)
                if (!barHistory.TryGetValue(groupKey, out List<BarData> bars))
                {
                    bars = new List<BarData>(30);
                    barHistory[groupKey] = bars;
                }
                bars.Add(new BarData { High = high, Low = low, Close = close });
                if (bars.Count > 30) bars.RemoveAt(0);

                // === ÐÀÑ×ÅÒ RSI ÈÍÄÈÊÀÒÎÐÎÂ ===
                decimal rsi14 = CalculateRSI(closes, 14);
                decimal rsi7 = CalculateRSI(closes, 7);
                decimal rsi21 = CalculateRSI(closes, 21);
                decimal rsiZScore = CalculateZScore(closes, rsi14);
                decimal rsiPercentile = CalculatePercentile(closes, rsi14);
                decimal rsiSlope5 = CalculateRSISlope(closes, 5);

                // === ÐÀÑ×ÅÒ STOCHASTIC ÈÍÄÈÊÀÒÎÐÎÂ ===
                decimal stochK14 = CalculateStochasticK(bars, 14);
                decimal stochD14 = CalculateStochasticD(bars, 14, 3);
                decimal stochSlope = CalculateStochasticSlope(bars);

                // === ÐÀÑ×ÅÒ ROC ÈÍÄÈÊÀÒÎÐÎÂ ===
                decimal roc14 = CalculateROC(closes, 14);
                decimal roc7 = CalculateROC(closes, 7);

                // === ÊÎÌÁÈÍÈÐÎÂÀÍÍÛÅ ÐÀÑ×ÅÒÛ ===
                decimal normalizedROC = NormalizeROC(roc14);
                decimal momentumScore = (rsi14 * 0.4m) + (stochK14 * 0.4m) + (normalizedROC * 0.2m);
                bool overboughtFlag = rsi14 > 70m || stochK14 > 80m;
                bool oversoldFlag = rsi14 < 30m || stochK14 < 20m;

                results.Add(new MomentumAllResult
                {
                    BarID = BarID,    
                    TickerJID = tickerID,
                    TimeframeID = tfID,
                    BarTime = barTime,
                    RSI_14 = Math.Round(rsi14, 4),
                    RSI_7 = Math.Round(rsi7, 4),
                    RSI_21 = Math.Round(rsi21, 4),
                    RSI_ZScore = Math.Round(rsiZScore, 4),
                    RSI_Percentile = Math.Round(rsiPercentile, 4),
                    RSI_Slope_5 = Math.Round(rsiSlope5, 4),
                    Stoch_K_14 = Math.Round(stochK14, 4),
                    Stoch_D_14 = Math.Round(stochD14, 4),
                    Stoch_Slope = Math.Round(stochSlope, 4),
                    ROC_14 = Math.Round(roc14, 6),
                    ROC_7 = Math.Round(roc7, 6),
                    Momentum_Score = Math.Round(momentumScore, 4),
                    Overbought_Flag = overboughtFlag,
                    Oversold_Flag = oversoldFlag
                });
            }
        }
        catch (Exception ex)
        {
            SqlContext.Pipe?.Send($"Error in CalculateAllMomentumBatch: {ex.Message}");
            throw;
        }

        return results;
    }

    // ========== RSI ÌÅÒÎÄÛ ==========
    private static decimal CalculateRSI(List<decimal> prices, int period)
    {
        if (prices.Count < period + 1) return 50m;

        decimal avgGain = 0m, avgLoss = 0m;

        for (int i = prices.Count - period - 1; i < prices.Count - 1; i++)
        {
            decimal change = prices[i + 1] - prices[i];
            if (change > 0) avgGain += change;
            else avgLoss += Math.Abs(change);
        }

        avgGain /= period;
        avgLoss /= period;

        if (avgLoss == 0) return 100m;
        decimal rs = avgGain / avgLoss;
        return 100m - (100m / (1m + rs));
    }

    private static decimal CalculateZScore(List<decimal> prices, decimal currentRSI)
    {
        if (prices.Count < 20) return 0m;
        return (currentRSI - 50m) / 10m;
    }

    private static decimal CalculatePercentile(List<decimal> prices, decimal currentRSI)
    {
        if (prices.Count < 20) return 50m;

        if (currentRSI > 70m) return 90m;
        if (currentRSI > 60m) return 70m;
        if (currentRSI > 50m) return 55m;
        if (currentRSI > 40m) return 45m;
        if (currentRSI > 30m) return 30m;
        return 10m;
    }

    private static decimal CalculateRSISlope(List<decimal> prices, int lookbackPeriod)
    {
        if (prices.Count < lookbackPeriod + 15) return 0m;

        decimal currentRSI = CalculateRSI(prices, 14);

        if (prices.Count - lookbackPeriod >= 15)
        {
            List<decimal> olderPrices = prices.GetRange(0, prices.Count - lookbackPeriod);
            decimal olderRSI = CalculateRSI(olderPrices, 14);
            return (currentRSI - olderRSI) / lookbackPeriod;
        }

        return 0m;
    }

    // ========== STOCHASTIC ÌÅÒÎÄÛ ==========
    private static decimal CalculateStochasticK(List<BarData> history, int period)
    {
        if (history.Count < period) return 50m;

        decimal lowest = decimal.MaxValue;
        decimal highest = decimal.MinValue;

        int startIdx = Math.Max(0, history.Count - period);
        for (int i = startIdx; i < history.Count; i++)
        {
            if (history[i].Low < lowest) lowest = history[i].Low;
            if (history[i].High > highest) highest = history[i].High;
        }

        if (highest == lowest) return 50m;
        decimal latestClose = history[history.Count - 1].Close;
        return 100m * (latestClose - lowest) / (highest - lowest);
    }

    private static decimal CalculateStochasticD(List<BarData> history, int periodK, int periodD)
    {
        if (history.Count < periodK + periodD - 1) return 50m;

        decimal sumK = 0m;
        for (int i = 0; i < periodD; i++)
        {
            int startIdx = Math.Max(0, history.Count - periodK - i);
            int endIdx = history.Count - i;
            int count = Math.Min(periodK, endIdx - startIdx);

            if (count > 0)
            {
                var sublist = history.GetRange(startIdx, count);
                sumK += CalculateStochasticK(sublist, Math.Min(periodK, sublist.Count));
            }
        }

        return sumK / periodD;
    }

    private static decimal CalculateStochasticSlope(List<BarData> history)
    {
        if (history.Count < 5) return 0m;

        decimal currentK = CalculateStochasticK(history, Math.Min(14, history.Count));

        if (history.Count >= 3)
        {
            List<BarData> olderHistory = history.GetRange(0, history.Count - 3);
            decimal olderK = CalculateStochasticK(olderHistory, Math.Min(14, olderHistory.Count));
            return (currentK - olderK) / 3;
        }

        return 0m;
    }

    // ========== ROC ÌÅÒÎÄÛ ==========
    private static decimal CalculateROC(List<decimal> prices, int period)
    {
        if (prices.Count < period + 1) return 0m;

        decimal current = prices[prices.Count - 1];
        int pastIndex = prices.Count - period - 1;
        if (pastIndex < 0) pastIndex = 0;
        decimal past = prices[pastIndex];

        if (past == 0) return 0m;
        return ((current - past) / past) * 100m;
    }

    // ========== ÍÎÐÌÀËÈÇÀÖÈß ROC ==========
    private static decimal NormalizeROC(decimal roc)
    {
        // Îãðàíè÷èâàåì ROC äèàïàçîíîì -100..100
        if (roc > 100m) roc = 100m;
        if (roc < -100m) roc = -100m;

        // Ïðåîáðàçóåì -100..100 ? 0..100
        // -100 ? 0, 0 ? 50, 100 ? 100
        return (roc + 100m) / 2m;
    }

    // ========== ÂÑÏÎÌÎÃÀÒÅËÜÍÛÅ ÌÅÒÎÄÛ ==========
    private static string BuildBarsQuery(SqlInt32 timeGap, SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        string query = @"
            SELECT 
                b.ID as BarID,
                b.TickerJID,
                b.timeframeID,
                b.BarTime,
                b.HighValue,
                b.LowValue,
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

    private static void AddQueryParameters(SqlCommand command, SqlInt32 timeGap,
                                          SqlInt32 filterTimeframeID, SqlInt32 filterTickerJID)
    {
        if (!timeGap.IsNull)
            command.Parameters.AddWithValue("@timeGap", timeGap.Value);

        if (!filterTimeframeID.IsNull)
            command.Parameters.AddWithValue("@filterTimeframeID", filterTimeframeID.Value);

        if (!filterTickerJID.IsNull)
            command.Parameters.AddWithValue("@filterTickerJID", filterTickerJID.Value);
    }

    // ========== FillRow ÌÅÒÎÄ ==========
    public static void FillRowMomentumAll(
        object obj,
        out SqlInt64 barID,           // ÄÎÁÀÂËÅÍÎ (ïåðâûé ïàðàìåòð)
        out SqlInt32 tickerJID,
        out SqlInt32 timeframeID,
        out SqlDateTime barTime,
        out SqlDecimal rsi_14,
        out SqlDecimal rsi_7,
        out SqlDecimal rsi_21,
        out SqlDecimal rsi_zscore,
        out SqlDecimal rsi_percentile,
        out SqlDecimal rsi_slope_5,
        out SqlDecimal stoch_k_14,
        out SqlDecimal stoch_d_14,
        out SqlDecimal stoch_slope,
        out SqlDecimal roc_14,
        out SqlDecimal roc_7,
        out SqlDecimal momentum_score,
        out SqlBoolean overbought_flag,
        out SqlBoolean oversold_flag)
    {
        MomentumAllResult result = (MomentumAllResult)obj;
        barID = result.BarID;
        tickerJID = result.TickerJID;
        timeframeID = result.TimeframeID;
        barTime = result.BarTime;
        rsi_14 = result.RSI_14;
        rsi_7 = result.RSI_7;
        rsi_21 = result.RSI_21;
        rsi_zscore = result.RSI_ZScore;
        rsi_percentile = result.RSI_Percentile;
        rsi_slope_5 = result.RSI_Slope_5;
        stoch_k_14 = result.Stoch_K_14;
        stoch_d_14 = result.Stoch_D_14;
        stoch_slope = result.Stoch_Slope;
        roc_14 = result.ROC_14;
        roc_7 = result.ROC_7;
        momentum_score = result.Momentum_Score;
        overbought_flag = result.Overbought_Flag;
        oversold_flag = result.Oversold_Flag;
    }

    // ========== ÂÑÏÎÌÎÃÀÒÅËÜÍÛÅ ÊËÀÑÑÛ ==========
    private class BarData
    {
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
    }

    private class MomentumAllResult
    {
        public long BarID { get; set; }
        public int TickerJID { get; set; }
        public int TimeframeID { get; set; }
        public DateTime BarTime { get; set; }
        public decimal RSI_14 { get; set; }
        public decimal RSI_7 { get; set; }
        public decimal RSI_21 { get; set; }
        public decimal RSI_ZScore { get; set; }
        public decimal RSI_Percentile { get; set; }
        public decimal RSI_Slope_5 { get; set; }
        public decimal Stoch_K_14 { get; set; }
        public decimal Stoch_D_14 { get; set; }
        public decimal Stoch_Slope { get; set; }
        public decimal ROC_14 { get; set; }
        public decimal ROC_7 { get; set; }
        public decimal Momentum_Score { get; set; }
        public bool Overbought_Flag { get; set; }
        public bool Oversold_Flag { get; set; }
    }
}