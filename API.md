# Supermarket Management System - API Documentation

The backend is built with **FastAPI**. It connects to the MySQL database and exposes all the business logic we wrote in Phase 2 via clean, RESTful endpoints.

## How to Test the API (Swagger UI)

1. Ensure the server is running: `& "C:\Users\bruh\AppData\Local\Programs\Python\Python314\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000`
2. Open your web browser and go to: **http://localhost:8000/docs**

### Testing a Route (Example: Login and checking Low Stock)

1. Find the `POST /auth/login` route in the Swagger UI and click on it.
2. Click the **"Try it out"** button on the right.
3. Edit the Request body to use the Owner account:
   ```json
   {
     "username": "owner",
     "password": "owner123"
   }
   ```
4. Click **"Execute"**. Scroll down to the Server Response. You will see an `access_token` string. Copy this string.
5. Scroll to the very top of the page and click the green **"Authorize"** button (with a padlock icon).
6. Paste the copied token into the Value box and click **"Authorize"**, then click **"Close"**.
7. Now find the `GET /owner/insights/low-stock` endpoint (only the owner can use this).
8. Click **"Try it out"**, then **"Execute"**. You will get back real data from the database!

---

## Test Accounts

You can log into the Swagger UI with any of these to test different permission levels:

| Role       | Username     | Password    |
|------------|--------------|-------------|
| **Owner**  | `owner`      | `owner123`  |
| **Employee**| `ramesh_emp` | `ramesh123` |
| **Customer**| `anil_cust`  | `anil123`   |

---

## Key Endpoints

### 🔐 Auth
- `POST /auth/login`: Authenticate and receive a JWT token.
- `POST /auth/register`: Create a new user account.

### 📦 Items & Inventory (Owner / Employee)
- `GET /items/`: Search and list items.
- `GET /items/batches`: View stock levels and expiry dates.
- `POST /items/receive-stock`: Record new stock delivery (Owner only).

### 🧾 Billing (Owner / Employee)
- `POST /bills/`: Create a complete bill (handles FEFO, stock reduction, loyalty points).
- `GET /bills/`: List all bills.

### 👥 Customer Tools
- `GET /customers/me`: Customer views their own profile.
- `GET /customers/me/loyalty`: Customer views their loyalty point balance and history.
- `POST /customers/me/stock-requests`: Customer submits a new stock request.
- `PATCH /customers/stock-requests/{request_id}`: Employee resolves a stock request.

### 📊 Insights (Owner Only)
- `GET /owner/insights/sales-by-day`: Daily sales totals.
- `GET /owner/insights/top-items`: Best-selling items.
- `GET /owner/insights/low-stock`: Items that need to be restocked.
- `GET /owner/insights/employee-performance`: Employee ratings and bills handled.
