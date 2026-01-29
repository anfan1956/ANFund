using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace SymbolExporter
{
    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SymbolExporter : Robot
    {
        [Parameter("Export Path", DefaultValue = @"D:\TradingSystems\fanfanTrader\AlgoExport\Symbols")]
        public string ExportPath { get; set; }

        [Parameter("Auto Stop", DefaultValue = true)]
        public bool AutoStop { get; set; }

        protected override void OnStart()
        {
            try
            {
                Print("=== SYMBOL EXPORTER ===");
                Print("Getting all symbols from Pepperstone cTrader...");

                Directory.CreateDirectory(ExportPath);

                string fileName = $"Pepperstone_Tickers_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string filePath = Path.Combine(ExportPath, fileName);

                Print($"Exporting to: {filePath}");

                int symbolCount = 0;

                using (var writer = new StreamWriter(filePath, false, Encoding.UTF8))
                {
                    // Только тикеры
                    writer.WriteLine("Ticker,OriginalSymbol,Unit,LotSize,PipSize");

                    foreach (string symbolName in Symbols)
                    {
                        try
                        {
                            Symbol symbol = Symbols.GetSymbol(symbolName);
                            string cleanTicker = ExtractCleanTicker(symbolName);
                            string unit = DetermineUnit(cleanTicker, symbol);

                            writer.WriteLine(
                                $"{cleanTicker}," +       // Чистый тикер
                                $"{symbolName}," +        // Оригинальное имя в cTrader
                                $"{unit}," +              // Unit
                                $"{symbol.LotSize}," +    // LotSize
                                $"{symbol.PipSize}"       // PipSize
                            );

                            symbolCount++;

                            if (symbolCount <= 20)
                            {
                                Print($"  {cleanTicker,-10} ← {symbolName}");
                            }
                        }
                        catch
                        {
                            // Пропускаем ошибки
                        }
                    }
                }

                Print($"Exported {symbolCount} tickers");
                Print("Export completed!");

            }
            catch (Exception ex)
            {
                Print($"ERROR: {ex.Message}");
            }

            if (AutoStop) Stop();
        }

        private string ExtractCleanTicker(string symbolName)
        {
            // Убираем форматирование Pepperstone
            // "Burberry_Group_(BRBY.L)" → "BRBY.L"
            // "Microsoft_(MSFT.US)" → "MSFT.US"
            // "EURUSD" → "EURUSD" (без изменений)

            // Ищем тикер в скобках
            Match match = Regex.Match(symbolName, @"\(([^)]+)\)");
            if (match.Success)
            {
                return match.Groups[1].Value; // BRBY.L
            }

            // Если нет скобок, возвращаем как есть
            return symbolName;
        }

        private string DetermineUnit(string ticker, Symbol symbol)
        {
            // Forex: PIPS
            if (ticker.Length == 6 &&
                (ticker.EndsWith("USD") || ticker.EndsWith("EUR") ||
                 ticker.EndsWith("JPY") || ticker.EndsWith("GBP") ||
                 ticker.EndsWith("CHF") || ticker.EndsWith("CAD") ||
                 ticker.EndsWith("AUD") || ticker.EndsWith("NZD")))
            {
                return "PIPS";
            }
            // Индексы: POINTS
            else if (ticker.StartsWith("US") && char.IsDigit(ticker[2]) ||
                     ticker == "NAS100" || ticker == "NDX" ||
                     ticker.StartsWith("GER") || ticker.StartsWith("UK") ||
                     ticker.StartsWith("JP") || ticker.StartsWith("AU"))
            {
                return "POINTS";
            }
            // Акции/ETF: USD или EUR
            else if (ticker.Contains(".US"))
            {
                return "USD";
            }
            else if (ticker.EndsWith(".L") || ticker.EndsWith(".DE") ||
                     ticker.EndsWith(".AS") || ticker.EndsWith(".FR"))
            {
                return "EUR"; // Европейские акции
            }

            return "USD"; // По умолчанию
        }

        protected override void OnStop()
        {
            Print("Symbol Exporter stopped");
        }
    }
}