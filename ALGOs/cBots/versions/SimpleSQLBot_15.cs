using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Linq;



namespace SimpleSQLBot
{

    [Robot(AccessRights = AccessRights.FullAccess)]
    public class SimpleSQLBot : Robot
    {
        [Parameter("Collect Bars", DefaultValue = true)]
        public bool CollectBars { get; set; }

        [Parameter("Collect Bars From Date", DefaultValue = "2025-01-01")]
        public string CollectFromDate { get; set; }

        [Parameter("Collect Bars To Date", DefaultValue = "2026-12-31")]
        public string CollectToDate { get; set; }

        [Parameter("Bars Time Frame", DefaultValue = "Minute")]
        public TimeFrame BarsTimeFrame { get; set; }

        [Parameter("Symbols to Collect", DefaultValue = "XAUUSD,XAGUSD,NAS100")]
        public string SymbolsToCollect { get; set; }

        [Parameter("Source ID (from tms.sources)", DefaultValue = 1)]
        public int SourceId { get; set; }

        // Карта: TickerJID для каждого символа
        private readonly Dictionary<string, int> _symbolTickerJids = new();


        private readonly Dictionary<TimeFrame, int> _timeFrameIds = new();
        private readonly Dictionary<string, DateTime> _lastProcessedBarTime = new();

        [Parameter("Time Frame", DefaultValue = "Minute1")]
        public TimeFrame SelectedTimeFrame { get; set; }

        [Parameter("SL Default, %", DefaultValue = 3, MinValue = 1, Step = 1)]
        public int SlDefault { get; set; }
        [Parameter("TP Default, %", DefaultValue = 5, MinValue = 1, Step = 1)]
        public int TpDefault { get; set; }

        [Parameter("Send to SQL", DefaultValue = true)]
        public bool SendToSql { get; set; }

        [Parameter("Signal TF (ms)", DefaultValue = 500, MinValue = 100, MaxValue = 5000)]
        public int SignalTfMs { get; set; }

        private System.Threading.Timer _signalTimer;
        private volatile bool _isProcessing = false;
        private readonly object _lockObject = new();

        private const string ConnectionString = "Server=62.181.56.230;Database=cTrader;User Id=anfan;Password=Gisele12!;";
        private DateTime _lastBarTime;
        private ConnectionManager _connectionManager;
        private static string GetOrderDirection(TradeType tradeType) => tradeType == TradeType.Buy ? "long" : "short";

        private static string GetOrderTypeName(PendingOrderType orderType)
        {
            return orderType switch
            {
                PendingOrderType.Limit => "LimitOrder",
                PendingOrderType.Stop => "StopOrder",
                PendingOrderType.StopLimit => "StopLimitOrder",
                _ => "MarketOrder"
            };
        }

        protected override void OnStart()
        {
            try
            {
                _connectionManager = new ConnectionManager(ConnectionString);
                _connectionManager.Open();
                Print("SQL Connection opened successfully");
            }
            catch (Exception ex)
            {
                Print($"ERROR: {ex.Message}");
                Stop();
                return;
            }

            Print("Loading symbol mappings from database...");
            using (SqlCommand cmd = new("ref.sp_GetTickerJIDs", _connectionManager.GetConnection()))
            {
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@symbolsCSV", SymbolsToCollect);

                using SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    _symbolTickerJids[reader.GetString(0)] = reader.GetInt32(1);
                }
            }

            Print($"Mapped {_symbolTickerJids.Count} symbols from database:");
            foreach (var kvp in _symbolTickerJids)
            {
                Print($"  {kvp.Key} -> {kvp.Value}");
            }

            // Подписываемся только на события позиций
            Positions.Opened += OnPositionOpened;
            Positions.Closed += OnPositionClosed;
            Positions.Modified += OnPositionModified;
            PendingOrders.Created += OnPendingOrderCreated;
            PendingOrders.Filled += OnPendingOrderFilled;
            PendingOrders.Cancelled += OnPendingOrderCancelled;
            PendingOrders.Modified += OnPendingOrderModified;

            Print($"=== POSITION LISTER STARTED ===");
            Print($"Start Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print($"Account: {Account.Number}, Broker: {Account.BrokerName}");
            Print("");

            _lastBarTime = Server.Time;

            Print("=== BOT STARTED ===");
            ExecuteSignals();

            // Запускаем таймер сигналов
            _signalTimer = new System.Threading.Timer(
                TimerCallback,
                null,
                0,              // Начальная задержка (0 = сразу)
                SignalTfMs);    // Интервал повторения

            Print($"Signal timer started with interval: {SignalTfMs}ms");

            // Инициализация для сбора баров
            InitializeBarCollection();

            // ЗАГРУЗКА ИСТОРИЧЕСКИХ ДАННЫХ ПРИ СТАРТЕ
            LoadHistoricalBars();

            Print("=== BOT FULLY INITIALIZED ===");
        }

        private void TimerCallback(object state)
        {
            // Защита от повторного входа
            if (_isProcessing)
            {
                return; // Пропускаем, если уже обрабатываем
            }

            lock (_lockObject)
            {
                if (_isProcessing) return;
                _isProcessing = true;
            }

            try
            {
                // Используем BeginInvokeOnMainThread для выполнения в основном потоке cAlgo
                BeginInvokeOnMainThread(() =>
                {
                    try
                    {
                        ExecuteSignals();
                    }
                    catch (Exception ex)
                    {
                        Print($"Error in timer callback: {ex.Message}");
                    }
                    finally
                    {
                        _isProcessing = false;
                    }
                });
            }
            catch (Exception ex)
            {
                Print($"Error invoking on main thread: {ex.Message}");
                _isProcessing = false;
            }
        }

        private void ExecuteSignals()
        {
            try
            {

                var connection = _connectionManager.GetConnection();
                if (connection.State != ConnectionState.Open)
                {
                    Print($"ERROR: SQL connection is not open! State: {connection.State}");
                    return;
                }

                using SqlCommand cmd = new("algo.sp_GetActiveSignal", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                using SqlDataReader reader = cmd.ExecuteReader();

                while (reader.Read())
                {
                    int signalId = Convert.ToInt32(reader[0]);
                    string ticker = Convert.ToString(reader[1]);
                    double volume = Convert.ToDouble(reader[2]);
                    string direction = Convert.ToString(reader[3]);
                    double? orderPrice = reader.IsDBNull(4) ? (double?)null : Convert.ToDouble(reader[4]);
                    double stopLoss = reader.IsDBNull(5) ? 0 : Convert.ToDouble(reader[5]);
                    double takeProfit = reader.IsDBNull(6) ? 0 : Convert.ToDouble(reader[6]);
                    Guid positionLabel = reader.GetGuid(7);
                    TradeType tradeType = direction.ToLower() == "buy" ? TradeType.Buy : TradeType.Sell;

                    PlaceOrderAsync(ticker, volume, orderPrice, stopLoss, takeProfit,
                           tradeType, signalId, positionLabel);

                }
            }
            catch (Exception ex)
            {
                Print($"Error: {ex.Message}");
            }
        }

        // Где-нибудь в классе SimpleSQLBot (можно в конце, перед методами обработки):

        private static int GetTimeFrameId(TimeFrame timeFrame)
        {
            // Простой маппинг без обращения к базе
            if (timeFrame == TimeFrame.Minute) return 1;      // M1
            if (timeFrame == TimeFrame.Minute5) return 2;     // M5
            if (timeFrame == TimeFrame.Minute15) return 3;    // M15
            if (timeFrame == TimeFrame.Minute30) return 4;    // M30
            if (timeFrame == TimeFrame.Hour) return 5;        // H1
            if (timeFrame == TimeFrame.Hour4) return 6;       // H4
            if (timeFrame == TimeFrame.Daily) return 7;       // D1
            if (timeFrame == TimeFrame.Weekly) return 8;      // W1
            if (timeFrame == TimeFrame.Monthly) return 9;     // MN1

            return 2; // По умолчанию M5
        }

        private void OnPositionOpened(PositionOpenedEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Position Opened ===");
                Print($"Position ID: {args.Position.Id}");
                Print($"Symbol: {args.Position.SymbolName}");
                Print($"Label: {args.Position.Label}");

                // Определяем тип события и UUID
                string eventName = "Discretionary";
                Guid? uuid = null;

                // ПРОВЕРЯЕМ UUID
                if (args.Position.Label != null)
                {
                    if (Guid.TryParse(args.Position.Label, out Guid parsedUuid))
                    {
                        eventName = "Signal";
                        uuid = parsedUuid;
                        Print($"UUID found: {uuid} - Signal opening");
                    }
                    else
                    {
                        // Label есть, но не UUID
                        Print($"Label exists but not UUID - Discretionary opening");
                    }
                }
                else
                {
                    // Label вообще нет
                    Print($"No Label - Discretionary opening");
                }

                // Используем универсальный TradeEventTrigger
                TradeEventTrigger(
                tradeType: "Position", // Важно: "Position", а не "marketOrder"
                eventName: eventName,
                category: "Open",
                symbol: args.Position.SymbolName,
                volume: args.Position.VolumeInUnits,
                price: args.Position.EntryPrice,
                slPrice: args.Position.StopLoss,
                tpPrice: args.Position.TakeProfit,
                direction: args.Position.TradeType,
                uuid: uuid
            );

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPositionOpened: {ex.Message}");
            }
        }

