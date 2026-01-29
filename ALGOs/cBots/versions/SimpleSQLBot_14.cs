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
        private string GetOrderDirection(TradeType tradeType) => tradeType == TradeType.Buy ? "long" : "short";

        private string GetOrderTypeName(PendingOrderType orderType)
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


            Print("Event subscriptions initialized");
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
                StringBuilder sqlBuilder = new StringBuilder();
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

                    ProcessDataCollection(); // Без параметра

                    _lastBarTime = currentBarTime;
                }
            }
            catch (Exception ex)
            {
                Print($"Error in OnBar: {ex.Message}");
            }
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
}










