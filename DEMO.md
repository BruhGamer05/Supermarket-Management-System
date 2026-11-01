# Supermarket Management System — Demo Script & Viva Guide
## Group 23 | B.Tech CSE, IIT BHU | Final Project Defense

Keep this file open on a split screen during your viva. It provides a step-by-step walkthrough of the exact demo sequence and answers to any technical questions the TA or professor may ask.

---

## 🛠️ Step 1: Pre-Demo Startup (One-Click)

1. **Double-click `start_demo.bat`** (or run as Administrator).
   * **What it does automatically:**
     1. Starts the local MySQL 8.0 service (`MySQL80`).
     2. Launches the FastAPI backend server on `http://localhost:8000`.
     3. Opens the default browser to the frontend (`http://localhost:8000/app/index.html`) and Swagger API docs (`http://localhost:8000/docs`).
     4. Opens a dedicated terminal with an interactive MySQL shell logged into `supermarket_db`.
2. **If starting manually via terminal:**
   ```powershell
   # Terminal 1: Backend
   .\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
   Open browser to: `http://localhost:8000/app/index.html`

---

## 🚀 Step 2: The Presentation Flow

### Part 1: Executive Introduction (30 seconds)
> *"Good morning Sir/Ma'am. For our DBMS project, we developed an enterprise-grade Supermarket Management System tailored for a wholesale FMCG trader in Muzaffarnagar (Kriyana, Dryfruits, Spices, and Holi Gulal). Our architecture couples a fully normalized MySQL 8 database enforcing strict ACID compliance and row-level locking with a high-performance Python FastAPI backend and a clean, responsive Vanilla JS enterprise frontend with distinct role-based access for Owners, Cashiers, and Customers."*

---

### Part 2: Role 1 — The Customer Experience (2 minutes)
1. Navigate to `http://localhost:8000/app/index.html`.
2. Sign in as **Customer**:
   * **Username:** `anil_cust`
   * **Password:** `anil123`
3. **What to demonstrate:**
   * **Home Dashboard (`/app/customer/home.html`):** Note the greeting pulled from the database (`Anil Gupta`), the running Loyalty Points balance (e.g. 153 pts = ₹153.00), and recent order activity.
   * **Catalog Browse (`/app/customer/catalog.html`):** Show the live store catalog with categories, wholesale rates, and live stock badges (`In stock`, `Low`, or `Out of stock` in red).
   * **Submit Out-of-Stock / New Item Request (`/app/customer/requests.html`):** 
     * Click **Requests** in the sidebar.
     * Point out the two flexible modes:
       1. **Restock Existing Item:** Customers can select an existing store item (e.g. **"Almonds (Badam) [Out of stock]"** or **"Basmati Rice"**) directly from the live catalog dropdown.
       2. **Request a New Product:** Or select "Request a new product" to request an unlisted item (e.g. **"Himalayan Pink Salt"**, Quantity: **10**).
     * *Bonus DBMS Feature:* Mention to the TA: *"Even if a customer types 'basmati rice' into the new product text box, our backend automatically performs a case-insensitive lookup on the `Item` catalog and resolves it cleanly to `Item_ID = 1`, ensuring no duplicate entries or ambiguous text records occur!"*
     * Click **Submit request**. Point out that it appears immediately with status badge `Pending`.
     * *DBMS Explanation:* *"Our database enforces a strict XOR constraint on `Stock_Request`: `CHECK ((Item_ID IS NOT NULL) <> (Requested_Item_Name IS NOT NULL))`. A request must specify either an existing `Item_ID` or a new `Requested_Item_Name`, never both or neither."*
   * **My Bills & Printable Tax Invoice (`/app/customer/bills.html`):**
     * Click **My bills**. Show Anil's purchase history.
     * Click **Invoice** on any bill. Point out the printable A4 Tax Invoice (`invoice.html`) with shop trade name (*Nanoomal Jagmeshwar Dayal*), GSTIN, HSN codes, and exact 50/50 CGST and SGST splits.
     * Click **Rate service** on a bill. Submit a 5-star rating with comment: *"Fast checkout and fresh stock!"*.
