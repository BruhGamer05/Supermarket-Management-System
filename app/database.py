# app/database.py
# Creates and manages the MySQL connection pool.
# Why a pool? Opening a new DB connection for every HTTP request is slow.
# A pool keeps a few connections open and reuses them.

import mysql.connector
from mysql.connector import pooling
from app.config import settings

# Connection pool: up to 10 simultaneous DB connections
_pool = pooling.MySQLConnectionPool(
    pool_name="supermarket_pool",
    pool_size=10,
    host=settings.db_host,
    port=settings.db_port,
    database=settings.db_name,
    user=settings.db_user,
    password=settings.db_password,
    autocommit=False,          # We manage transactions ourselves
    charset="utf8mb4",
)


def get_db():
    """
    FastAPI dependency: yields a DB connection, then closes it.
    Usage in a route:  db: Connection = Depends(get_db)
    """
    conn = _pool.get_connection()
    try:
        yield conn
    finally:
        conn.close()
