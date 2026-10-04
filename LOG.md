# LOG.md — Project Activity Log
## Supermarket Management System | Group 23 | IIT BHU CSE

This file records every major action taken on this project, in order.
Anyone reading this can understand what was done, why, and how to reproduce it.

---

## Session 1 — 2026-10-04

### What we read first
- `AGENTS.md` — rules for the AI agent
- `PROJECT.md` — project scope and client details
- `SCHEMA.md` — database design (source of truth)
- `TODO.md` — phases and task list
- `changes.txt` — 5 changes requested by the TA
- `new_schema.txt` — DESCRIBE output of a friend's older version of the DB (used as reference)
- `docker-compose.yml` — shows MySQL 8.0 config for Docker (not used; we went native)
- `db/01_schema.sql`, `db/02_views.sql`, `db/03_seed.sql` — the actual database files

---

### Phase 0 — Environment Setup

**OS detected:** Windows 11 (PowerShell)
**Initial state:** `mysql` not found, `docker` not found.

**Decision:** Install MySQL 8 natively via MySQL Installer (simpler than Docker on Windows).

**Steps taken:**
1. Downloaded MySQL Installer from https://dev.mysql.com/downloads/installer/
2. Ran installer → chose "Developer Default" → installed MySQL Server 8.0.46, MySQL Workbench, MySQL Shell
3. Set root password: `rootpass` (dev only — never reuse in production)
4. MySQL was installed but `mysql` command not in PATH

**PATH fix:**
Added `C:\Program Files\MySQL\MySQL Server 8.0\bin` to the user's PATH via PowerShell:
```powershell
$current = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable("Path", $current + ";C:\Program Files\MySQL\MySQL Server 8.0\bin", [System.EnvironmentVariableTarget]::User)
```
To reload in an already-open PowerShell window (without restarting):
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

**Database loaded:**
PowerShell's `<` operator does not work for stdin redirection. Used `Get-Content | mysql` instead:
```powershell
mysql -u root -prootpass -e "CREATE DATABASE IF NOT EXISTS supermarket_db;"
Get-Content db\01_schema.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\02_views.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\03_seed.sql -Raw | mysql -u root -prootpass supermarket_db
```
All 3 files loaded with no errors (password-on-CLI warning is harmless).

**How to connect to the DB from terminal:**
```powershell
mysql -u root -p        # prompts for password: rootpass
USE supermarket_db;     # switch to our database
```

---

### Design decisions confirmed this session

| Topic | Decision | Reason |
|-------|----------|--------|
| Backend stack | **FastAPI (Python)** | Simpler syntax, auto Swagger docs at /docs, easy to explain in viva |
| Loyalty numbers | 1 pt per Rs 100 earned; 1 pt = Rs 1 off; max 50% of bill | Placeholder values owner may change later |
| Procures FK | No composite FK from Batch to Procures | Adds complexity with little gain; Procures still used for restock views |
| ERD update | Will regenerate ERD after all schema decisions are final | Assignments 2 & 3 PDFs are outdated |

**Loyalty in bill price (clarified):**
`v_bill_totals` already includes loyalty discount:
```
Amount_Payable = Gross_Total - Points_Redeemed
```
`Points_Discount` is read from `Loyalty_Transaction` where `Txn_Type = 'Redeemed'`.
Nothing is stored on the bill itself — all computed.

---

### After laptop restart — MySQL service not running

**Symptom:** `ERROR 2003 (HY000): Can't connect to MySQL server on 'localhost:3306' (10061)`
**Cause:** MySQL service set to Manual start by installer; stops on shutdown.

**Fix — run in an Administrator PowerShell:**
```powershell
net start MySQL80
```

**To make MySQL start automatically on every boot (run once in Admin PowerShell):**
```powershell
Set-Service -Name MySQL80 -StartupType Automatic
```

---

### Phase 1 — Verification (COMPLETE ✅)

All checks passed:
- `SHOW FULL TABLES` → 14 base tables + 2 views confirmed
- `SELECT * FROM v_bill_totals` → 5 bills; Bill 4: Points_Discount=100, Amount_Payable=10355.00 ✅
- Constraint rejections confirmed:
  - `UPDATE Batch SET Live_Stock = -1` → ERROR (CHECK constraint)
  - `INSERT Stock_Request` with both Item_ID and Requested_Item_Name → ERROR (CHECK constraint)
  - `INSERT Users` with Role='Employee' and Customer_ID set → ERROR (CHECK constraint)
- `DESCRIBE Batch`, `DESCRIBE Bill_Details`, `DESCRIBE Stock_Request` — reviewed and understood

**Concepts explained this session:**
- Views: saved SELECT queries that look like tables; read-only; recomputed on every query
- `v_bill_lines`: computes per-line subtotal, GST, and total for each item on a bill
- `v_bill_totals`: sums lines per bill, subtracts redeemed loyalty points → Amount_Payable
- Loyalty earning (e.g. 103 pts on Rs 10355 bill) is NOT in the views — it will be written in Phase 2 stored procedure

