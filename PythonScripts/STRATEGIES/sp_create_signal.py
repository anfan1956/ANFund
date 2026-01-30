import pyodbc
from datetime import datetime


def execute_signal_procedure(
        connection,
        ticker,
        direction,
        volume,
        order_price,
        stop_loss,
        take_profit,
        expiry,
        broker_id,
        platform_id,
        trade_id=None,
        trade_type=None,
        strategy_configuration_id=None
):
    """
    Execute the stored procedure to create a trading signal

    Parameters:
    connection (pyodbc.Connection): Active database connection
    ticker (str): Instrument ticker (e.g., 'XAUUSD', 'EURUSD')
    direction (str): Trade direction: 'buy', 'sell', 'drop'
    volume (float): Trade volume in lots/units
    order_price (float or None): Order price (None for market order)
    stop_loss (float or None): Stop loss price
    take_profit (float or None): Take profit price
    expiry (datetime or None): Order expiry time
    broker_id (int): Broker identifier
    platform_id (int): Platform identifier
    trade_id (int or None): ID of existing trade to modify/close (for 'drop' direction)
    trade_type (str or None): Type of trade to close: 'POSITION' or 'PENDING ORDER'
    strategy_configuration_id (int or None): Strategy configuration ID

    Returns:
    bool: True if signal was sent successfully, False otherwise
    """
    try:
        cursor = connection.cursor()

        # Вызов процедуры с параметрами по порядку
        sql = "EXEC trd.sp_CreateSignal ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"

        cursor.execute(sql, (
            ticker,
            direction,
            volume,
            order_price,
            stop_loss,
            take_profit,
            expiry,
            broker_id,
            platform_id,
            trade_id,
            trade_type,
            strategy_configuration_id
        ))
        connection.commit()
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{current_time}] Signal SENT: {ticker} {direction} volume={volume}, "
              f"Trade ID: {trade_id}, Type: {trade_type}")

        cursor.close()
        return True

    except Exception as e:
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{current_time}] Error sending signal: {e}")
        return False


