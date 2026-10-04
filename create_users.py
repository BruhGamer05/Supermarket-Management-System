import mysql.connector
import bcrypt
from app.config import settings

def hash_pw(pw):
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()

conn = mysql.connector.connect(
    host=settings.db_host,
    port=settings.db_port,
    database=settings.db_name,
    user=settings.db_user,
    password=settings.db_password
)
cur = conn.cursor()

users = [
    # (Username, Password_Hash, Role, Employee_ID, Customer_ID)
    ("owner", hash_pw("owner123"), "Owner", None, None),
    ("ramesh_emp", hash_pw("ramesh123"), "Employee", 1, None),
    ("anil_cust", hash_pw("anil123"), "Customer", None, 1),
    ("rekha_cust", hash_pw("rekha123"), "Customer", None, 2)
]

for u in users:
    try:
        cur.execute(
            "INSERT INTO Users (Username, Password_Hash, Role, Employee_ID, Customer_ID) VALUES (%s, %s, %s, %s, %s)",
            u
        )
        print(f"Created user: {u[0]} ({u[2]})")
    except Exception as e:
        print(f"Failed to create {u[0]}: {e}")

conn.commit()
cur.close()
conn.close()