4. Click user profile in top-right → **Sign out**.

---

### Part 3: Role 2 — The Cashier / Employee POS (3 minutes)
1. Sign in as **Cashier / Employee**:
   * **Username:** `ramesh_emp`
   * **Password:** `ramesh123`
2. **What to demonstrate:**
   * Automatically routes to **Point of Sale (`/app/staff/pos.html`)**.
   * **Customer Phone Lookup:**
     * Type `9820000001` (Anil Gupta) in the Customer Phone field.
     * Point out that the system auto-fetches Anil's name and available loyalty balance.
   * **Cart & Inventory Availability:**
     * Search for **"Basmati Rice"** or click **Add**.
     * Adjust quantity. Notice the line subtotal and taxes compute dynamically.
     * Try typing a quantity exceeding available stock: notice the instant client and server guard preventing over-allocation.
   * **Checkout & Stored Procedure Execution:**
     * Select Payment Method: `Cash`.
     * Click **Checkout Bill**.
     * *DBMS Explanation to TA:*
       > *"When checkout is triggered, the backend calls stored procedure `sp_create_bill`. The entire checkout runs inside a single atomic transaction. It applies `SELECT ... FOR UPDATE` row locks on the `Batch` table to eliminate race conditions, takes stock using the FEFO algorithm (earliest expiry first), inserts `Bill` and `Bill_Details`, logs the `Loyalty_Transaction`, and awards 1 point per ₹100 spent."*
     * Show the bill confirmation toast and the **Print Tax Invoice** link.
   * **Cashier Bills Log (`/app/staff/bills.html`):**
     * Show that the new bill is recorded in the cashier's shift audit log.
3. Click user profile in top-right → **Sign out**.

---

### Part 4: Role 3 — The Owner Suite & Analytics (4 minutes)
1. Sign in as **Owner**:
   * **Username:** `owner`
   * **Password:** `owner123`
2. **What to demonstrate:**
   * **Owner Dashboard (`/app/owner/dashboard.html`):**
     * **KPI strip:** Total bills, Low stock items, Pending customer requests, Batches expiring within 30 days.
     * **Sales Trend Chart:** Custom SVG line chart showing revenue over the last 30 days.
     * **Low Stock Alerts:** Point out that exhausted items (like **Almonds (Badam)** with 0 units) are clearly highlighted in red with an `Out of stock` badge.
   * **Manage Stock Requests (`/app/owner/requests.html`):**
     * Locate Anil's pending request for **"Himalayan Pink Salt"**.
     * Click **Approve**, enter remarks (*"Approved for next dryfruits procurement run"*), and save.
     * Show that the status updates to `Approved` with the handling cashier's ID logged.
   * **Customer Feedback (`/app/owner/feedback.html`):**
     * Show the **Employee performance averages** table (average star rating per cashier).
     * Show the review submitted by Anil during the customer walkthrough.
   * **Analytical BI Reports (`/app/owner/reports.html`):**
     * Walk through the analytical tabs powered by SQL aggregation views:
       1. **Monthly revenue & daily breakdown** (`v_sales_by_month`, `v_sales_by_day`)
       2. **Category breakdown** (`v_sales_by_category`)
       3. **Top customer spenders** (`v_top_customers`)
       4. **Gross profit & margins** (`v_profit_per_item` — compares `Wholesale_Price` vs `Purchase_Price`)
       5. **Cashier performance** (`v_employee_performance`)
       6. **Restock planner** (`v_restock_list` — joins `Item`, `Batch`, `Procures`, and `Supplier` to display exactly which supplier and phone number to contact for replenishment).
   * **Batches & Stock Management (`/app/owner/batches.html`):**
     * Show batch tracking with expiry countdowns (`OK`, `Expiring`, `Expired`, `Empty`).
     * Click **Receive stock** button: shows modal to record a new supplier shipment (Item, Supplier, HSN, Cost Price, Wholesale Price, Quantity, Expiry Date).
   * **Bills Master Audit Ledger (`/app/owner/bills.html`):**
     * Show live search, payment method filters, and the **Export CSV** feature for accounting.

