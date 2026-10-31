# TODO.md - phases and status
Mark items [x] when done. Stop at the end of each phase and show the user before continuing.

## Phase 0 - Environment (get MySQL running)
- [x] Detect OS (`cat /etc/os-release` or equivalent) and check what is installed: `mysql --version`, `mariadb --version`, `docker --version`.
- [x] Propose the simplest way to get MySQL 8.0 running and wait for the user to choose. Options:
  - Docker (best match for our schema): `docker compose up -d` using `docker-compose.yml`. Needs Docker installed and its daemon running.
  - Native MySQL 8 (Windows: MySQL Installer; macOS: `brew install mysql`; Debian/Ubuntu: `mysql-server`;
    Arch Linux: MySQL 8 is not in the official repos, use Docker or an AUR package).
  - MariaDB is a last resort (in Arch's official repos); the schema may need small syntax changes. Tell the user first.
- [x] Any `sudo` or system-level command: give it to the user to run, wait for the output.
- [x] Load the database in order: `db/01_schema.sql`, `db/02_views.sql`, `db/03_seed.sql`
  (Docker does this automatically on first start; otherwise `mysql -u root -p < db/01_schema.sql` etc.).
- [x] Explain to the user, in a few lines, how to connect to the DB from the terminal.

## Phase 1 - Verify the database
- [x] `SHOW TABLES;` shows 14 tables + 2 views (`v_bill_lines`, `v_bill_totals`).
- [x] `SELECT * FROM v_bill_totals;` returns 5 bills; bill 4 has Points_Discount 100 and Amount_Payable 10355.00.
- [x] Constraint checks fail as expected: set a batch's Live_Stock to -1; insert a Stock_Request with both or neither of
  Item_ID/Requested_Item_Name; insert a Users row with Role 'Employee' and a Customer_ID.
- [x] Walk the user through the schema with `DESCRIBE` on Batch, Bill_Details and Stock_Request.
- STOP and report.

## Phase 2 - Business logic in the database
- [x] Stored procedure `sp_create_bill(customer_id, employee_id, payment_method, items_json, points_to_redeem)`:
  one transaction, lock batches `FOR UPDATE`, FEFO allocation, check stock, insert Bill + Bill_Details, deduct stock,
  validate and apply loyalty (rules in AGENTS.md), insert Loyalty_Transaction rows, update Customer.Loyalty_Points.
- [x] Procedure to receive stock (create a Batch, optionally validating the supplier sells the item via Procures).
- [x] Procedure to resolve a stock request (approve/reject/fulfil; link a new Item for new products).
- [x] Insight views: low stock per item, batches expiring within 30 days / expired, sales by day and month, sales by
  category, top items, top customers, profit per item, employee average rating and bills handled, product demand
  from Stock_Request, restock list (low-stock item with its suppliers from Procures).
- [ ] SQL stress tests, including two simultaneous bills competing for the last units (must not oversell).

## Phase 3 - Backend API
- [x] Ask the user for the stack (FastAPI or Express) and DB driver; set up project structure and `.env` (not committed).
- [x] Auth: login endpoint, bcrypt hashes, JWT tokens, role guard (Owner/Employee/Customer).
- [x] Script to create the first Owner user and sample Employee/Customer users (`create_users.py`).
- [x] Endpoints by role: items and search (name, category, HSN), batches, billing, stock requests, loyalty,
  feedback, suppliers, employees, owner insights.
- [x] Validate input; return clear errors; use parameterized queries only (no string-built SQL).
- [x] Short API doc (`API.md`) listing endpoints, roles and example requests.
- [x] Frontend served statically from `/app` via FastAPI mount (`app.mount("/app", StaticFiles(directory="frontend"))`).

## Phase 4 - Testing and demo readiness
- [ ] Automated tests for billing math (GST rounding), stock deduction, loyalty, role permissions.
- [x] Demo script (`DEMO.md`) covering full TA walkthrough — role-by-role flow, startup checklist, viva Q&A answers.
- [x] One-click startup script (`start_demo.bat`): starts MySQL80 service (as Admin), opens browser to frontend + Swagger, opens MySQL live shell in a separate terminal, starts Uvicorn server.

## Phase 5 - Frontend (Vanilla HTML/CSS/JS)
- [x] Shared design system (`frontend/css/style.css`) — glassmorphism dark theme, CSS variables, toast notifications.
- [x] Login page (`frontend/index.html`) — role-aware redirect after JWT auth.
- [x] Owner dashboard (`frontend/owner.html`) — KPI stats, Top Items, Low Stock, Employee Performance, Stock Request management (Approve/Reject).
- [x] Cashier / Employee POS (`frontend/cashier.html`) — item catalog, cart, phone-based customer lookup, checkout.
- [x] Customer portal (`frontend/customer.html`) — loyalty points + history, stock request submission + tracking.
- [x] Shared API helper (`frontend/js/api.js`) — JWT header injection, 401 toast handling, prevents redirect on login page.

## Phase 6 - Submission documents
- [x] Relational schema regenerated from live DB in MySQL `describe` format → `new_schema.md`.
- [x] `README.md` written — setup instructions, demo accounts, tech stack, Docker and native MySQL options.
- [x] GitHub repository created: https://github.com/BruhGamer05/Supermarket-Management-System
- [ ] Regenerate ER diagram (visual) to match final schema (old Assignment PDFs are outdated).

## Open questions for the user
See "Still open" in PROJECT.md.