        private void OnPositionClosed(PositionClosedEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Position Closed ===");
                Print($"Position ID: {args.Position.Id}");
                Print($"Symbol: {args.Position.SymbolName}");
                Print($"P&L: {args.Position.NetProfit}");
                Print($"Label: {args.Position.Label}");

                // Определяем причину закрытия
                string eventName = "ManualClose"; // по умолчанию
                Guid? uuid = null;

                if (Guid.TryParse(args.Position.Label, out Guid parsedUuid))
                {
                    uuid = parsedUuid;
                    Print($"UUID found: {uuid}");
                }

                // Ищем сделку в истории для получения данных закрытия
                double closePrice = 0;
                double grossProfit = 0;
                double netProfit = 0;
                double swap = 0;
                double commission = 0;

                foreach (HistoricalTrade trade in History)
                {
                    if (trade.PositionId == args.Position.Id)
                    {
                        closePrice = trade.ClosingPrice;
                        grossProfit = trade.GrossProfit;
                        netProfit = trade.NetProfit;
                        swap = trade.Swap;
                        commission = trade.Commissions;
                        break;
                    }
                }
                if (uuid.HasValue)
                {
                    try
                    {
                        using SqlCommand updateCmd = new("UPDATE trd.position SET closeTime = @closeTime WHERE positionLabel = @positionLabel", _connectionManager.GetConnection());

                        updateCmd.Parameters.AddWithValue("@positionLabel", uuid.Value);
                        updateCmd.Parameters.AddWithValue("@closeTime", Server.Time);

                        int rowsUpdated = updateCmd.ExecuteNonQuery();
                        Print($"Position {uuid.Value} closeTime updated, rows affected: {rowsUpdated}");
                    }
                    catch (Exception updateEx)
                    {
                        Print($"Error updating closeTime: {updateEx.Message}");
                    }
                }


                // Создаем profitInfo XML для закрытия
                string profitXml = $@"<Profit>
                    <Gross>{grossProfit:F2}</Gross>
                    <Net>{netProfit:F2}</Net>
                    <Swap>{swap:F2}</Swap>
                    <Commission>{commission:F2}</Commission>
                </Profit>";

                // Создаем DataTable с 16 колонками
                DataTable eventsTable = new();
                eventsTable.Columns.Add("tradeUUID", typeof(Guid));
                eventsTable.Columns.Add("tradeType", typeof(string));         // Position
                eventsTable.Columns.Add("eventName", typeof(string));         // ManualClose, StopLoss, etc.
                eventsTable.Columns.Add("category", typeof(string));          // Close
                eventsTable.Columns.Add("direction", typeof(string));         // long/short
                eventsTable.Columns.Add("accountNumber", typeof(string));
                eventsTable.Columns.Add("brokerName", typeof(string));
                eventsTable.Columns.Add("platformCode", typeof(string));
                eventsTable.Columns.Add("symbol", typeof(string));
                eventsTable.Columns.Add("volume", typeof(decimal));
                eventsTable.Columns.Add("price", typeof(decimal));            // Цена закрытия
                eventsTable.Columns.Add("slPrice", typeof(decimal));
                eventsTable.Columns.Add("tpPrice", typeof(decimal));
                eventsTable.Columns.Add("tradeTypeName", typeof(string));     // Position
                eventsTable.Columns.Add("profitInfo", typeof(string));        // XML с P&L

                DataRow row = eventsTable.NewRow();
                row["tradeUUID"] = uuid ?? (object)DBNull.Value;
                row["tradeType"] = "Position";
                row["eventName"] = eventName;
                row["category"] = "Close";
                row["direction"] = args.Position.TradeType == TradeType.Buy ? "long" : "short";
                row["accountNumber"] = Account.Number.ToString();
                row["brokerName"] = Account.BrokerName;
                row["platformCode"] = "cTrader";
                row["symbol"] = args.Position.SymbolName;
                row["volume"] = Convert.ToDecimal(args.Position.VolumeInUnits);
                row["price"] = Convert.ToDecimal(closePrice);
                row["slPrice"] = args.Position.StopLoss ?? 0;
                row["tpPrice"] = args.Position.TakeProfit ?? 0;
                row["tradeTypeName"] = "Position";
                row["profitInfo"] = profitXml; // Важно: XML с данными P&L

                eventsTable.Rows.Add(row);

                // Вызываем хранимую процедуру
                using SqlCommand cmd = new("algo.sp_LogTradeEvents", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter param = cmd.Parameters.AddWithValue("@events", eventsTable);
                param.SqlDbType = SqlDbType.Structured;
                param.TypeName = "algo.TradeEventTableType";

                int rowsAffected = cmd.ExecuteNonQuery();
                Print($"Position closed logged, rows affected: {rowsAffected}");

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPositionClosed: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private void OnPositionModified(PositionModifiedEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Position Modified ===");
                Print($"Position ID: {args.Position.Id}");
                Print($"Symbol: {args.Position.SymbolName}");
                Print($"Label: {args.Position.Label}");

                // Определяем тип события
                string eventName = "Discretionary"; // по умолчанию - ручная модификация
                Guid? uuid = null;

                if (Guid.TryParse(args.Position.Label, out Guid parsedUuid))
                {
                    eventName = "Signal";
                    uuid = parsedUuid;
                    Print($"UUID found: {uuid} - Signal modification");
                }
                else
                {
                    Print($"No UUID - Discretionary modification");
                }

                // Используем универсальный TradeEventTrigger
                TradeEventTrigger(
                    tradeType: "Position",
                    eventName: eventName,
                    category: "Modify",
                    symbol: args.Position.SymbolName,
                    volume: args.Position.VolumeInUnits,
                    price: args.Position.EntryPrice, // Цена открытия не меняется
                    slPrice: args.Position.StopLoss,
                    tpPrice: args.Position.TakeProfit,
                    direction: args.Position.TradeType,
                    uuid: uuid
                );

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPositionModified: {ex.Message}");
            }
        }

        private void OnPendingOrderCreated(PendingOrderCreatedEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Pending Order Created ===");

                // Определяем UUID
                if (!string.IsNullOrEmpty(args.PendingOrder.Label) &&
                    Guid.TryParse(args.PendingOrder.Label, out Guid orderUuid))
                {
                    // Используем общие методы
                    string orderTypeName = GetOrderTypeName(args.PendingOrder.OrderType);
                    string orderDirection = GetOrderDirection(args.PendingOrder.TradeType);

                    var orderData = new PendingOrderData
                    {
                        OrderUuid = orderUuid,
                        OrderTicket = args.PendingOrder.Id.ToString(),
                        Symbol = args.PendingOrder.SymbolName,
                        OrderTypeName = orderTypeName,
                        OrderDirection = orderDirection,
                        Volume = args.PendingOrder.VolumeInUnits,
                        TargetPrice = args.PendingOrder.TargetPrice,
                        StopLoss = args.PendingOrder.StopLoss,
                        TakeProfit = args.PendingOrder.TakeProfit,
                        OrderStatus = "pending"
                    };

                    ProcessPendingOrders(new List<PendingOrderData> { orderData });
                }
                else
                {
                    Print($"No UUID in Label - skipping SQL update");
                }
            }
            catch (Exception ex)
            {
                Print($"Error in OnPendingOrderCreated: {ex.Message}");
            }
        }

