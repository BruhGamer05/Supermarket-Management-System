# Supermarket Management System - Demo Script

Keep this file open on a split screen during your viva. Follow these steps exactly, from the moment you open your laptop!

---

## 🛠️ Step 1: The "Open Laptop" Checklist

Before the TA arrives, you need to ensure the engine is running.

1. **Start MySQL Database:**
   - *If using Docker:* Open a terminal in your project folder and run: `docker-compose up -d`
   - *If using local MySQL Server:* Ensure the MySQL 80 service is running in Windows Services.
   
2. **Start the FastAPI Backend Server:**
   - Open a fresh PowerShell terminal in VS Code inside `DBMSProject`.
   - Run exactly this command to start the server:
     ```powershell
     & ".\venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000
     ```
   - Keep this terminal open!

3. **Open the Frontend:**
   - Open your web browser and navigate to: **http://localhost:8000/app/index.html**
   - *Pro tip: Do NOT double-click the HTML file from your file explorer. Always use the localhost link.*

---

## 🚀 Step 2: The Presentation Flow

### Part 1: The Introduction
- **What to say:** *"Sir/Ma'am, for our Phase 2 project, we went beyond just a backend API. We built a fully functional web application connected to our MySQL database using FastAPI. The system handles secure concurrency, real-time analytics, and role-based access."*

### Part 2: Role 1 - The Customer Experience
1. Open the login page (`http://localhost:8000/app/index.html`).
2. Log in using the **Customer** credentials:
   - Username: `anil_cust`
   - Password: `anil123`
3. **What to show:** 
   - Point out that the system pulled their real name from the DB and authenticated them securely using JWT tokens.
   - Show their Loyalty Points balance and transaction history.
   - **Action:** Go to the "Request an Item" form. Type in a completely new item (e.g., "Himalayan Pink Salt", Qty: 10) and hit Submit. Show that it appears in their tracking table as "Pending".

### Part 3: Role 2 - The Employee (Cashier) Experience
1. Click **Sign Out**.
2. Log in using the **Cashier** credentials:
   - Username: `ramesh_emp`
   - Password: `ramesh123`
3. **What to show:**
   - The Point-of-Sale (POS) interface. The live catalog is pulled directly from the `Item` and `Batch` tables.
   - Mention the **Business Logic:** *"When we check out, the database runs `sp_create_bill`. It uses `FOR UPDATE` row locks to prevent overselling if two cashiers bill the same item simultaneously. It also automatically applies the correct GST from our `HSN_Tax_Rate` table and uses FEFO (First-Expiring-First-Out) to clear old stock first."*
   - **Action:** Click on an item to add it to the cart. 
   - Enter `9820000001` (Anil's phone number) in the Customer Phone box.
   - Click **Checkout Bill**. (The toast will confirm the bill amount).

### Part 4: Role 3 - The Owner Experience (Analytics)
1. Click **Sign Out**.
2. Log in using the **Owner** credentials:
   - Username: `owner`
   - Password: `owner123`
3. **What to show:**
   - **The Analytics:** Point out the "Top Selling Items", "Low Stock Alerts", and "Employee Performance" tables. 
   - Mention: *"These are powered by our SQL Views (like `v_low_stock` and `v_employee_performance`), which aggregate data instantly."*
   - **Action:** Scroll to the bottom to **"Manage Customer Stock Requests"**.
   - Show the request Anil made earlier for "Himalayan Pink Salt".
   - Click **Approve**. Explain that when it's eventually fulfilled, the backend links their text request to a permanent `Item_ID` in the system!

### Part 5: The Backend / Swagger Docs (If asked)
If the TA asks about your API or backend structure:
1. Open a new tab and go to: **http://localhost:8000/docs**
2. Show them the auto-generated Swagger UI.
3. Mention: *"FastAPI automatically generated documentation for all our endpoints. We implemented proper connection pooling using `mysql-connector-python` and secured all routes with OAuth2 Bearer Tokens."*

---

## 🛡️ Defending the Design (Viva Cheatsheet)
If the TA asks tricky questions, use these answers:

- **"Why don't you store the Total Price on the Bill table?"**
  *Answer:* "Because of normalization (3NF). We calculate totals dynamically in our `v_bill_totals` view by multiplying `Bill_Details.Quantity` by `Batch.Wholesale_Price` and adding the `HSN_Tax_Rate`. This ensures data never goes out of sync."

- **"What happens if GST rates change?"**
  *Answer:* "Our `HSN_Tax_Rate` table is designed to be insert-only. If the government changes a tax rate, we insert a new HSN code version. Since batches are permanently linked to a specific HSN code at the time of purchase, old bills will perfectly retain their historical tax rates."

- **"How did you prevent negative stock?"**
  *Answer:* "We have a `CHECK (Live_Stock >= 0)` constraint in MySQL, and our `sp_create_bill` procedure locks the rows during the transaction. It checks stock availability and rolls back immediately if there's insufficient quantity."

- **"How are passwords stored and how do new users get created?"**
  *Answer:* "Passwords are NEVER stored in plain text. They are salted and hashed using `bcrypt`. For this demo, we seeded the database using a Python script. In a full production system, the Owner would create Employee accounts from their dashboard, and Customers would sign up online to link their phone number to a new `Users` login row."
