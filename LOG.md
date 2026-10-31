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

---

## Session 2 — 2026-10-05

### What we worked on
Continued from Phase 3. Completed Phase 5 (Frontend), Phase 4 demo readiness, and Phase 6 submission documents. 
Also pushed the project to GitHub.

---

### Phase 5 — Frontend (COMPLETE ✅)

**Design System — `frontend/css/style.css`**
- Glassmorphism dark theme with CSS custom properties (colour tokens, surface layers, glow effects).
- Reusable components: `.glass-panel`, `.btn`, `.toast` notification system, form styles.

**Pages built:**

| File | Role | Key Features |
|------|------|-------------|
| `frontend/index.html` | All (Login) | JWT auth, role-aware redirect (Owner→owner.html, Employee→cashier.html, Customer→customer.html), invalid credentials toast |
| `frontend/owner.html` | Owner | KPI stats, Top Items table, Low Stock alerts, Employee Performance, Manage Stock Requests (Approve/Reject with PATCH call) |
| `frontend/cashier.html` | Employee | Live item catalog from DB, add-to-cart, phone-based customer lookup (auto-creates walk-in), checkout via `sp_create_bill` |
| `frontend/customer.html` | Customer | Loyalty points balance + transaction history, stock request form (new or existing item), request status tracking |

**Shared JS — `frontend/js/api.js`**
- `apiFetch()` wrapper: automatically injects `Authorization: Bearer <token>` header on every request.
- On 401 response: shows a "Session expired" toast and redirects to login (but suppressed on the login page itself to prevent redirect loops).
- `showToast()` helper used across all pages for success/error feedback.

**Bugs fixed:**
- JavaScript Temporal Dead Zone crash in `cashier.html` (variable declared with `const` inside a block but referenced before declaration).
- Backslash-escaped backtick in `owner.html` inline JS caused VS Code syntax error — removed the erroneous escapes.
- `start "" "http://..."` in the `.bat` file treated `&` as a shell operator — replaced with the word "and".
- After Admin elevation in `.bat`, Windows changed the working directory to `system32`, causing `.\venv\Scripts\python.exe` to fail — added `cd /d "%~dp0"` immediately after elevation check.

---

### Phase 4 — Demo Readiness (COMPLETE ✅)

**`DEMO.md` created** — full walkthrough document:
- Pre-flight checklist (start MySQL, run server, open browser).
- Step-by-step role flow: Customer → Cashier → Owner, with exact credentials and what to click.
- Swagger UI tour (`/docs`).
- Viva cheatsheet: pre-written answers for common TA questions (no stored totals, GST insert-only, negative stock prevention, bcrypt passwords, JWT authentication).

**`start_demo.bat` created** — one double-click startup:
1. Auto-requests Administrator privileges (needed to start MySQL80 service).
2. Runs `net start MySQL80`.
3. Opens two browser tabs: `http://localhost:8000/app/index.html` and `http://localhost:8000/docs`.
4. Opens a separate terminal window titled "MySQL Live Shell" — pre-logged into `supermarket_db` as root.
5. Starts FastAPI/Uvicorn server in the main window.

---

### Phase 6 — Submission Documents (MOSTLY COMPLETE ✅)

**`new_schema.md` created** — generated by `generate_mysql_schema.py`:
- Section 1: `SHOW FULL TABLES` output (14 base tables + 13 views).
- Section 2: `DESCRIBE <table>` ASCII table for every table in the database, exactly as MySQL shows it in the terminal.

**`README.md` created**:
- Project overview, feature list, tech stack.
- Two setup paths: Docker (`docker-compose up -d`) and native MySQL with step-by-step SQL source commands.
- `.env` setup, `pip install -r requirements.txt`, server start command.
- Demo account credentials table.
- Link to Swagger docs.

**`requirements.txt` generated** via `pip freeze` from the project venv.

**`.gitignore` updated** — added `.vscode/` and `mysql_data/` to existing entries.

---

### GitHub Setup

```
Repository: https://github.com/BruhGamer05/Supermarket-Management-System
```

Steps taken:
1. `git init` in project root.
2. `git add .` — 45 files staged (`.env` correctly excluded by `.gitignore`).
3. `git commit -m "Initial commit: Supermarket Management System"` — 4329 insertions.
4. `git remote add origin https://github.com/BruhGamer05/Supermarket-Management-System.git`
5. `git push -u origin master` — successful.

Note: An accidental `git remote add origit ...` was immediately cleaned up with `git remote remove origit`.

---

## Session 3 — 2026-10-31

### Complete Frontend Rewrite per FRONTEND.md (COMPLETE ✅)

**Design System & Assets:**
- Removed glassmorphism, glowing gradients, and emoji headings in favor of a calm, dense, enterprise light business theme.
- Authored design tokens strictly in `frontend/css/tokens.css` with zero runtime external dependencies (offline ready, no Google Fonts or CDNs).
- Structured stylesheets into `tokens.css`, `base.css`, `layout.css`, `components.css`, and `print.css`.