---

### Phase 2 — Business Logic in the Database (COMPLETE ✅)

**New files created:**
- `db/04_procedures.sql` — 3 stored procedures
- `db/05_insights.sql` — 11 owner insight views
- `db/test_procedures.sql` — test calls (dev only)

**Stored procedures:**

| Procedure | What it does |
|-----------|-------------|
| `sp_create_bill(phone, emp_id, method, items_json, redeem_pts)` | Full atomic billing: FEFO stock allocation, loyalty earn/redeem, auto customer creation by phone |
| `sp_receive_stock(item, supplier, hsn, purchase_price, wholesale_price, qty, recv_date, expiry, check_procures)` | Records a new delivery as a new Batch row |
| `sp_resolve_stock_request(req_id, status, emp_id, remarks, item_id)` | Approves / Rejects / Fulfils a Stock_Request; links new Item if applicable |

**Insight views (all prefixed `v_`):**
`v_low_stock`, `v_expiring_batches`, `v_sales_by_day`, `v_sales_by_month`, `v_sales_by_category`,
`v_top_items`, `v_top_customers`, `v_profit_per_item`, `v_employee_performance`, `v_product_demand`, `v_restock_list`

**Design decisions made in Phase 2:**

| Decision | Choice | Reason |
|----------|--------|---------|
| Walk-in customer handling | Phone number → lookup or auto-create customer. NULL phone = true walk-in | Keeps billing fast; loyalty starts immediately; name can be updated later |
| New customer name | Stored as 'Walk-in' placeholder | Cashier doesn't have time to collect full details at counter |
| Loyalty redemption cap | 50% of gross total per bill | Business rule from AGENTS.md |
| FEFO implementation | MySQL cursor ordered by `ISNULL(Expiry_Date), Expiry_Date ASC` | NULLs (no expiry) go last; oldest expiry taken first |

**Bug fixed:** Typo `v_redeem_points` → `p_redeem_points` in sp_create_bill (caught during testing).

**Test results:**
- Bill created for known customer (Rekha, phone 9820000002): loyalty redeemed and earned correctly
- New phone (9999999999): Customer auto-created as 'Walk-in', 1 loyalty point earned
- NULL phone: Bill created with Customer_ID=NULL, 0 points earned/redeemed
- `v_low_stock`: Almonds (0), Tulsi Leaves (45) flagged
- `v_expiring_batches`: Tulsi Leaves expired; Ashwagandha expiring in 16 days
- `v_top_items`: Cashew top seller (Rs 20,412 revenue)
- `v_employee_performance`: Ramesh 3 bills handled, avg rating 5.0

---

### Phase 3 — Backend API (COMPLETE ✅)

**Technology Stack used:** Python 3.14 + FastAPI + `mysql-connector-python`

**Key Implementations:**
1. **Security & Auth:** Used `bcrypt` for secure password hashing and `PyJWT` for stateless authentication tokens. Each route is guarded by a role checker (Owner/Employee/Customer).
2. **Database Connection Pooling:** Implemented a pool in `app/database.py` (size 10) to reuse DB connections rather than opening a new one per request, ensuring high performance.
3. **API Routes mapping DB to Frontend:**
   - **Auth:** `/auth/login`, `/auth/register`
   - **Billing:** `/bills` (handles creation by invoking `sp_create_bill`), `/bills/{id}/feedback`
   - **Items/Inventory:** `/items`, `/items/categories`, `/items/batches` (and `receive-stock` hitting `sp_receive_stock`)
   - **Customers:** `/customers/me`, `/customers/me/loyalty`, `/customers/stock-requests`
   - **Owner Insights:** 11 different `/owner/insights/...` endpoints hitting our views (low stock, expiring batches, profit, top items).

**Troubleshooting/Fixes:**
- Handled a tricky Python interpreter path issue where VS Code failed to detect the standard `venv` because of a conflict with `msys64`'s python. Rebuilt the virtual environment strictly tied to the native Windows python, and configured `.vscode/settings.json` explicitly.

**Test accounts created (`create_users.py`):**
- Owner: `owner` / `owner123`
- Employee: `ramesh_emp` / `ramesh123`
- Customer: `anil_cust` / `anil123`, `rekha_cust` / `rekha123`

---

## How to reload the entire DB from scratch

> WARNING: This drops and recreates all tables. Do NOT run if you have real data to keep.

```powershell
# 1. Start MySQL service first (in Admin PowerShell)
net start MySQL80

# 2. Then in a normal PowerShell from the project root folder:
Get-Content db\01_schema.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\02_views.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\03_seed.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\04_procedures.sql -Raw | mysql -u root -prootpass supermarket_db
Get-Content db\05_insights.sql -Raw | mysql -u root -prootpass supermarket_db
```

---

_Log maintained by the AI agent. Updated after each session._
