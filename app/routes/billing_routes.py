# app/routes/billing_routes.py
# Create bills (Employee/Owner), view bills (role-filtered)

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from mysql.connector import MySQLConnection
import json
from app.database import get_db
from app.auth import get_current_user, require_role

router = APIRouter(prefix="/bills", tags=["Billing"])


class BillItem(BaseModel):
    item_id: int
    qty: int


class CreateBillRequest(BaseModel):
    phone: str | None = None        # None = true walk-in
    employee_id: int
    payment_method: str             # Cash | Card | UPI
    items: list[BillItem]
    redeem_points: int = 0


class FeedbackRequest(BaseModel):
    rating: int         # 1-5
    comments: str | None = None


@router.post("/", status_code=201)
def create_bill(
    body: CreateBillRequest,
    db: MySQLConnection = Depends(get_db),
    _user=Depends(require_role("Owner", "Employee")),
):
    """
    Create a complete bill via sp_create_bill.
    - phone: provide customer phone number to earn/redeem loyalty.
              Leave null for anonymous walk-in.
    - items: list of {item_id, qty}
    - redeem_points: how many loyalty points to spend (0 = none)
    Returns: Bill_ID, Amount_Payable, Points_Earned, Points_Redeemed, Is_New_Customer
    """
    if not body.items:
        raise HTTPException(status_code=400, detail="Bill must have at least one item.")
    if body.payment_method not in ("Cash", "Card", "UPI"):
        raise HTTPException(status_code=400, detail="payment_method must be Cash, Card or UPI.")

    items_json = json.dumps([{"item_id": it.item_id, "qty": it.qty} for it in body.items])

    cur = db.cursor(dictionary=True)
    try:
        cur.callproc("sp_create_bill", [
            body.phone, body.employee_id, body.payment_method,
            items_json, body.redeem_points
        ])
        db.commit()
        for result in cur.stored_results():
            row = result.fetchone()
            return row
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()


@router.get("/")
def list_bills(
    db: MySQLConnection = Depends(get_db),
    user=Depends(get_current_user),
):
    """
    Owner/Employee: see all bills.
    Customer: see only their own bills (matched via Customer_ID on their Users record).
    """
    cur = db.cursor(dictionary=True)
    if user["role"] == "Customer":
        # Find this customer's Customer_ID from Users
        cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
        row = cur.fetchone()
        if not row or not row["Customer_ID"]:
            cur.close()
            return []
        cur.execute("""
            SELECT b.Bill_ID, b.Date_Time, b.Payment_Method,
                   vbt.Gross_Total, vbt.Points_Discount, vbt.Amount_Payable
            FROM Bill b
            JOIN v_bill_totals vbt ON vbt.Bill_ID = b.Bill_ID
            WHERE b.Customer_ID = %s
            ORDER BY b.Date_Time DESC
        """, (row["Customer_ID"],))
    else:
        cur.execute("""
            SELECT b.Bill_ID, b.Date_Time, b.Payment_Method,
                   CONCAT(c.First_Name,' ',COALESCE(c.Last_Name,'')) AS Customer_Name,
                   c.Phone_Number,
                   e.Name AS Cashier,
                   vbt.Gross_Total, vbt.Points_Discount, vbt.Amount_Payable
            FROM Bill b
            LEFT JOIN Customer c ON c.Customer_ID = b.Customer_ID
            LEFT JOIN Employee e ON e.Employee_ID = b.Employee_ID
            JOIN v_bill_totals vbt ON vbt.Bill_ID = b.Bill_ID
            ORDER BY b.Date_Time DESC
        """)
    bills = cur.fetchall()
    cur.close()
    return bills


@router.get("/{bill_id}")
def get_bill(bill_id: int, db: MySQLConnection = Depends(get_db), user=Depends(get_current_user)):
    """Get full line-by-line breakdown of a bill."""
    cur = db.cursor(dictionary=True)

    # Security: customers can only view their own bills
    if user["role"] == "Customer":
        cur.execute("SELECT Customer_ID FROM Users WHERE User_ID = %s", (user["sub"],))
        row = cur.fetchone()
        cur.execute("SELECT Customer_ID FROM Bill WHERE Bill_ID = %s", (bill_id,))
        bill_owner = cur.fetchone()
        if not bill_owner or bill_owner["Customer_ID"] != row["Customer_ID"]:
            raise HTTPException(status_code=403, detail="Access denied.")

    cur.execute("SELECT * FROM v_bill_lines WHERE Bill_ID = %s", (bill_id,))
    lines = cur.fetchall()
    cur.execute("SELECT * FROM v_bill_totals WHERE Bill_ID = %s", (bill_id,))
    totals = cur.fetchone()
    cur.close()

    if not totals:
        raise HTTPException(status_code=404, detail="Bill not found.")
    return {"totals": totals, "lines": lines}


@router.post("/{bill_id}/feedback", status_code=201)
def add_feedback(
    bill_id: int,
    body: FeedbackRequest,
    db: MySQLConnection = Depends(get_db),
    _user=Depends(require_role("Customer")),
):
    """Customer rates the employee who handled their bill (1–5 stars)."""
    if not 1 <= body.rating <= 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5.")
    cur = db.cursor()
    try:
        cur.execute(
            "INSERT INTO Employee_Feedback (Bill_ID, Rating, Comments) VALUES (%s, %s, %s)",
            (bill_id, body.rating, body.comments)
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"message": "Feedback submitted."}