---

### Part 5: Backend Architecture & Concurrency Defense (If Requested)
1. Open a new tab to **`http://localhost:8000/docs`** to display the Swagger UI.
2. If asked how concurrency and race conditions were verified:
   * Explain: *"We developed an automated concurrency test script `tests/test_concurrency.py` that launches two concurrent threads simultaneously attempting to purchase the exact last unit of stock. Our `FOR UPDATE` lock inside `sp_create_bill` ensures exactly one thread commits with HTTP 201, the other is cleanly rejected with HTTP 400 (Insufficient Stock), and `Live_Stock` drops to 0 without ever going negative."*
   * Run script: `python tests/test_concurrency.py`.

---

## 🛡️ Viva Defense Cheatsheet (Frequently Asked Questions)

### Q1: Why don't you store the `Total_Price` on the `Bill` table?
> **Answer:** *"To strictly satisfy Third Normal Form (3NF). If we stored totals directly on `Bill`, `Total_Price` would be transitively dependent on `Bill_Details.Quantity`, `Batch.Wholesale_Price`, and `HSN_Tax_Rate.GST_Percentage`. If a batch price or tax rate were corrected, the stored total would risk becoming inconsistent. Instead, we dynamically compute subtotals, GST, and payable amounts in the view `v_bill_totals`. This guarantees 100% mathematical consistency without data anomalies."*

### Q2: What happens when the government changes a GST rate?
> **Answer:** *"Our `HSN_Tax_Rate` table is strictly insert-only. If the tax rate for an item changes, we insert a new HSN code entry with the updated rate. Historical batches remain permanently linked to the original HSN code under which they were procured. Therefore, historical invoices printed months later preserve their exact historical tax split without retroactive distortion."*

### Q3: How do you prevent stock from going negative?
> **Answer:** *"We enforce this at three separate layers:
> 1. **Database Constraint:** `Batch` has a table-level check constraint `CHECK (Live_Stock >= 0)`.
> 2. **Transaction Locking:** Stored procedure `sp_create_bill` uses `SELECT ... FOR UPDATE` row locks, ensuring concurrent bills cannot read stale stock counts.
> 3. **Application Guard:** The stored procedure calculates required quantity and issues a `ROLLBACK` with a `45000` SQL state if any batch lacks sufficient units."*

### Q4: How are passwords stored and roles secured?
> **Answer:** *"Passwords are never stored in plaintext. They are hashed using `bcrypt` with unique salts. Authentication is handled via stateless JWT (JSON Web Tokens) with HS256 signatures. Role-Based Access Control (RBAC) is enforced at the backend dependency layer (`require_role(['Owner', ...])`), preventing unauthorized users from accessing endpoints even if they manipulate the client-side JavaScript."*

### Q5: What is the difference between `Item` and `Batch`?
> **Answer:** *"An `Item` represents an abstract retail product (e.g. 'Basmati Rice', Category: Kriyana). A `Batch` represents a physical shipment delivered by a supplier at a specific cost, with a specific wholesale price, statutory HSN code, and expiration date. An item can have multiple batches over time. Pricing and inventory exist on the `Batch` level to accommodate supplier price fluctuations and FIFO/FEFO expiry management."*

---

## 📋 Demo Credentials Reference

| Role | Username | Password | Default Landing Page |
| :--- | :--- | :--- | :--- |
| **Owner** | `owner` | `owner123` | `/app/owner/dashboard.html` |
| **Employee (Cashier)** | `ramesh_emp` | `ramesh123` | `/app/staff/pos.html` |
| **Customer** | `anil_cust` | `anil123` | `/app/customer/home.html` |

*Good luck with your presentation tomorrow!*
