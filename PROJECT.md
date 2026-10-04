# PROJECT.md - Supermarket Management System (Group 23)

## Client and scope
Client: Nanoomal Jagmeshwar Dayal, wholesale dealership in Muzaffarnagar (U.P.) dealing in Kriyana, Dryfruits,
Desi Jadi Booti, and Tota Rang Gulal. Goal: replace manual inventory and ledger work with a centralized
database system: stock levels, accurate GST, customer demand trends, and management of suppliers,
employees and inventory.

## Course context
College DBMS project (IIT BHU, CSE). Done so far: Assignment 1 (requirements), 2 (ER diagram),
3 (relational schema). Next deliverable (TA meet): the BACKEND of the system. Frontend comes after.
The TA asked for five changes (see below).

## Original requirements (from Assignment1.pdf)
- Customer: unique ID, name (first/last), composite address (shop/bldg no, street, area, city, state, PIN),
  phone, loyalty points.
- Employee: ID, name, phone, shift schedule, assigned item category.
- Category: ID, name, aisle/location.
- Item: ID, name, wholesale price, live stock, HSN code, expiry date. GST % is NOT stored; derived from HSN code.
  (This was later restructured into Item + Batch; see SCHEMA.md.)
- Supplier: ID, name, phone, GSTIN (e.g. 09AAAFN7008D1ZL), composite address. Used to track inward purchases
  and trigger restocking alerts.
- Bill: unique ID, customer, cashier (employee), date/time, payment method (Cash/Card/UPI), final total.
  Items and quantities are a multivalued relationship via the junction table Bill_Details.
- Functional: staff log in; browse inventory and live stock; search by name/category/HSN; process bills with
  automatic GST; log unfulfilled customer stock requests; stock auto-deducted when a bill is confirmed.
  Admin: add/remove items, update wholesale prices, manage suppliers, analyze purchase histories for
  targeted marketing lists.
- Non-functional: simple UI usable during fast billing; stock never negative under concurrent transactions;
  fast search; precise GST; scalable catalog.

## TA's requested changes (changes.txt) and how we handle them
1. Customer requirement for new products -> `Stock_Request` supports a free-text new product name.
2. Employee feedback logging -> customers give a 1-5 rating + comment per bill (`Employee_Feedback`).
3. Loyalty points implementation -> `Loyalty_Transaction` log + balance on `Customer`.
4. Detailed insights for owner -> SQL views and API endpoints (low stock, expiring batches, sales trends,
   top items/customers, profit, employee ratings, product demand from requests).
5. Owner, employee and customer all in the frontend with roles and authentication -> `Users` table, backend
   role checks, three role-specific views.

## Roles (PROPOSED - confirm with the team)
- Owner: everything. Manage items, prices, batches, suppliers, employees. Approve/reject stock requests.
  See all insights.
- Employee: search/browse inventory, create bills, log stock requests for customers, view pending requests.
- Customer: browse catalog and stock, submit stock requests (existing out-of-stock or new product), view own
  bills and loyalty points, give feedback on a bill.

## Key design decisions already made
- Prices and GST are computed, not stored on bills. The team knowingly simplifies GST history by assuming a GST
  change means a new HSN code (old batches/bills keep the old code and rate).
- `HSN_Code` stays on `Batch`. A batch = one purchase of one item from one supplier (with purchase price).
- Selling price = `Batch.Wholesale_Price`, excluding GST.
- `Procures` only means "this supplier sells this item"; actual purchases are recorded as batches.
- All IDs auto-increment. Walk-in customers are allowed on bills (no loyalty).
- Stock is taken earliest-expiry-first when billing (proposed default).

## Still open (ask the user; do not decide silently)
1. Backend stack: Python (FastAPI) or Node (Express)? Whatever the team knows best.
2. Loyalty numbers (1 point per Rs 100, 1 point = Rs 1, max 50%) are placeholders.
3. Optional integrity rule: composite FK `Batch(Supplier_ID, Item_ID) -> Procures(Supplier_ID, Item_ID)`.
4. The friend's real data: only table structure is available here. `db/03_seed.sql` is fictional sample data.
   The friend can export real data with `mysqldump supermarket_db > dump.sql`.
5. Assignment2.pdf's text describes an older 4-entity model (Customer, Order, Product, Employee) that does not match
   its own figure. The ER diagram and relational schema documents need regenerating from `SCHEMA.md` before submission.
