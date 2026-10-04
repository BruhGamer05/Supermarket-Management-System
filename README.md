# Supermarket Management System 🛒

A full-stack, database-backed web application for managing a wholesale supermarket. 
This project features a complete Vanilla JS frontend and a robust Python FastAPI backend, all powered by a highly normalized MySQL database.

## 🌟 Features
- **Role-Based Access Control:** Distinct interfaces for Owners, Employees (Cashiers), and Customers.
- **Concurrency Protection:** Uses `FOR UPDATE` row locks during checkout to prevent overselling of limited inventory.
- **Dynamic Taxation:** Tax rates are applied dynamically from an insert-only historic `HSN_Tax_Rate` table.
- **Loyalty Engine:** Walk-in vs registered customer tracking, with auto-calculating loyalty points.
- **Stock Requests:** Customers can request completely new items, which owners can approve and procure.
- **Real-Time Analytics:** 11 highly-optimized SQL Views for real-time dashboards (Top items, low stock, employee performance, etc).

## 🛠️ Tech Stack
- **Database:** MySQL 8.0
- **Backend:** Python 3.14, FastAPI, Uvicorn, mysql-connector-python
- **Frontend:** Vanilla HTML5, CSS3 (Custom Design System), JavaScript
- **Authentication:** JWT (JSON Web Tokens) with bcrypt password hashing

---

## 🚀 How to Run the Project Locally

### 1. Set up the Database (Two Methods)

**Method A: Using Docker (Recommended)**
If you have Docker installed, you can instantly spin up the database. This will automatically run all the SQL setup files in the `db/` folder!
```bash
docker-compose up -d
```

**Method B: Using Local MySQL**
1. Install MySQL Server 8.0 and start the service.
2. Log into your MySQL shell as root.
3. Run the setup scripts in this exact order:
```sql
SOURCE db/01_schema.sql;
SOURCE db/02_views.sql;
SOURCE db/03_seed.sql;
```

### 2. Set up the Backend Environment

1. Rename `.env.example` to `.env`.
2. Edit `.env` to match your MySQL credentials (if you used Docker, the defaults will work).
3. Create a Python virtual environment and activate it:
```bash
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Mac/Linux:
source venv/bin/activate
```
4. Install the required dependencies:
```bash
pip install -r requirements.txt
```

### 3. Start the Server

Run the following command to start the FastAPI server:
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
*(Windows users can simply double-click `start_demo.bat` to automate the database and server startup!)*

### 4. Open the App
The frontend is served statically by the backend. Open your browser and go to:
**http://localhost:8000/app/index.html**

## 🔑 Demo Accounts
Use these credentials to log in and test the different roles:
- **Owner:** `owner` / `owner123`
- **Cashier (Employee):** `ramesh_emp` / `ramesh123`
- **Customer:** `anil_cust` / `anil123`

---

## 📚 API Documentation
Because we use FastAPI, interactive API documentation is automatically generated.
Once the server is running, visit:
**http://localhost:8000/docs** to test all endpoints!