        private void OnPendingOrderFilled(PendingOrderFilledEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Pending Order Filled ===");
                Print($"Order ID: {args.PendingOrder.Id}");
                Print($"Symbol: {args.PendingOrder.SymbolName}");
                Print($"Order Type: {args.PendingOrder.OrderType}");
                Print($"Volume (from pending): {args.PendingOrder.VolumeInUnits}");
                Print($"Volume (from position): {args.Position.VolumeInUnits}");
                Print($"Target Price: {args.PendingOrder.TargetPrice:F5}");
                Print($"Label: {args.PendingOrder.Label}");
                Print($"Filled Price: {args.Position.EntryPrice:F5}");
                Print($"Position ID: {args.Position.Id}");

                // Определяем UUID
                Guid? uuid = null;

                if (!string.IsNullOrEmpty(args.PendingOrder.Label) &&
                    Guid.TryParse(args.PendingOrder.Label, out Guid parsedUuid))
                {
                    uuid = parsedUuid;
                    Print($"UUID found: {uuid} - Signal order filled");
                }
                else if (!string.IsNullOrEmpty(args.PendingOrder.Label))
                {
                    Print($"Label exists but not UUID: '{args.PendingOrder.Label}' - Discretionary order filled");
                }
                else
                {
                    Print($"No Label - Discretionary order filled");
                }

                // Используем общий метод для типа ордера
                string tradeTypeName = GetOrderTypeName(args.PendingOrder.OrderType);

                // ФИКС: Используем объем из позиции, если pending объем = 0
                double volume = args.PendingOrder.VolumeInUnits > 0
                    ? args.PendingOrder.VolumeInUnits
                    : args.Position.VolumeInUnits;

                // Логируем закрытие отложенного ордера (Filled)
                // ВАЖНО: Для Filled всегда используем eventName = "Filled"
                TradeEventTrigger(
                    tradeType: tradeTypeName,
                    eventName: "Filled",  // Всегда "Filled" для исполненных ордеров
                    category: "Close",
                    symbol: args.PendingOrder.SymbolName,
                    volume: volume,  // Используем исправленный объем
                    price: args.PendingOrder.TargetPrice,
                    slPrice: args.PendingOrder.StopLoss,
                    tpPrice: args.PendingOrder.TakeProfit,
                    direction: args.PendingOrder.TradeType,
                    uuid: uuid
                );

                // Обновляем статус только для сигнальных ордеров
                if (uuid.HasValue)
                {
                    var orderData = new PendingOrderData
                    {
                        OrderUuid = uuid.Value,
                        OrderTicket = args.PendingOrder.Id.ToString(),
                        Symbol = args.PendingOrder.SymbolName,
                        OrderTypeName = tradeTypeName,
                        OrderDirection = GetOrderDirection(args.PendingOrder.TradeType),
                        Volume = volume,  // Используем исправленный объем
                        TargetPrice = args.PendingOrder.TargetPrice,
                        StopLoss = args.PendingOrder.StopLoss,
                        TakeProfit = args.PendingOrder.TakeProfit,
                        OrderStatus = "filled"
                    };

                    ProcessPendingOrders(new List<PendingOrderData> { orderData });
                    Print($"Order {uuid.Value} status updated to 'filled' (Volume: {volume})");
                }

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPendingOrderFilled: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private void OnPendingOrderCancelled(PendingOrderCancelledEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Pending Order Cancelled ===");
                Print($"Order ID: {args.PendingOrder.Id}");
                Print($"Symbol: {args.PendingOrder.SymbolName}");
                Print($"Order Type: {args.PendingOrder.OrderType}");
                Print($"Volume: {args.PendingOrder.VolumeInUnits}");
                Print($"Target Price: {args.PendingOrder.TargetPrice:F5}");
                Print($"Label: {args.PendingOrder.Label}");

                // Определяем UUID и тип события
                Guid? uuid = null;
                string eventName = "Discretionary";

                if (!string.IsNullOrEmpty(args.PendingOrder.Label) &&
                    Guid.TryParse(args.PendingOrder.Label, out Guid parsedUuid))
                {
                    uuid = parsedUuid;
                    eventName = "Signal";
                    Print($"UUID found: {uuid} - Signal order cancelled");
                }
                else if (!string.IsNullOrEmpty(args.PendingOrder.Label))
                {
                    Print($"Label exists but not UUID: '{args.PendingOrder.Label}' - Discretionary order cancelled");
                }
                else
                {
                    Print($"No Label - Discretionary order cancelled");
                }

                // Используем общий метод для типа ордера
                string tradeTypeName = GetOrderTypeName(args.PendingOrder.OrderType);

                // Логируем закрытие отложенного ордера
                TradeEventTrigger(
                    tradeType: tradeTypeName,
                    eventName: eventName,
                    category: "Close",
                    symbol: args.PendingOrder.SymbolName,
                    volume: args.PendingOrder.VolumeInUnits,
                    price: args.PendingOrder.TargetPrice,
                    slPrice: args.PendingOrder.StopLoss,
                    tpPrice: args.PendingOrder.TakeProfit,
                    direction: args.PendingOrder.TradeType,
                    uuid: uuid
                );

                // Обновляем статус только для сигнальных ордеров
                if (uuid.HasValue)
                {
                    var orderData = new PendingOrderData
                    {
                        OrderUuid = uuid.Value,
                        OrderTicket = args.PendingOrder.Id.ToString(),
                        Symbol = args.PendingOrder.SymbolName,
                        OrderTypeName = tradeTypeName,
                        OrderDirection = GetOrderDirection(args.PendingOrder.TradeType),
                        Volume = args.PendingOrder.VolumeInUnits,
                        TargetPrice = args.PendingOrder.TargetPrice,
                        StopLoss = args.PendingOrder.StopLoss,
                        TakeProfit = args.PendingOrder.TakeProfit,
                        OrderStatus = "cancelled"
                    };

                    ProcessPendingOrders(new List<PendingOrderData> { orderData });
                    Print($"Order {uuid.Value} status updated to 'cancelled'");
                }

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPendingOrderCancelled: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private void OnPendingOrderModified(PendingOrderModifiedEventArgs args)
        {
            try
            {
                Print($"=== EVENT: Pending Order Modified ===");
                Print($"Order ID: {args.PendingOrder.Id}");
                Print($"Symbol: {args.PendingOrder.SymbolName}");
                Print($"Order Type: {args.PendingOrder.OrderType}");
                Print($"New Target Price: {args.PendingOrder.TargetPrice:F5}");
                Print($"Label: {args.PendingOrder.Label}");

                // Определяем UUID и тип события
                Guid? uuid = null;
                string eventName = "Discretionary"; // по умолчанию

                if (!string.IsNullOrEmpty(args.PendingOrder.Label) &&
                    Guid.TryParse(args.PendingOrder.Label, out Guid parsedUuid))
                {
                    uuid = parsedUuid;
                    eventName = "Signal";
                    Print($"UUID found: {uuid} - Signal order modified");
                }
                else if (!string.IsNullOrEmpty(args.PendingOrder.Label))
                {
                    Print($"Label exists but not UUID: '{args.PendingOrder.Label}' - Discretionary order modified");
                }
                else
                {
                    Print($"No Label - Discretionary order modified");
                }

                // Используем общий метод для определения типа ордера
                string tradeTypeName = GetOrderTypeName(args.PendingOrder.OrderType);

                // Логируем модификацию отложенного ордера
                TradeEventTrigger(
                    tradeType: tradeTypeName,
                    eventName: eventName,
                    category: "Modify",
                    symbol: args.PendingOrder.SymbolName,
                    volume: args.PendingOrder.VolumeInUnits,
                    price: args.PendingOrder.TargetPrice,
                    slPrice: args.PendingOrder.StopLoss,
                    tpPrice: args.PendingOrder.TakeProfit,
                    direction: args.PendingOrder.TradeType,
                    uuid: uuid
                );

                // Обновляем запись в pendingOrders
                if (uuid.HasValue)
                {
                    // Создаем данные для обновления через trd.sp_PendingOrder
                    var orderData = new PendingOrderData
                    {
                        OrderUuid = uuid.Value,
                        OrderTicket = args.PendingOrder.Id.ToString(),
                        Symbol = args.PendingOrder.SymbolName,
                        OrderTypeName = tradeTypeName,  // Используем общий метод
                        OrderDirection = GetOrderDirection(args.PendingOrder.TradeType),  // Используем общий метод
                        Volume = args.PendingOrder.VolumeInUnits,
                        TargetPrice = args.PendingOrder.TargetPrice,
                        StopLoss = args.PendingOrder.StopLoss,
                        TakeProfit = args.PendingOrder.TakeProfit,
                        OrderStatus = "pending"  // Для модификации статус остается pending
                    };

                    // Вызываем процедуру обновления
                    ProcessPendingOrders(new List<PendingOrderData> { orderData });
                    Print($"Order {uuid.Value} updated (modified)");
                }

                Print($"=== END EVENT ===");
            }
            catch (Exception ex)
            {
                Print($"Error in OnPendingOrderModified: {ex.Message}");
            }
        }

        private void TradeEventTrigger(string tradeType, string eventName, string category,
                          string symbol, double volume, double price,
                          double? slPrice, double? tpPrice, TradeType direction,
                          Guid? uuid = null)
        {
            try
            {
                // ПРОВЕРКА СОЕДИНЕНИЯ
                if (_connectionManager == null)
                {
                    Print($"ERROR: Connection manager is null in TradeEventTrigger!");
                    return;
                }

                var connection = _connectionManager.GetConnection();
                if (connection.State != ConnectionState.Open)
                {
                    Print($"ERROR: SQL connection is not open! State: {connection.State}");
                    return;
                }

                Print($"=== TradeEventTrigger ===");
                Print($"Type: {tradeType}, Event: {eventName}, Category: {category}");

                // Определяем direction string
                string directionStr = direction == TradeType.Buy ? "long" : "short";

                // Определяем tradeType для колонки tradeType (Position или PendingOrder)
                string tradeTypeForColumn = tradeType == "Position" ? "Position" : "PendingOrder";

                // Подготовка данных для SQL
                DataTable eventsTable = new();
                eventsTable.Columns.Add("tradeUUID", typeof(Guid));
                eventsTable.Columns.Add("tradeType", typeof(string));         // НОВАЯ КОЛОНКА
                eventsTable.Columns.Add("eventName", typeof(string));
                eventsTable.Columns.Add("category", typeof(string));
                eventsTable.Columns.Add("direction", typeof(string));
                eventsTable.Columns.Add("accountNumber", typeof(string));
                eventsTable.Columns.Add("brokerName", typeof(string));
                eventsTable.Columns.Add("platformCode", typeof(string));
                eventsTable.Columns.Add("symbol", typeof(string));
                eventsTable.Columns.Add("volume", typeof(decimal));
                eventsTable.Columns.Add("price", typeof(decimal));
                eventsTable.Columns.Add("slPrice", typeof(decimal));
                eventsTable.Columns.Add("tpPrice", typeof(decimal));
                eventsTable.Columns.Add("tradeTypeName", typeof(string));
                eventsTable.Columns.Add("profitInfo", typeof(string));

                DataRow row = eventsTable.NewRow();
                row["tradeUUID"] = uuid ?? (object)DBNull.Value;
                row["tradeType"] = tradeTypeForColumn; // Position или PendingOrder
                row["eventName"] = eventName;
                row["category"] = category;
                row["direction"] = directionStr;
                row["accountNumber"] = Account.Number.ToString();
                row["brokerName"] = Account.BrokerName;
                row["platformCode"] = "cTrader";
                row["symbol"] = symbol;
                row["volume"] = Convert.ToDecimal(volume);
                row["price"] = Convert.ToDecimal(price);
                row["slPrice"] = slPrice ?? 0;
                row["tpPrice"] = tpPrice ?? 0;
                row["tradeTypeName"] = tradeType; // marketOrder, LimitOrder, StopOrder, Position
                row["profitInfo"] = "<Profit></Profit>";

                eventsTable.Rows.Add(row);

                // Вызываем хранимую процедуру
                using SqlCommand cmd = new("algo.sp_LogTradeEvents", connection);
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter param = cmd.Parameters.AddWithValue("@events", eventsTable);
                param.SqlDbType = SqlDbType.Structured;
                param.TypeName = "algo.TradeEventTableType";

                int rowsAffected = cmd.ExecuteNonQuery();
                Print($"TradeEventTrigger executed, rows affected: {rowsAffected}");
                Print($"=== END TradeEventTrigger ===");
            }
            catch (Exception ex)
            {
                Print($"Error in TradeEventTrigger: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private void PlaceOrderAsync(string symbol, double volume, double? price,
                                   double stopLoss, double takeProfit,
                                   TradeType tradeType, int signalId, Guid Label)
        {
            if (!Symbols.Exists(symbol))
            {
                Print($"[{signalId}] Symbol not found");
                UpdateSignalStatus(Label, "REJECTED");
                return;
            }

            var symbolObj = Symbols.GetSymbol(symbol);
            double currentPrice = tradeType == TradeType.Buy ? symbolObj.Bid : symbolObj.Ask;
            double volumeUnits = symbolObj.QuantityToVolumeInUnits(volume);
            Print($"double volumeUnites: {volumeUnits}");

            void callback(TradeResult result)
            {
                if (result.IsSuccessful)
                {
                    string execType = result.PendingOrder != null ? "order" : "position";
                    string execId = result.PendingOrder?.Id.ToString() ?? result.Position?.Id.ToString();

                    Print($"=== TradeResult Callback ===");
                    Print($"UUID: {Label}, Success: {result.IsSuccessful}");

                    if (result.Position != null)
                    {
                        Print($"Position opened: ID={result.Position.Id}");
                    }

                    if (result.PendingOrder != null)
                    {
                        Print($"PendingOrder created: ID={result.PendingOrder.Id}");
                    }

                    // Вызываем с UUID вместо signalId
                    UpdateSignalStatus(Label, "ACCEPTED", execType, execId);
                }
                else
                {
                    Print($"=== TradeResult FAILED ===");
                    Print($"UUID: {Label}, Error: {result.Error}");

                    // Вызываем с UUID вместо signalId
                    UpdateSignalStatus(Label, "REJECTED");
                }
            }

            double ThePrice = tradeType == TradeType.Buy ? symbolObj.Bid : symbolObj.Ask;
            double slPips = stopLoss > 0 ? Math.Abs(ThePrice - stopLoss) / symbolObj.PipSize : ThePrice * SlDefault / 100 / symbolObj.PipSize;
            double tpPips = takeProfit > 0 ? Math.Abs(takeProfit - currentPrice) / symbolObj.PipSize : ThePrice * TpDefault / 100 / symbolObj.PipSize;
            double priceDiff = price.HasValue ? Math.Abs(price.Value - currentPrice) : 0;
            double minDiff = symbolObj.PipSize * 2;
            string PositionLabel = Label.ToString();

            if (price == null || priceDiff < minDiff)
            {
                Print($"[{PositionLabel}] NULL or less then mindif price detected, placing MARKET ORDER");
                ExecuteMarketOrderAsync(tradeType, symbol, volumeUnits,
                                      $"{PositionLabel}", slPips, tpPips, callback);
            }
            else
            {
                if ((tradeType == TradeType.Buy && price.Value < currentPrice) ||
                         (tradeType == TradeType.Sell && price.Value > currentPrice))
                {
                    PlaceLimitOrderAsync(tradeType, symbol, volumeUnits, price.Value,
                                       $"{PositionLabel}", stopLoss, takeProfit,
                                       ProtectionType.Absolute, callback);
                }
                else
                {
                    PlaceStopOrderAsync(tradeType, symbol, volumeUnits, price.Value,
                                      $"{PositionLabel}", stopLoss, takeProfit,
                                      ProtectionType.Absolute, callback);
                }
            }
        }

        private void UpdateSignalStatus(Guid uuid, string status,
                               string executionType = null, string executionId = null)
        {
            try
            {
                using SqlCommand cmd = new("algo.sp_ProcessSignal", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                // Теперь основной параметр - @uuid, а не @signalID
                cmd.Parameters.AddWithValue("@uuid", uuid.ToString());
                cmd.Parameters.AddWithValue("@status", status);
                cmd.Parameters.AddWithValue("@executionType", executionType ?? (object)DBNull.Value);
                cmd.Parameters.AddWithValue("@executionID", executionId ?? (object)DBNull.Value);

                cmd.ExecuteNonQuery();
                Print($"[Signal {uuid}] Status updated: {status}");
            }
            catch (Exception ex)
            {
                Print($"[Signal {uuid}] SQL error: {ex.Message}");
            }
        }

        private void ProcessPendingOrders(List<PendingOrderData> orders)
        {
            if (orders.Count == 0)
                return;

            try
            {
                // Создаем DataTable для TVT
                DataTable ordersTable = new();
                ordersTable.Columns.Add("accountNumber", typeof(string));
                ordersTable.Columns.Add("brokerName", typeof(string));
                ordersTable.Columns.Add("platformName", typeof(string));
                ordersTable.Columns.Add("orderUUID", typeof(Guid));
                ordersTable.Columns.Add("orderTicket", typeof(string));
                ordersTable.Columns.Add("symbol", typeof(string));
                ordersTable.Columns.Add("orderTypeName", typeof(string));
                ordersTable.Columns.Add("direction", typeof(string));
                ordersTable.Columns.Add("volume", typeof(decimal));
                ordersTable.Columns.Add("targetPrice", typeof(decimal));
                ordersTable.Columns.Add("stopLoss", typeof(decimal));
                ordersTable.Columns.Add("takeProfit", typeof(decimal));
                ordersTable.Columns.Add("orderStatus", typeof(string));

                // Заполняем DataTable
                foreach (var order in orders)
                {
                    DataRow row = ordersTable.NewRow();
                    row["accountNumber"] = Account.Number.ToString();
                    row["brokerName"] = Account.BrokerName;
                    row["platformName"] = "cTrader";
                    row["orderUUID"] = order.OrderUuid;
                    row["orderTicket"] = order.OrderTicket;
                    row["symbol"] = order.Symbol;
                    row["orderTypeName"] = order.OrderTypeName;
                    row["direction"] = order.OrderDirection; // Используем явное поле
                    row["volume"] = Convert.ToDecimal(order.Volume);
                    row["targetPrice"] = order.TargetPrice ?? (object)DBNull.Value;
                    row["stopLoss"] = order.StopLoss ?? (object)DBNull.Value;
                    row["takeProfit"] = order.TakeProfit ?? (object)DBNull.Value;
                    row["orderStatus"] = order.OrderStatus;

                    ordersTable.Rows.Add(row);
                }

                // ВЫВОДИМ SQL ДЛЯ ОТЛАДКИ
                Print("=== DEBUG: trd.sp_PendingOrder CALL ===");
                Print($"Number of orders: {orders.Count}");

                foreach (var order in orders)
                {
                    Print($"Order UUID: {order.OrderUuid}");
                    Print($"Order Ticket: {order.OrderTicket}");
                    Print($"Symbol: {order.Symbol}");
                    Print($"Order Type: {order.OrderTypeName}");
                    Print($"Direction: {order.OrderDirection}");
                    Print($"Volume: {order.Volume}");
                    Print($"Target Price: {order.TargetPrice?.ToString("F5") ?? "NULL"}");
                    Print($"Stop Loss: {order.StopLoss?.ToString("F5") ?? "NULL"}");
                    Print($"Take Profit: {order.TakeProfit?.ToString("F5") ?? "NULL"}");
                    Print($"Status: {order.OrderStatus}");
                    Print("---");
                }

                // Генерируем SQL скрипт для ручного выполнения
                StringBuilder sqlBuilder = new();
                sqlBuilder.AppendLine("DECLARE @orders trd.PendingOrderTableType");
                sqlBuilder.AppendLine("INSERT INTO @orders VALUES ");

                for (int i = 0; i < orders.Count; i++)
                {
                    var order = orders[i];
                    sqlBuilder.Append($"('{Account.Number}', ");
                    sqlBuilder.Append($"'{Account.BrokerName.Replace("'", "''")}', ");
                    sqlBuilder.Append($"'cTrader', ");
                    sqlBuilder.Append($"'{order.OrderUuid}', ");
                    sqlBuilder.Append($"'{order.OrderTicket}', ");
                    sqlBuilder.Append($"'{order.Symbol}', ");
                    sqlBuilder.Append($"'{order.OrderTypeName}', ");
                    sqlBuilder.Append($"'{order.OrderDirection}', ");
                    sqlBuilder.Append($"{order.Volume.ToString("F2", System.Globalization.CultureInfo.InvariantCulture)}, ");
                    sqlBuilder.Append(order.TargetPrice.HasValue ? $"{order.TargetPrice.Value.ToString("F6", System.Globalization.CultureInfo.InvariantCulture)}" : "NULL");
                    sqlBuilder.Append($", ");
                    sqlBuilder.Append(order.StopLoss.HasValue ? $"{order.StopLoss.Value.ToString("F6", System.Globalization.CultureInfo.InvariantCulture)}" : "NULL");
                    sqlBuilder.Append($", ");
                    sqlBuilder.Append(order.TakeProfit.HasValue ? $"{order.TakeProfit.Value.ToString("F6", System.Globalization.CultureInfo.InvariantCulture)}" : "NULL");
                    sqlBuilder.Append($", ");
                    sqlBuilder.Append($"'{order.OrderStatus}')");

                    if (i < orders.Count - 1)
                        sqlBuilder.AppendLine(", ");
                    else
                        sqlBuilder.AppendLine();
                }

                sqlBuilder.AppendLine();
                sqlBuilder.AppendLine("EXEC trd.sp_PendingOrder @orders");
                sqlBuilder.AppendLine("GO");

                Print("=== SQL SCRIPT FOR MANUAL EXECUTION ===");
                Print(sqlBuilder.ToString());
                Print("=== END DEBUG ===");

                // Вызываем хранимую процедуру
                using SqlCommand cmd = new("trd.sp_PendingOrder", _connectionManager.GetConnection());
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter param = cmd.Parameters.AddWithValue("@orders", ordersTable);
                param.SqlDbType = SqlDbType.Structured;
                param.TypeName = "trd.PendingOrderTableType";

                int rowsAffected = cmd.ExecuteNonQuery();
                Print($"Pending orders updated: {rowsAffected} rows affected");
            }
            catch (Exception ex)
            {
                Print($"Error updating pending orders: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }
        protected override void OnBar()
        {
            Print($"New Bar Started for timeframe: {SelectedTimeFrame}");
            try
            {
                DateTime currentBarTime = Server.Time;

                // Process on every new bar
                if (currentBarTime > _lastBarTime)
                {
                    Print($"=== PROCESSING BAR: {currentBarTime:yyyy-MM-dd HH:mm:ss} ===");
                    Print($"Time Frame: {SelectedTimeFrame}");

                    // Обрабатываем сбор данных о позициях
                    ProcessDataCollection();

                    // НОВАЯ ЛОГИКА: Сбор баров
                    if (CollectBars)
                    {
                        // Дополнительная проверка для отладки
                        if (BarsTimeFrame == null)
                        {
                            Print($"ERROR: BarsTimeFrame is null!");
                            return;
                        }

                        if (string.IsNullOrEmpty(SymbolsToCollect))
                        {
                            Print($"ERROR: SymbolsToCollect is empty!");
                            return;
                        }

                        Print($"DEBUG: Starting CollectBarsData()...");
                        Print($"  BarsTimeFrame: {BarsTimeFrame}");
                        Print($"  SymbolsToCollect: {SymbolsToCollect}");

                        CollectBarsData();
                        Print($"DEBUG: CollectBarsData() completed");
                    }

                    _lastBarTime = currentBarTime;
                }
                else
                {
                    Print($"Skipping bar processing - already processed for {_lastBarTime:yyyy-MM-dd HH:mm:ss}");
                }
            }
            catch (Exception ex)
            {
                Print($"Error in OnBar: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private int ProcessNewBarsForSymbol(Symbol symbol, Bars bars)
        {
            int barsProcessed = 0;
            List<BarData> newBars = new();

            try
            {
                // Получаем время последнего обработанного бара
                DateTime lastProcessedTime = _lastProcessedBarTime.ContainsKey(symbol.Name)
                    ? _lastProcessedBarTime[symbol.Name]
                    : DateTime.MinValue;

                Print($"    Last processed time for {symbol.Name}: {lastProcessedTime:yyyy-MM-dd HH:mm:ss}");
                Print($"    Current bars count: {bars.Count}");

                if (bars.Count > 0)
                {
                    Print($"    Last bar in series: {bars.Last().OpenTime:yyyy-MM-dd HH:mm:ss}");
                }

                // Обрабатываем новые бары (с конца, но не включая текущий формирующийся бар)
                int startIndex = Math.Max(0, bars.Count - 2); // начинаем с предпоследнего бара

                for (int i = startIndex; i >= 0; i--)
                {
                    var bar = bars[i];

                    // Если время бара больше последнего обработанного - это новый бар
                    if (bar.OpenTime > lastProcessedTime)
                    {
                        var barData = new BarData
                        {
                            TickerJID = _symbolTickerJids.ContainsKey(symbol.Name)
                                ? _symbolTickerJids[symbol.Name]
                                : 0,
                            BarTime = bar.OpenTime,
                            TimeFrameID = GetTimeFrameId(BarsTimeFrame),
                            OpenValue = bar.Open,
                            CloseValue = bar.Close,
                            HighValue = bar.High,
                            LowValue = bar.Low,
                            SourceID = SourceId
                        };

                        newBars.Add(barData);
                        barsProcessed++;
                    }
                    else
                    {
                        // Дошли до уже обработанных баров - выходим из цикла
                        break;
                    }
                }

                if (newBars.Count > 0)
                {
                    // Реверсируем чтобы сохранить хронологический порядок
                    newBars.Reverse();
                    SendBarsToSql(newBars);

                    // Обновляем время последнего обработанного бара
                    var lastBar = newBars[^1];
                    _lastProcessedBarTime[symbol.Name] = lastBar.BarTime;

                    Print($"    Found {barsProcessed} new bars since {lastProcessedTime:yyyy-MM-dd HH:mm:ss}");
                    Print($"    New last processed time: {_lastProcessedBarTime[symbol.Name]:yyyy-MM-dd HH:mm:ss}");
                }
                else
                {
                    Print($"    No new bars since {lastProcessedTime:yyyy-MM-dd HH:mm:ss}");
                }
            }
            catch (Exception ex)
            {
                Print($"Error processing new bars for {symbol.Name}: {ex.Message}");
            }

            return barsProcessed;
        }

        private void ProcessDataCollection()
        {
            try
            {
                // 1. COLLECT EQUITY DATA
                CollectEquityData();

                // Get current positions
                var positions = Positions.ToArray();

                // Get and execute SQL script
                if (SendToSql && positions.Length > 0)
                {
                    string sqlScript = GetSqlScript(positions);
                    ExecuteSql(sqlScript);
                }
                else if (positions.Length == 0)
                {
                    Print("No positions to process");
                }
                else
                {
                    Print("SQL integration disabled");
                }

                Print("Data collection completed");
            }
            catch (Exception ex)
            {
                Print($"Error in ProcessDataCollection: {ex.Message}");
            }
        }

        private int ProcessHistoricalBarsForSymbol(Symbol symbol, List<Bar> historicalBars)
        {
            int barsProcessed = 0;
            List<BarData> barsToSend = new();

            try
            {
                Print($"    Processing {historicalBars.Count} historical bars...");

                // Проверяем есть ли TickerJID для этого символа
                if (!_symbolTickerJids.ContainsKey(symbol.Name))
                {
                    Print($"    ERROR: No TickerJID mapping for symbol {symbol.Name}");
                    Print($"    Available symbols: {string.Join(", ", _symbolTickerJids.Keys)}");
                    return 0;
                }

                // Обрабатываем все исторические бары
                foreach (var bar in historicalBars)
                {
                    var barData = new BarData
                    {
                        TickerJID = _symbolTickerJids[symbol.Name],
                        BarTime = bar.OpenTime,
                        TimeFrameID = GetTimeFrameId(BarsTimeFrame),
                        OpenValue = bar.Open,
                        CloseValue = bar.Close,
                        HighValue = bar.High,
                        LowValue = bar.Low,
                        SourceID = SourceId
                    };

                    barsToSend.Add(barData);
                    barsProcessed++;
                }

                // Отправляем все исторические бары в SQL
                if (barsToSend.Count > 0)
                {
                    SendBarsToSql(barsToSend);

                    // Запоминаем время последнего исторического бара
                    var lastBarTime = historicalBars[^1].OpenTime;

                    if (!_lastProcessedBarTime.ContainsKey(symbol.Name))
                    {
                        _lastProcessedBarTime[symbol.Name] = lastBarTime;
                    }
                    else if (lastBarTime > _lastProcessedBarTime[symbol.Name])
                    {
                        _lastProcessedBarTime[symbol.Name] = lastBarTime;
                    }

                    Print($"    Sent {barsProcessed} historical bars to SQL");
                    Print($"    Last historical bar time: {lastBarTime:yyyy-MM-dd HH:mm:ss}");
                }
            }
            catch (Exception ex)
            {
                Print($"Error processing historical bars for {symbol.Name}: {ex.Message}");
            }

            return barsProcessed;
        }

        private void CollectBarsData()
        {
            if (!CollectBars) return;

            try
            {
                Print($"=== COLLECTING BAR DATA ({BarsTimeFrame}) ===");

                var symbols = SymbolsToCollect.Split(',');
                int totalBarsProcessed = 0;

                foreach (var symbolName in symbols)
                {
                    string cleanSymbol = symbolName.Trim();

                    if (string.IsNullOrEmpty(cleanSymbol))
                        continue;

                    if (!Symbols.Exists(cleanSymbol))
                    {
                        Print($"  {cleanSymbol}: Symbol not found");
                        continue;
                    }

                    var symbol = Symbols.GetSymbol(cleanSymbol);

                    // Проверяем есть ли TickerJID для этого символа
                    if (!_symbolTickerJids.ContainsKey(symbol.Name))
                    {
                        Print($"  {symbol.Name}: No TickerJID mapping (skipping)");
                        Print($"  Available mappings: {string.Join(", ", _symbolTickerJids.Keys)}");
                        continue;
                    }

                    Print($"  Processing {symbol.Name} (TickerJID: {_symbolTickerJids[symbol.Name]})...");

                    try
                    {
                        // Получаем бары для символа
                        var bars = MarketData.GetBars(BarsTimeFrame, symbol.Name);
                        Print($"    Bars available: {bars.Count}");

                        if (bars.Count < 2)
                        {
                            Print($"    Not enough bars ({bars.Count})");
                            continue;
                        }

                        // Обрабатываем новые бары
                        int barsProcessed = ProcessNewBarsForSymbol(symbol, bars);
                        totalBarsProcessed += barsProcessed;

                        if (barsProcessed > 0)
                        {
                            Print($"    Processed {barsProcessed} new bars");
                        }
                        else
                        {
                            Print($"    No new bars to process");
                        }
                    }
                    catch (Exception ex)
                    {
                        Print($"    ERROR getting bars: {ex.Message}");
                    }
                }

                if (totalBarsProcessed > 0)
                {
                    Print($"=== COLLECTION COMPLETE: {totalBarsProcessed} bars processed ===");
                }
                else
                {
                    Print("=== COLLECTION COMPLETE: No new bars ===");
                }
            }
            catch (Exception ex)
            {
                Print($"Error collecting bars: {ex.Message}");
            }
        }


        private void CollectEquityData()
        {
            try
            {
                // Get account data
                var accountData = GetSqlAccountData();

                // Get current equity values
                decimal equity = (decimal)Account.Equity;
                decimal marginUsed = (decimal)Account.Margin;
                decimal marginFree = (decimal)Account.FreeMargin;
                decimal marginLevel = Account.MarginLevel > 0 ? (decimal)Account.MarginLevel / 100 : 0;


                // Create SQL script
                string sqlScript = GetEquitySqlScript(accountData, equity, marginUsed, marginFree, marginLevel);

                // Execute the SQL
                ExecuteSql(sqlScript);

                Print($"Equity collected: {equity:F2}");
            }
            catch (Exception ex)
            {
                Print($"Error collecting equity: {ex.Message}");
            }
        }


        private void SendBarsToSql(List<BarData> bars)
        {
            if (bars == null || bars.Count == 0) return;

            try
            {
                if (_connectionManager == null)
                {
                    Print("ERROR: Connection manager is null!");
                    return;
                }

                var connection = _connectionManager.GetConnection();
                if (connection.State != ConnectionState.Open)
                {
                    Print($"ERROR: SQL connection is not open! State: {connection.State}");
                    return;
                }

                // Создаем DataTable для tms.BarsTableType
                DataTable barsTable = new ();
                barsTable.Columns.Add("TickerJID", typeof(int));
                barsTable.Columns.Add("barTime", typeof(DateTime));
                barsTable.Columns.Add("timeframeID", typeof(int));
                barsTable.Columns.Add("openValue", typeof(double));
                barsTable.Columns.Add("closeValue", typeof(double));
                barsTable.Columns.Add("highValue", typeof(double));
                barsTable.Columns.Add("lowValue", typeof(double));
                barsTable.Columns.Add("sourceID", typeof(int));

                foreach (var bar in bars)
                {
                    DataRow row = barsTable.NewRow();
                    row["TickerJID"] = bar.TickerJID;
                    row["barTime"] = bar.BarTime;
                    row["timeframeID"] = bar.TimeFrameID;
                    row["openValue"] = bar.OpenValue;
                    row["closeValue"] = bar.CloseValue;
                    row["highValue"] = bar.HighValue;
                    row["lowValue"] = bar.LowValue;
                    row["sourceID"] = bar.SourceID;

                    barsTable.Rows.Add(row);
                }

                // Вызываем хранимую процедуру
                using SqlCommand cmd = new("tms.sp_MergeBars", connection);
                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter param = cmd.Parameters.AddWithValue("@bars", barsTable);
                param.SqlDbType = SqlDbType.Structured;
                param.TypeName = "tms.BarsTableType";

                int rowsAffected = cmd.ExecuteNonQuery();
                Print($"Bars sent to SQL: {rowsAffected} rows affected for {bars.Count} bars");
            }
            catch (Exception ex)
            {
                Print($"Error sending bars to SQL: {ex.Message}");
                Print($"StackTrace: {ex.StackTrace}");
            }
        }

        private void LoadHistoricalBars()
        {
            if (!CollectBars) return;

            try
            {
                // Парсим даты из параметров
                if (!DateTime.TryParse(CollectFromDate, out DateTime requestedStartDate))
                {
                    Print($"ERROR: Invalid CollectFromDate format: {CollectFromDate}");
                    return;
                }

                if (!DateTime.TryParse(CollectToDate, out DateTime requestedEndDate))
                {
                    Print($"ERROR: Invalid CollectToDate format: {CollectToDate}");
                    return;
                }

                // Убедимся, что даты в UTC
                requestedStartDate = DateTime.SpecifyKind(requestedStartDate, DateTimeKind.Utc);
                requestedEndDate = DateTime.SpecifyKind(requestedEndDate, DateTimeKind.Utc);

                // Корректируем: если endDate меньше startDate, меняем местами
                if (requestedEndDate < requestedStartDate)
                {
                    (requestedStartDate, requestedEndDate) = (requestedEndDate, requestedStartDate);
                    Print($"WARNING: Dates swapped. Using {requestedStartDate:yyyy-MM-dd} to {requestedEndDate:yyyy-MM-dd}");
                }

                Print($"=== LOADING HISTORICAL BARS ({requestedStartDate:yyyy-MM-dd} to {requestedEndDate:yyyy-MM-dd}) ===");

                var symbols = SymbolsToCollect.Split(',');
                int totalHistoricalBars = 0;

                foreach (var symbolName in symbols)
                {
                    string cleanSymbol = symbolName.Trim();

                    if (string.IsNullOrEmpty(cleanSymbol))
                        continue;

                    if (!Symbols.Exists(cleanSymbol))
                    {
                        Print($"  {cleanSymbol}: Symbol not found");
                        continue;
                    }

                    var symbol = Symbols.GetSymbol(cleanSymbol);
                    Print($"  Loading historical data for {symbol.Name}...");

                    try
                    {
                        // ПРОВЕРЯЕМ, КАКИЕ ДАННЫЕ УЖЕ ЕСТЬ В БАЗЕ
                        DateTime? lastBarTimeInDb = GetLastBarTimeFromDatabase(symbol.Name);

                        // Если в базе уже есть данные, начинаем с последнего бара + 1 минута
                        if (lastBarTimeInDb.HasValue && lastBarTimeInDb.Value > requestedStartDate)
                        {
                            Print($"    Last bar in database: {lastBarTimeInDb.Value:yyyy-MM-dd HH:mm:ss}");
                            Print($"    Skipping already loaded data");
                            requestedStartDate = lastBarTimeInDb.Value.AddMinutes(1);

                            if (requestedStartDate >= requestedEndDate)
                            {
                                Print($"    All data already loaded, skipping");
                                continue;
                            }
                        }

                        // Получаем исторические бары за указанный период
                        var historicalBars = GetHistoricalBars(symbol, BarsTimeFrame, requestedStartDate, requestedEndDate);

                        if (historicalBars != null && historicalBars.Count > 0)
                        {
                            Print($"    Found {historicalBars.Count} historical bars since {requestedStartDate:yyyy-MM-dd}");

                            int barsProcessed = ProcessHistoricalBarsForSymbol(symbol, historicalBars);
                            totalHistoricalBars += barsProcessed;

                            Print($"    Processed {barsProcessed} historical bars");
                        }
                        else
                        {
                            Print($"    No historical data found in this period");
                        }
                    }
                    catch (Exception ex)
                    {
                        Print($"    ERROR loading historical data: {ex.Message}");
                    }
                }

                Print($"=== HISTORICAL LOAD COMPLETE: {totalHistoricalBars} bars loaded ===");
            }
            catch (Exception ex)
            {
                Print($"Error in LoadHistoricalBars: {ex.Message}");
            }
        }

        private DateTime? GetLastBarTimeFromDatabase(string symbolName)
        {
            try
            {
                if (!_symbolTickerJids.ContainsKey(symbolName))
                {
                    return null;
                }

                int tickerJID = _symbolTickerJids[symbolName];
                int timeFrameID = GetTimeFrameId(BarsTimeFrame);

                using SqlCommand cmd = new(
                    @"SELECT MAX(barTime) FROM tms.Bars 
              WHERE TickerJID = @tickerJID AND timeframeID = @timeframeID",
                    _connectionManager.GetConnection());

                cmd.Parameters.AddWithValue("@tickerJID", tickerJID);
                cmd.Parameters.AddWithValue("@timeframeID", timeFrameID);

                var result = cmd.ExecuteScalar();

                if (result != null && result != DBNull.Value)
                {
                    return Convert.ToDateTime(result);
                }

                return null;
            }
            catch (Exception ex)
            {
                Print($"Error getting last bar time from DB for {symbolName}: {ex.Message}");
                return null;
            }
        }

        private SqlAccountData GetSqlAccountData()
        {
            return new SqlAccountData
            {
                Broker = Account.BrokerName,
                AccountNumber = Account.Number.ToString(),
                PlatformCode = "cTrader",
            };
        }

        private string GetSqlScript(Position[] positions)
        {
            if (positions.Length == 0)
                return "-- No positions to process";

            StringBuilder sqlValues = new();

            // Формируем данные для trd.PositionDataTableType
            for (int i = 0; i < positions.Length; i++)
            {
                var position = positions[i];
                string openTime = position.EntryTime.ToString("yyyy-MM-dd HH:mm:ss");

                string uuidValue = Guid.TryParse(position.Label, out Guid positionUuid) ? positionUuid.ToString() : "NULL";

                sqlValues.Append($"('{uuidValue}',");
                sqlValues.Append($"'{position.Id}',");           // positionTicket
                sqlValues.Append($"'{position.SymbolName?.Replace("'", "''") ?? ""}',");  // Symbol
                sqlValues.Append($"'{position.TradeType}',");    // TradeType
                sqlValues.Append($"'{position.VolumeInUnits:F2}',");  // Volume
                sqlValues.Append($"'{position.EntryPrice:F5}',");     // EntryPrice
                sqlValues.Append($"'{position.CurrentPrice:F5}',");   // CurrentPrice
                sqlValues.Append($"'{position.StopLoss?.ToString("F5") ?? ""}',");  // StopLoss
                sqlValues.Append($"'{position.TakeProfit?.ToString("F5") ?? ""}',"); // TakeProfit
                sqlValues.Append($"'{position.GrossProfit:F2}',");    // GrossProfit
                sqlValues.Append($"'{position.NetProfit:F2}',");      // NetProfit
                sqlValues.Append($"'{position.Swap:F2}',");           // Swap
                sqlValues.Append($"'{position.Margin:F2}',");         // Margin
                sqlValues.Append($"'{position.Commissions:F2}',");    // Commission
                sqlValues.Append($"'{openTime}')");                   // OpenTime (без Comment!)

                if (i < positions.Length - 1)
                    sqlValues.AppendLine(", ");
                else
                    sqlValues.AppendLine();
            }

            string broker = Account.BrokerName;
            string accountNumber = Account.Number.ToString();
            string platformCode = "cTrader";

            string sqlScript = $@"
        declare @positions trd.PositionDataTableType
        insert into @positions values 
        {sqlValues}
        
        declare @broker VARCHAR(MAX) = '{broker.Replace("'", "''")}'
            , @account varchar(50) = '{accountNumber}'
            , @platformCode NVARCHAR(20) = '{platformCode}';

        declare @accountID  int = trd.account_ID(@account, @broker, @platformCode);
        
        exec trd.positions_p @positions, @broker, @account, @platformCode;";

            return sqlScript;
        }

        private static string GetEquitySqlScript(SqlAccountData accountData, decimal amount, decimal marginUsed, decimal marginFree, decimal marginLevel)
        {
            string sqlScript = $@"
        exec fin.equity_p 
            @account = '{accountData.AccountNumber}'
            , @broker = '{accountData.Broker.Replace("'", "''")}'
            , @platformCode = '{accountData.PlatformCode}'
            , @amount = {amount:F2}
            , @marginUsed = {marginUsed:F2}
            , @marginFree = {marginFree:F2}
            , @marginLevel = {marginLevel:F6};";

            return sqlScript;
        }

        private List<Bar> GetHistoricalBars(Symbol symbol, TimeFrame timeFrame, DateTime startDate, DateTime endDate)
        {
            var bars = new List<Bar>();

            try
            {
                // Получаем исторические бары через MarketData
                var historicalSeries = MarketData.GetBars(timeFrame, symbol.Name);

                if (historicalSeries == null || historicalSeries.Count == 0)
                {
                    Print($"    No bars available for {symbol.Name} ({timeFrame})");
                    return bars;
                }

                Print($"    Total bars in series: {historicalSeries.Count}");
                Print($"    First bar: {historicalSeries.First().OpenTime}");
                Print($"    Last bar: {historicalSeries.Last().OpenTime}");

                // Фильтруем бары по заданному диапазону дат
                for (int i = 0; i < historicalSeries.Count; i++)
                {
                    var bar = historicalSeries[i];
                    if (bar.OpenTime >= startDate && bar.OpenTime <= endDate)
                    {
                        bars.Add(bar);
                    }
                }

                // Если не нашли бары в диапазоне, нощем ближайшие
                if (bars.Count == 0 && historicalSeries.Count > 0)
                {
                    Print($"    No bars in range {startDate:yyyy-MM-dd} to {endDate:yyyy-MM-dd}");
                    Print($"    Available range: {historicalSeries.First().OpenTime:yyyy-MM-dd} to {historicalSeries.Last().OpenTime:yyyy-MM-dd}");
                }
            }
            catch (Exception ex)
            {
                Print($"Error getting historical bars for {symbol.Name}: {ex.Message}");
            }

            return bars;
        }

        private void ExecuteSql(string sqlScript)
        {
            if (_connectionManager == null)
            {
                Print("Connection manager not initialized");
                return;
            }

            try
            {
                using SqlCommand command = new(sqlScript, _connectionManager.GetConnection());
                using SqlDataReader reader = command.ExecuteReader();

                Print("=== DATASET RESULTS ===");

                if (reader.HasRows)
                {
                    int fieldCount = reader.FieldCount;
                    string[] columnNames = new string[fieldCount];
                    for (int i = 0; i < fieldCount; i++)
                    {
                        columnNames[i] = reader.GetName(i);
                    }

                    Print($"Columns: {string.Join(", ", columnNames)}");
                    Print("------------------");

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
            catch (Exception ex)
            {
                Print($"Error executing SQL: {ex.Message}");
            }
        }

        private void InitializeBarCollection()
        {
            try
            {
                Print("=== INITIALIZING BAR COLLECTION ===");

                // Инициализируем словарь времени последних обработанных баров
                var symbols = SymbolsToCollect.Split(',');
                foreach (var symbolName in symbols)
                {
                    string cleanSymbol = symbolName.Trim();
                    if (!string.IsNullOrEmpty(cleanSymbol) && !_lastProcessedBarTime.ContainsKey(cleanSymbol))
                    {
                        _lastProcessedBarTime[cleanSymbol] = DateTime.MinValue;
                    }
                }

                // Заполняем TimeFrameIds словарь (теперь он должен существовать!)
                if (_timeFrameIds != null)
                {
                    _timeFrameIds[TimeFrame.Minute] = 1;      // M1
                    _timeFrameIds[TimeFrame.Minute5] = 2;     // M5
                    _timeFrameIds[TimeFrame.Minute15] = 3;    // M15
                    _timeFrameIds[TimeFrame.Minute30] = 4;    // M30
                    _timeFrameIds[TimeFrame.Hour] = 5;        // H1
                    _timeFrameIds[TimeFrame.Hour4] = 6;       // H4
                    _timeFrameIds[TimeFrame.Daily] = 7;       // D1
                    _timeFrameIds[TimeFrame.Weekly] = 8;      // W1
                    _timeFrameIds[TimeFrame.Monthly] = 9;     // MN1
                }

                Print($"Bar collection initialized:");
                Print($"  Symbols: {string.Join(", ", _lastProcessedBarTime.Keys)}");
                Print($"  TimeFrame: {BarsTimeFrame} (ID: {GetTimeFrameId(BarsTimeFrame)})");
                Print($"  SourceID: {SourceId}");
                Print("=== BAR COLLECTION INITIALIZED ===");
            }
            catch (Exception ex)
            {
                Print($"Error initializing bar collection: {ex.Message}");
            }
        }

        protected override void OnStop()
        {
            if (_connectionManager != null)
            {
                _connectionManager.Close();
                Print("SQL Connection closed");
            }

            Positions.Opened -= OnPositionOpened;
            Positions.Closed -= OnPositionClosed;
            Positions.Modified -= OnPositionModified;
            PendingOrders.Created -= OnPendingOrderCreated;
            PendingOrders.Filled -= OnPendingOrderFilled;
            PendingOrders.Cancelled -= OnPendingOrderCancelled;
            PendingOrders.Modified -= OnPendingOrderModified;

            Print("=== POSITION LISTER STOPPED ===");
            Print($"Stop Time: {Server.Time:yyyy-MM-dd HH:mm:ss}");
            Print("=================================");

            _signalTimer?.Dispose();

        }
    }

    public class SqlAccountData
    {
        public string Broker { get; set; }
        public string AccountNumber { get; set; }
        public string PlatformCode { get; set; }

    }

    public class ConnectionManager
    {
        private SqlConnection _connection;
        private readonly string _connectionString;

        public ConnectionManager(string connectionString)
        {
            _connectionString = connectionString;
        }

        public SqlConnection GetConnection()
        {
            if (_connection == null || _connection.State != ConnectionState.Open)
            {
                // Open if not already open
                Open();
            }
            return _connection;
        }

        public void Open()
        {
            try
            {
                _connection = new SqlConnection(_connectionString);
                _connection.Open();
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to open SQL connection: {ex.Message}");
            }
        }

        public void Close()
        {
            if (_connection != null)
            {
                if (_connection.State == ConnectionState.Open)
                {
                    _connection.Close();
                }
                _connection.Dispose();
                _connection = null;
            }
        }
    }

    public class PendingOrderData
    {
        public Guid OrderUuid { get; set; }
        public string OrderTicket { get; set; }
        public string Symbol { get; set; }
        public string OrderTypeName { get; set; }  // Используем строку как в SQL
        public string OrderDirection { get; set; } // Используем строку как в SQL
        public double Volume { get; set; }
        public double? TargetPrice { get; set; }
        public double? StopLoss { get; set; }
        public double? TakeProfit { get; set; }
        public string OrderStatus { get; set; }
    }
    // Добавляем после класса PendingOrderData:

    public class BarData
    {
        public int TickerJID { get; set; }
        public DateTime BarTime { get; set; }
        public int TimeFrameID { get; set; }
        public double OpenValue { get; set; }
        public double CloseValue { get; set; }
        public double HighValue { get; set; }
        public double LowValue { get; set; }
        public int SourceID { get; set; }
    }
}










