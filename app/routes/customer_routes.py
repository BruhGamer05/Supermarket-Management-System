# app/routes/customer_routes.py
# Customer profile, loyalty points, stock requests

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from mysql.connector import MySQLConnection
from app.database import get_db
from app.auth import get_current_user, require_role

router = APIRouter(prefix="/customers", tags=["Customers"])


class StockRequestBody(BaseModel):
    item_id: int | None = None               # for existing out-of-stock item
    requested_item_name: str | None = None   # for a brand-new product
    quantity_requested: int = 1


class UpdateProfileBody(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    shop_bldg_no: str | None = None
    street: str | None = None
    area: str | None = None
    city: str | None = None
    state: str | None = None
    pin_code: str | None = None


# ── Owner: list all customers ─────────────────────────────────

@router.get("/")
def list_customers(db: MySQLConnection = Depends(get_db),
                   _user=Depends(require_role("Owner", "Employee"))):
    cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT Customer_ID, First_Name, Last_Name, Phone_Number,
               Loyalty_Points, City
        FROM Customer ORDER BY First_Name
    """)
    result = cur.fetchall()
    cur.close()
    return result


# ── Customer: view own profile ────────────────────────────────

@router.get("/me")
def my_profile(db: MySQLConnection = Depends(get_db), user=Depends(get_current_user)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    if not row or not row["Customer_ID"]:
        raise HTTPException(status_code=404, detail="No customer profile linked to this account.")
    cur.execute("SELECT * FROM Customer WHERE Customer_ID = %s", (row["Customer_ID"],))
    profile = cur.fetchone()
    cur.close()
    return profile


@router.put("/me")
def update_profile(body: UpdateProfileBody, db: MySQLConnection = Depends(get_db),
                   user=Depends(get_current_user)):
    """Customer updates their own name/address. Walk-ins can fill in their real name here."""
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    if not row or not row["Customer_ID"]:
        raise HTTPException(status_code=404, detail="No customer profile linked.")
    cid = row["Customer_ID"]

    fields = {k: v for k, v in body.model_dump().items() if v is not None}
    if not fields:
        raise HTTPException(status_code=400, detail="Nothing to update.")

    col_map = {
        "first_name": "First_Name", "last_name": "Last_Name",
        "phone_number": "Phone_Number", "shop_bldg_no": "Shop_Bldg_No",
        "street": "Street", "area": "Area", "city": "City",
        "state": "State", "pin_code": "PIN_Code",
    }
    set_clause = ", ".join(f"{col_map[k]} = %s" for k in fields)
    params = list(fields.values()) + [cid]
    try:
        cur2 = db.cursor()
        cur2.execute(f"UPDATE Customer SET {set_clause} WHERE Customer_ID = %s", params)
        db.commit()
        cur2.close()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"message": "Profile updated."}


# ── Loyalty ───────────────────────────────────────────────────

@router.get("/me/loyalty")
def my_loyalty(db: MySQLConnection = Depends(get_db), user=Depends(get_current_user)):
    """Customer views their loyalty balance and transaction history."""
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    if not row or not row["Customer_ID"]:
        raise HTTPException(status_code=404, detail="No customer profile linked.")
    cid = row["Customer_ID"]

    cur.execute("SELECT Loyalty_Points FROM Customer WHERE Customer_ID = %s", (cid,))
    balance = cur.fetchone()
    cur.execute("""
        SELECT Txn_ID, Bill_ID, Txn_Type, Points_Change, Txn_Date
        FROM Loyalty_Transaction WHERE Customer_ID = %s
        ORDER BY Txn_Date DESC
    """, (cid,))
    history = cur.fetchall()
    cur.close()
    return {"balance": balance["Loyalty_Points"], "history": history}


# ── Stock requests ────────────────────────────────────────────

@router.post("/me/stock-requests", status_code=201)
def submit_stock_request(
    body: StockRequestBody,
    db: MySQLConnection = Depends(get_db),
    user=Depends(require_role("Customer")),
):
    """
    Customer submits a stock request.
    Provide EITHER item_id (existing out-of-stock item) OR requested_item_name (new product).
    The DB CHECK constraint enforces exactly one.
    """
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    if not row or not row["Customer_ID"]:
        raise HTTPException(status_code=404, detail="No customer profile linked.")
    cid = row["Customer_ID"]
    cur.close()

    cur2 = db.cursor()
    try:
        cur2.execute("""
            INSERT INTO Stock_Request (Customer_ID, Item_ID, Requested_Item_Name, Quantity_Requested)
            VALUES (%s, %s, %s, %s)
        """, (cid, body.item_id, body.requested_item_name, body.quantity_requested))
        db.commit()
        req_id = cur2.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur2.close()
    return {"request_id": req_id, "status": "Pending"}


@router.get("/me/stock-requests")
def my_stock_requests(db: MySQLConnection = Depends(get_db), user=Depends(require_role("Customer"))):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    if not row or not row["Customer_ID"]:
        cur.close()
        return []
    cur.execute("""
        SELECT sr.Request_ID, i.Item_Name, sr.Requested_Item_Name,
               sr.Quantity_Requested, sr.Status, sr.Remarks, sr.Request_Date
        FROM Stock_Request sr
        LEFT JOIN Item i ON i.Item_ID = sr.Item_ID
        WHERE sr.Customer_ID = %s
        ORDER BY sr.Request_Date DESC
    """, (row["Customer_ID"],))
    result = cur.fetchall()
    cur.close()
    return result


# ── Employee/Owner: manage all stock requests ─────────────────

@router.get("/stock-requests")
def all_stock_requests(
    status: str | None = None,
    db: MySQLConnection = Depends(get_db),
    _user=Depends(require_role("Owner", "Employee")),
):
    cur = db.cursor(dictionary=True)
    sql = """
        SELECT sr.Request_ID,
               CONCAT(c.First_Name,' ',COALESCE(c.Last_Name,'')) AS Customer_Name,
               c.Phone_Number,
               i.Item_Name, sr.Requested_Item_Name,
               sr.Quantity_Requested, sr.Status, sr.Remarks,
               e.Name AS Handled_By_Name, sr.Request_Date
        FROM Stock_Request sr
        JOIN Customer c    ON c.Customer_ID = sr.Customer_ID
        LEFT JOIN Item i   ON i.Item_ID     = sr.Item_ID
        LEFT JOIN Employee e ON e.Employee_ID = sr.Handled_By
        WHERE 1=1
    """
    params = []
    if status:
        sql += " AND sr.Status = %s"
        params.append(status)
    sql += " ORDER BY sr.Request_Date DESC"
    cur.execute(sql, params)
    result = cur.fetchall()
    cur.close()
    return result


class ResolveRequest(BaseModel):
    new_status: str         # Approved | Rejected | Fulfilled
    remarks: str | None = None
    item_id: int | None = None   # link Item if fulfilling a new-product request


@router.patch("/stock-requests/{request_id}")
def resolve_stock_request(
    request_id: int,
    body: ResolveRequest,
    db: MySQLConnection = Depends(get_db),
    user=Depends(require_role("Owner", "Employee")),
):
    """Call sp_resolve_stock_request to approve/reject/fulfil a request."""
    # employee_id = the Employee linked to this user's account
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT Employee_ID FROM Users WHERE User_ID = %s", (user["sub"],))
    row = cur.fetchone()
    emp_id = row["Employee_ID"] if row else None
    cur.close()

    cur2 = db.cursor(dictionary=True)
    try:
        cur2.callproc("sp_resolve_stock_request",
                      [request_id, body.new_status, emp_id, body.remarks, body.item_id])
        db.commit()
        for result in cur2.stored_results():
            return result.fetchone()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur2.close()
