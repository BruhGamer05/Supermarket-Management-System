# app/routes/owner_routes.py
# Owner-only: suppliers, employees, insight views

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from mysql.connector import MySQLConnection
from app.database import get_db
from app.auth import require_role

router = APIRouter(prefix="/owner", tags=["Owner Insights"])

OWNER_ONLY = Depends(require_role("Owner"))


# ── Suppliers ─────────────────────────────────────────────────

class NewSupplier(BaseModel):
    supplier_name: str
    phone_number: str | None = None
    gstin: str | None = None
    shop_bldg_no: str | None = None
    street: str | None = None
    area: str | None = None
    city: str | None = None
    state: str | None = None
    pin_code: str | None = None


@router.get("/suppliers")
def list_suppliers(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM Supplier ORDER BY Supplier_Name")
    result = cur.fetchall()
    cur.close()
    return result


@router.post("/suppliers", status_code=201)
def add_supplier(body: NewSupplier, db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    cur = db.cursor()
    try:
        cur.execute("""
            INSERT INTO Supplier
              (Supplier_Name, Phone_Number, GSTIN, Shop_Bldg_No, Street, Area, City, State, PIN_Code)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (body.supplier_name, body.phone_number, body.gstin, body.shop_bldg_no,
              body.street, body.area, body.city, body.state, body.pin_code))
        db.commit()
        sid = cur.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"supplier_id": sid, "supplier_name": body.supplier_name}


# ── Employees ─────────────────────────────────────────────────

class NewEmployee(BaseModel):
    name: str
    phone_number: str | None = None
    shift_schedule: str | None = None
    category_id: int | None = None


@router.get("/employees")
def list_employees(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT e.Employee_ID, e.Name, e.Phone_Number, e.Shift_Schedule, c.Category_Name
        FROM Employee e
        LEFT JOIN Category c ON c.Category_ID = e.Category_ID
        ORDER BY e.Name
    """)
    result = cur.fetchall()
    cur.close()
    return result


@router.post("/employees", status_code=201)
def add_employee(body: NewEmployee, db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    cur = db.cursor()
    try:
        cur.execute("""
            INSERT INTO Employee (Name, Phone_Number, Shift_Schedule, Category_ID)
            VALUES (%s, %s, %s, %s)
        """, (body.name, body.phone_number, body.shift_schedule, body.category_id))
        db.commit()
        eid = cur.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"employee_id": eid, "name": body.name}


# ── Insight views ─────────────────────────────────────────────

def _fetch_view(view_name: str, db: MySQLConnection):
    cur = db.cursor(dictionary=True)
    cur.execute(f"SELECT * FROM {view_name}")
    result = cur.fetchall()
    cur.close()
    return result


@router.get("/insights/low-stock")
def low_stock(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_low_stock", db)


@router.get("/insights/expiring-batches")
def expiring_batches(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_expiring_batches", db)


@router.get("/insights/sales-by-day")
def sales_by_day(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_sales_by_day", db)


@router.get("/insights/sales-by-month")
def sales_by_month(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_sales_by_month", db)


@router.get("/insights/sales-by-category")
def sales_by_category(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_sales_by_category", db)


@router.get("/insights/top-items")
def top_items(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_top_items", db)


@router.get("/insights/top-customers")
def top_customers(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_top_customers", db)


@router.get("/insights/profit")
def profit_per_item(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_profit_per_item", db)


@router.get("/insights/employee-performance")
def employee_performance(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_employee_performance", db)


@router.get("/insights/product-demand")
def product_demand(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_product_demand", db)


@router.get("/insights/restock-list")
def restock_list(db: MySQLConnection = Depends(get_db), _=OWNER_ONLY):
    return _fetch_view("v_restock_list", db)
