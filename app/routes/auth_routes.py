# app/routes/auth_routes.py
# Login endpoint + first-time owner setup script logic.

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from mysql.connector import MySQLConnection
from app.database import get_db
from app.auth import hash_password, verify_password, create_token

router = APIRouter(prefix="/auth", tags=["Auth"])


class LoginRequest(BaseModel):
    username: str
    password: str


class CreateUserRequest(BaseModel):
    username: str
    password: str
    role: str           # 'Owner' | 'Employee' | 'Customer'
    employee_id: int | None = None
    customer_id: int | None = None


@router.post("/login")
def login(body: LoginRequest, db: MySQLConnection = Depends(get_db)):
    """
    Authenticate a user and return a JWT.
    The token encodes user_id, username, role — sent as Bearer header for all other requests.
    """
    cur = db.cursor(dictionary=True)
    cur.execute(
        "SELECT User_ID, Username, Password_Hash, Role FROM Users WHERE Username = %s",
        (body.username,)
    )
    user = cur.fetchone()
    cur.close()

    if not user or not verify_password(body.password, user["Password_Hash"]):
        raise HTTPException(status_code=401, detail="Invalid username or password.")

    token = create_token(user["User_ID"], user["Username"], user["Role"])
    return {"access_token": token, "token_type": "bearer", "role": user["Role"]}


@router.post("/register", status_code=201)
def register_user(body: CreateUserRequest, db: MySQLConnection = Depends(get_db)):
    """
    Create a new user account. In production, restrict this to Owner only.
    For the demo, it's open so you can create the first owner account.
    Role rules (enforced by DB CHECK constraint):
      Owner    → employee_id=None, customer_id=None
      Employee → employee_id required
      Customer → customer_id required
    """
    if body.role not in ("Owner", "Employee", "Customer"):
        raise HTTPException(status_code=400, detail="Role must be Owner, Employee or Customer.")

    cur = db.cursor()
    try:
        cur.execute(
            """INSERT INTO Users (Username, Password_Hash, Role, Employee_ID, Customer_ID)
               VALUES (%s, %s, %s, %s, %s)""",
            (body.username, hash_password(body.password), body.role,
             body.employee_id, body.customer_id)
        )
        db.commit()
        user_id = cur.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()

    return {"user_id": user_id, "username": body.username, "role": body.role}
