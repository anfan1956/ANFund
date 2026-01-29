cat > test_framework.py << 'EOF'
"""
Test ANFramework connection functionality
"""

from anFramework import EnvironmentConfig, LocalConnectionProvider, DatabaseHelper, StrategyBase


def test_environment_config():
    """Test environment configuration"""
    print("=== Testing EnvironmentConfig ===")

    conn_str = EnvironmentConfig.get_connection_string()
    print(f"✓ Connection string retrieved: {conn_str[:50]}...")

    # Test connection
    import pyodbc
    conn = pyodbc.connect(conn_str, timeout=5)
    cursor = conn.cursor()
    cursor.execute("SELECT DB_NAME() as db, USER_NAME() as user")
    row = cursor.fetchone()
    print(f"✓ Database connection: {row.db} as {row.user}")
    cursor.close()
    conn.close()
    print("EnvironmentConfig: PASS\n")


def test_local_connection_provider():
    """Test connection provider with pool"""
    print("=== Testing LocalConnectionProvider ===")

    provider = LocalConnectionProvider(pool_size=5, max_overflow=2)

    # Get multiple connections
    connections = []
    for i in range(5):
        conn = provider.get_connection(autocommit=True)
        cursor = conn.cursor()
        cursor.execute("SELECT @@SPID as spid")
        spid = cursor.fetchone().spid
        print(f"  Connection {i + 1}: SPID={spid}")
        connections.append(conn)

    stats = provider.get_stats()
    print(f"✓ Pool stats: {stats}")

    # Return connections
    for conn in connections:
        provider.return_connection(conn)

    stats_after = provider.get_stats()
    print(f"✓ After return: {stats_after}")

    provider.close_all_connections()
    print("LocalConnectionProvider: PASS\n")


def test_database_helper():
    """Test database helper"""
    print("=== Testing DatabaseHelper ===")

    provider = LocalConnectionProvider(pool_size=3)
    db = DatabaseHelper(provider)

    # Test execute_query
    cursor = db.execute_query("SELECT @@VERSION as version")
    version = cursor.fetchone().version
    print(f"✓ SQL Server version: {version[:50]}...")
    cursor.close()

    # Test parameterized query
    cursor = db.execute_query("SELECT ? + ? as sum", (10, 20))
    result = cursor.fetchone().sum
    print(f"✓ Parameterized query: 10 + 20 = {result}")
    cursor.close()

    print(f"✓ Connection stats: {db.get_stats()}")
    provider.close_all_connections()
    print("DatabaseHelper: PASS\n")


def test_strategy_base():
    """Test base strategy"""
    print("=== Testing StrategyBase ===")

    class TestStrategy(StrategyBase):
        def _get_connection_string(self):
            # Not needed anymore, but keep for compatibility
            return EnvironmentConfig.get_connection_string()

    strategy = TestStrategy(configuration_id=999)

    # Get connection through strategy
    conn = strategy.get_connection(autocommit=True)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) as cnt FROM sys.tables")
    table_count = cursor.fetchone().cnt
    print(f"✓ Strategy connection works. Tables in DB: {table_count}")
    cursor.close()
    strategy.return_connection(conn)

    print(f"✓ Strategy stats: {strategy.db.get_stats()}")
    print("StrategyBase: PASS\n")


def main():
    """Run all tests"""
    print("ANFramework Connection Tests")
    print("=" * 40)

    try:
        test_environment_config()
        test_local_connection_provider()
        test_database_helper()
        test_strategy_base()

        print("=" * 40)
        print("ALL TESTS PASSED!")

    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    exit(main())

EOF

python
test_framework.py