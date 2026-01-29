import pyodbc


def main():
    connection_string = (
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=62.181.56.230;'
        'DATABASE=cTrader;'
        'UID=anfan;'
        'PWD=Gisele12!;'
    )

    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        sql = """
        select  
            ID , 
            orderUUID, 
            tradeType,
            ticker,
            direction, 
            entryPrice, 
            createdTime, 
            volume, 
            margin
        from trd.trades_v
        """

        cursor.execute(sql)

        # Get column names
        columns = [column[0] for column in cursor.description]
        print(" | ".join(columns))
        print("-" * 100)

        for row in cursor:
            print(f"{row.ID} | {row.orderUUID} | {row.tradeType} | {row.ticker} | {row.direction} | {row.entryPrice} | {row.createdTime} "
                  f"| {row.volume} | {row.margin}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()
