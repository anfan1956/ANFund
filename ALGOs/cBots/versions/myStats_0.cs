using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Collections;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

namespace myStats
{
    [Robot(AccessRights = AccessRights.None)]
    public class PositionLister : Robot
    {
        [Parameter("Auto Export", DefaultValue = true)]
        public bool AutoExport { get; set; }

        [Parameter("Print to Log", DefaultValue = true)]
        public bool PrintToLog { get; set; }

        [Parameter("Show in Message Box", DefaultValue = false)]
        public bool ShowMessageBox { get; set; }

        protected override void OnStart()
        {
            Print("=== POSITION LISTER STARTED ===");

            ListAllPositions();

            if (AutoExport)
                ExportPositionsToFile();

            Print("=== POSITION LISTER FINISHED ===");

            if (ShowMessageBox)
                ShowSummaryMessage();
        }

        private void ListAllPositions()
        {
            var positions = Positions.ToArray();

            Print($"Total Open Positions: {positions.Length}");
            Print($"Account Balance: {Account.Balance}");
            Print($"Account Equity: {Account.Equity}");
            Print($"Free Margin: {Account.FreeMargin}");
            Print($"Used Margin: {Account.Margin:F2}");
            Print($"Margin Level: {Account.MarginLevel:F2}%");
            Print("");

            if (positions.Length == 0)
            {
                Print("No open positions found.");
                return;
            }

            // Print header - CORRECTED column name
            Print("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗");
            Print("║ ID       │ Symbol      │ Type │ Volume    │ Entry Price │ Current Price │ Stop Loss │ Take Profit │ P&L        │ Net P&L    │ Swap       │ Margin      │ Open Time          ║");
            Print("╟──────────┼─────────────┼──────┼───────────┼─────────────┼───────────────┼───────────┼─────────────┼────────────┼────────────┼────────────┼─────────────┼────────────────────╢");

            double totalProfit = 0;
            double totalSwap = 0;
            double totalMarginUsed = 0;

            foreach (var position in positions)
            {
                totalProfit += position.NetProfit;
                totalSwap += position.Swap;
                totalMarginUsed += position.Margin; // CORRECTED: Use position.Margin

                string positionInfo = string.Format(
                    "║ {0,-8} │ {1,-11} │ {2,-4} │ {3,9:F2} │ {4,11:F5} │ {5,13:F5} │ {6,9:F5} │ {7,11:F5} │ {8,10:F2} │ {9,10:F2} │ {10,10:F2} │ {11,11:F2} │ {12,18} ║",
                    position.Id,
                    position.SymbolName,
                    position.TradeType,
                    position.VolumeInUnits,
                    position.EntryPrice,
                    position.CurrentPrice,
                    position.StopLoss.HasValue ? position.StopLoss.Value : 0,
                    position.TakeProfit.HasValue ? position.TakeProfit.Value : 0,
                    position.GrossProfit,
                    position.NetProfit,
                    position.Swap,
                    position.Margin, // CORRECTED: Use position.Margin
                    position.EntryTime.ToString("yyyy-MM-dd HH:mm:ss")
                );

                Print(positionInfo);
            }

            Print("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝");
            Print("");

            // Summary - CORRECTED variable name
            Print($"=== SUMMARY ===");
            Print($"Total Positions: {positions.Length}");
            Print($"Total Gross Profit: {positions.Sum(p => p.GrossProfit):F2}");
            Print($"Total Net Profit: {totalProfit:F2}");
            Print($"Total Swap: {totalSwap:F2}");
            Print($"Total Margin Used: {totalMarginUsed:F2}");
            Print($"Account Margin: {Account.Margin:F2}"); // This should match totalMarginUsed
            Print($"Margin Utilization: {(Account.Margin > 0 ? (totalMarginUsed / Account.Margin * 100) : 0):F2}%");
            Print($"Average P&L per position: {(positions.Length > 0 ? totalProfit / positions.Length : 0):F2}");
            Print($"Average Margin per position: {(positions.Length > 0 ? totalMarginUsed / positions.Length : 0):F2}");
            Print("");

            // By symbol summary - CORRECTED property name
            var bySymbol = positions.GroupBy(p => p.SymbolName);
            foreach (var group in bySymbol)
            {
                double symbolProfit = group.Sum(p => p.NetProfit);
                double symbolMargin = group.Sum(p => p.Margin); // CORRECTED: Use p.Margin
                Print($"{group.Key}: {group.Count()} positions, Total P&L: {symbolProfit:F2}, Total Margin: {symbolMargin:F2}");
            }
        }

        private void ExportPositionsToFile()
        {
            try
            {
                string fileName = $"Positions_{Account.Number}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
                string folderPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
                string filePath = System.IO.Path.Combine(folderPath, "cTrader Exports", fileName);

                // Create directory if it doesn't exist
                System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(filePath));

                using (var writer = new System.IO.StreamWriter(filePath))
                {
                    // Write header - CORRECTED column name
                    writer.WriteLine("ID,Symbol,TradeType,Volume,EntryPrice,CurrentPrice,StopLoss,TakeProfit,GrossProfit,NetProfit,Swap,Margin,OpenTime,Comment");

                    // Write data - CORRECTED property name
                    foreach (var position in Positions)
                    {
                        writer.WriteLine(
                            $"{position.Id}," +
                            $"{position.SymbolName}," +
                            $"{position.TradeType}," +
                            $"{position.VolumeInUnits}," +
                            $"{position.EntryPrice}," +
                            $"{position.CurrentPrice}," +
                            $"{(position.StopLoss.HasValue ? position.StopLoss.Value.ToString() : "")}," +
                            $"{(position.TakeProfit.HasValue ? position.TakeProfit.Value.ToString() : "")}," +
                            $"{position.GrossProfit}," +
                            $"{position.NetProfit}," +
                            $"{position.Swap}," +
                            $"{position.Margin}," + // CORRECTED: Use position.Margin
                            $"{position.EntryTime:yyyy-MM-dd HH:mm:ss}," +
                            $"\"{position.Comment?.Replace("\"", "\"\"") ?? ""}\""
                        );
                    }
                }

                Print($"Positions exported to: {filePath}");
                Print("You can open this file in Excel");
            }
            catch (Exception ex)
            {
                Print($"Error exporting to file: {ex.Message}");
            }
        }

        private void ShowSummaryMessage()
        {
            var positions = Positions.ToArray();
            string message = $"Open Positions: {positions.Length}\n";
            message += $"Total P&L: {positions.Sum(p => p.NetProfit):F2}\n";
            message += $"Total Margin Used: {positions.Sum(p => p.Margin):F2}\n\n"; // CORRECTED: Use p.Margin

            foreach (var position in positions.Take(10)) // Show first 10
            {
                message += $"{position.SymbolName} {position.TradeType} - P&L: {position.NetProfit:F2}, Margin: {position.Margin:F2}\n"; // CORRECTED: Use position.Margin
            }

            if (positions.Length > 10)
                message += $"\n... and {positions.Length - 10} more positions";

            MessageBox.Show(message, "Position Summary", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        protected override void OnStop()
        {
            Print("Position Lister stopped");
        }
    }
}