import os
from dotenv import load_dotenv
import pyodbc

load_dotenv()

server = os.getenv('ANFUND_DB_SERVER')
database = os.getenv('ANFUND_DB_NAME')
username = os.getenv('ANFUND_DB_USER')
password = os.getenv('ANFUND_DB_PASSWORD')

conn_str = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    f'SERVER={server};'
    f'DATABASE={database};'
    f'UID={username};'
    f'PWD={password};'
)

try:
    conn = pyodbc.connect(conn_str, timeout=5)
    cursor = conn.cursor()
    cursor.execute("SELECT DB_NAME() as database_name, USER_NAME() as username")
    row = cursor.fetchone()
    print(f"Connected successfully to: {row.database_name} as {row.username}")
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