**Shared Modular JavaScript (`frontend/js/`):**
- `escape.js`: Safe dynamic value escaping (`esc()`) to eliminate XSS risks across all rendered templates.
- `format.js`: Standard Indian currency formatting (`inr()`), dates (`date()`, `dateTime()`), quantities (`qty()`), and percentages.
- `api.js`: Standardized fetch wrapper returning `ApiError`, handling JWT authorization headers and clearing session on 401.
- `auth.js`: Session management, role-based guard (`requireRole()`), and current user resolution.
- `shell.js`: Responsive top bar and sidebar navigation rendering customized per role.
- `ui.js`: Minimal toasts, custom modals, loading states, status badges, and confirm dialogs.
- `table.js`: Sortable, paginated data table builder with CSV export.
- `forms.js`: Blur-time and submit-time inline field validation (regex for phone, PIN, GSTIN, HSN).
- `charts.js`: Lightweight, zero-dependency SVG line and bar charts with accessible table fallback.

**Pages Built Across Role Subdirectories:**
1. **Public:**
   - `index.html`: Clean 380px login card with validation and role-aware redirect.
   - `signup.html`: Customer account registration.
   - `session-expired.html`, `403.html`, `404.html`: Plain status error pages.
2. **Staff (`frontend/staff/`):**
   - `pos.html`: High-performance 2-column billing terminal. Left: catalog search & category filter with real-time stock indicator. Right: sticky bill cart with real-time subtotal, GST, loyalty point redemption calculator, customer phone lookup, and checkout.
   - `home.html`: Shift KPIs and recent bills.
   - `bills.html`: Bill history with invoice preview link.
   - `inventory.html`: Batches, live stock, and expiry status tabs.
   - `customers.html`: Customer search and profile editing drawer.
   - `requests.html`: Customer stock request viewer and staff submission form.
   - `profile.html`: Employee profile and password update.
3. **Customer (`frontend/customer/`):**
   - `home.html`: Welcome dashboard with loyalty balance in rupees, pending requests, and last 5 bills.
   - `catalog.html`: Store inventory browsing with stock availability badges and out-of-stock request link.
   - `bills.html`: Invoice history with inline modal to submit 1–5 star employee feedback.
   - `loyalty.html`: Transaction ledger with earned/redeemed log.
   - `requests.html`: New stock request submission and status tracking.
   - `profile.html`: Profile and address editor.
4. **Owner (`frontend/owner/`):**
   - `dashboard.html`: Financial KPI strip, 30-day SVG sales trend line, top 5 revenue items, low stock alerts, and pending requests with quick approve/reject.
   - `items.html`: Catalog management with Add Item modal.
   - `batches.html`: Batch inventory tracker with Receive Stock delivery modal.
   - `suppliers.html`: Supplier management and Add Supplier modal.
   - `employees.html`: Employee roster and performance ratings.
   - `customers.html`: Customer records, total loyalty liability, and transaction drawer.
   - `bills.html`: Master audit ledger of all bills with CSV export.
   - `requests.html`: Stock request lifecycle manager (Approve/Reject/Fulfil with custom remarks).
   - `feedback.html`: Customer review dashboard highlighting ratings below 3.
   - `reports.html`: Multi-tab analytics (Sales, Categories, Profit per item, Employees, Restock).
   - `marketing.html`: Customer segmentation for SMS/WhatsApp festival campaigns with CSV export.
   - `loyalty.html`: Store discount liability and top point holders.
   - `tax.html`: HSN code list, GST rate breakdown (CGST/SGST), and policy explanation.
   - `accounts.html`: System user management and credential provisioning.
   - `settings.html`: Shop legal identity, GSTIN, and business rules overview.
5. **Shared:**
   - `invoice.html`: Printable A4 tax invoice with shop identity, GSTIN, per-line HSN, taxable value, CGST, SGST, loyalty deduction, and totals.

---

### Remaining items (not yet done)
- SQL stress test: two concurrent bills competing for last units of the same batch.
- ER diagram (visual) regeneration to match the final schema.

---

## Session 6 — 2026-10-31

### What was done
1. **Diagnosis of Missing Sidebar / Empty Bills Screen:**
   - Identified root cause: browser disk caching of legacy pre-rewrite JavaScript ES modules (`api.js`, `shell.js`, etc.) across pages. When an uncached import encountered a browser syntax or load error, script execution halted before `renderShell()` was reached, leaving the sidebar DOM element empty.
   - Audited all 32 HTML and JS files in the project.
   - Enforced consistent `?v=3` cache-busting query strings on all ES module imports across all pages and internal JS modules.
   - Verified that all HTML, CSS, and JS static assets return HTTP 200 OK via FastAPI static files mounting.

2. **Full End-to-End Test Suite Execution (`scratch/run_exhaustive_tests.py`):**
   - Executed 29 automated test cases covering authentication, Owner suite, Cashier suite, Customer suite, and RBAC security boundaries.
   - Result: 29/29 tests passed (0 failures).

---

_Log maintained by the AI agent. Updated after each session._
