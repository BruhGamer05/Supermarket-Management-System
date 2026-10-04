# app/routes/item_routes.py
# Browse items, categories, batches (all roles can read; Owner can write)

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from mysql.connector import MySQLConnection
from app.database import get_db
from app.auth import get_current_user, require_role

router = APIRouter(prefix="/items", tags=["Items & Inventory"])


# ── Read endpoints (any logged-in user) ──────────────────────

@router.get("/")
def list_items(
    search: str | None = Query(None, description="Search by item name"),
    category_id: int | None = Query(None),
    db: MySQLConnection = Depends(get_db),
    _user=Depends(get_current_user),
):
    """List all items with their total live stock. Supports name search and category filter."""
    cur = db.cursor(dictionary=True)
    sql = """
        SELECT i.Item_ID, i.Item_Name, c.Category_Name,
               COALESCE(SUM(b.Live_Stock), 0) AS Total_Stock
        FROM Item i
        LEFT JOIN Category c ON c.Category_ID = i.Category_ID
        LEFT JOIN Batch b    ON b.Item_ID = i.Item_ID
        WHERE 1=1
    """
    params = []
    if search:
        sql += " AND i.Item_Name LIKE %s"
        params.append(f"%{search}%")
    if category_id:
        sql += " AND i.Category_ID = %s"
        params.append(category_id)
    sql += " GROUP BY i.Item_ID, i.Item_Name, c.Category_Name ORDER BY i.Item_Name"
    cur.execute(sql, params)
    items = cur.fetchall()
    cur.close()
    return items


@router.get("/categories")
def list_categories(db: MySQLConnection = Depends(get_db), _user=Depends(get_current_user)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM Category ORDER BY Category_Name")
    result = cur.fetchall()
    cur.close()
    return result


@router.get("/batches")
def list_batches(
    item_id: int | None = Query(None),
    in_stock_only: bool = Query(False),
    db: MySQLConnection = Depends(get_db),
    _user=Depends(get_current_user),
):
    """List batches. Filter by item or show only batches with stock > 0."""
    cur = db.cursor(dictionary=True)
    sql = """
        SELECT b.Batch_ID, i.Item_Name, s.Supplier_Name,
               b.HSN_Code, h.GST_Percentage,
               b.Purchase_Price, b.Wholesale_Price,
               b.Live_Stock, b.Received_Date, b.Expiry_Date
        FROM Batch b
        JOIN Item i        ON i.Item_ID     = b.Item_ID
        LEFT JOIN Supplier s ON s.Supplier_ID = b.Supplier_ID
        JOIN HSN_Tax_Rate h ON h.HSN_Code   = b.HSN_Code
        WHERE 1=1
    """
    params = []
    if item_id:
        sql += " AND b.Item_ID = %s"
        params.append(item_id)
    if in_stock_only:
        sql += " AND b.Live_Stock > 0"
    sql += " ORDER BY b.Expiry_Date ASC"
    cur.execute(sql, params)
    result = cur.fetchall()
    cur.close()
    return result


@router.get("/{item_id}")
def get_item(item_id: int, db: MySQLConnection = Depends(get_db), _user=Depends(get_current_user)):
    cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT i.Item_ID, i.Item_Name, c.Category_Name,
               COALESCE(SUM(b.Live_Stock), 0) AS Total_Stock
        FROM Item i
        LEFT JOIN Category c ON c.Category_ID = i.Category_ID
        LEFT JOIN Batch b    ON b.Item_ID = i.Item_ID
        WHERE i.Item_ID = %s
        GROUP BY i.Item_ID, i.Item_Name, c.Category_Name
    """, (item_id,))
    item = cur.fetchone()
    cur.close()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found.")
    return item


# ── Write endpoints (Owner only) ─────────────────────────────

class NewItem(BaseModel):
    item_name: str
    category_id: int | None = None


class NewCategory(BaseModel):
    category_name: str
    aisle_location: str | None = None


class ReceiveStockRequest(BaseModel):
    item_id: int
    supplier_id: int | None = None
    hsn_code: str
    purchase_price: float
    wholesale_price: float
    quantity: int
    received_date: str          # YYYY-MM-DD
    expiry_date: str | None = None
    check_procures: bool = True


@router.post("/", status_code=201)
def create_item(body: NewItem, db: MySQLConnection = Depends(get_db),
                _user=Depends(require_role("Owner"))):
    cur = db.cursor()
    try:
        cur.execute("INSERT INTO Item (Item_Name, Category_ID) VALUES (%s, %s)",
                    (body.item_name, body.category_id))
        db.commit()
        item_id = cur.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"item_id": item_id, "item_name": body.item_name}


@router.post("/categories", status_code=201)
def create_category(body: NewCategory, db: MySQLConnection = Depends(get_db),
                    _user=Depends(require_role("Owner"))):
    cur = db.cursor()
    try:
        cur.execute("INSERT INTO Category (Category_Name, Aisle_Location) VALUES (%s, %s)",
                    (body.category_name, body.aisle_location))
        db.commit()
        cat_id = cur.lastrowid
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
    return {"category_id": cat_id, "category_name": body.category_name}


@router.post("/receive-stock", status_code=201)
def receive_stock(body: ReceiveStockRequest, db: MySQLConnection = Depends(get_db),
                  _user=Depends(require_role("Owner"))):
    """Call sp_receive_stock to record a new delivery as a new Batch."""
    cur = db.cursor(dictionary=True)
    try:
        cur.callproc("sp_receive_stock", [
            body.item_id, body.supplier_id, body.hsn_code,
            body.purchase_price, body.wholesale_price, body.quantity,
            body.received_date, body.expiry_date,
            1 if body.check_procures else 0
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
