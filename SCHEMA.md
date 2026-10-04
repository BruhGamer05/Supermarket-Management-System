# SCHEMA.md - supermarket_db, schema v2 (MySQL 8.0.16+)
Source of truth for the design. The executable version is `db/01_schema.sql`.
Key: PK primary key, FK foreign key, UK unique. All single-column IDs are AUTO_INCREMENT.

## Tables
| Table | Columns | Notes |
|---|---|---|
| Category | Category_ID PK, Category_Name, Aisle_Location | |
| Employee | Employee_ID PK, Name, Phone_Number UK, Shift_Schedule, Category_ID FK | category they manage |
| Customer | Customer_ID PK, First_Name, Last_Name, Phone_Number UK, Loyalty_Points (>=0), Shop_Bldg_No, Street, Area, City, State, PIN_Code | Loyalty_Points = running balance |
| Supplier | Supplier_ID PK, Supplier_Name, Phone_Number UK, GSTIN UK, Shop_Bldg_No, Street, Area, City, State, PIN_Code | |
| HSN_Tax_Rate | HSN_Code PK, GST_Percentage (0-100) | INSERT-ONLY |
| Item | Item_ID PK, Item_Name (indexed), Category_ID FK | no price/stock here |
| Procures | Supplier_ID PK/FK, Item_ID PK/FK | "supplier sells item" only |
| Batch | Batch_ID PK, Item_ID FK, Supplier_ID FK, HSN_Code FK, Purchase_Price, Wholesale_Price, Live_Stock (>=0), Received_Date, Expiry_Date | one purchase of one item; stock and prices live here |
| Bill | Bill_ID PK, Date_Time, Payment_Method (Cash/Card/UPI), Customer_ID FK (nullable = walk-in), Employee_ID FK | NO total column |
| Bill_Details | Bill_ID PK/FK, Batch_ID PK/FK, Quantity (>0) | junction |
| Stock_Request | Request_ID PK, Customer_ID FK, Item_ID FK (nullable), Requested_Item_Name (nullable), Quantity_Requested, Request_Date, Status (Pending/Approved/Rejected/Fulfilled), Handled_By FK Employee, Remarks | CHECK: exactly one of Item_ID / Requested_Item_Name |
| Loyalty_Transaction | Txn_ID PK, Customer_ID FK, Bill_ID FK, Txn_Type (Earned/Redeemed), Points_Change (+earned / -redeemed), Txn_Date | |
| Employee_Feedback | Feedback_ID PK, Bill_ID FK UK, Rating 1-5, Comments, Feedback_Date | one per bill; employee = Bill.Employee_ID |
| Users | User_ID PK, Username UK, Password_Hash, Role (Owner/Employee/Customer), Employee_ID FK UK, Customer_ID FK UK | CHECK ties role to the right link; Owner has neither |

## Relationships
Category 1-N Item; Category 1-N Employee; Item 1-N Batch; Supplier 1-N Batch; HSN_Tax_Rate 1-N Batch;
Bill 1-N Bill_Details N-1 Batch; Customer 1-N Bill; Employee 1-N Bill; Customer 1-N Stock_Request;
Item 1-N Stock_Request; Supplier N-M Item via Procures; Bill 1-1 Employee_Feedback (optional);
Bill 1-N Loyalty_Transaction; Customer 1-N Loyalty_Transaction; Users 1-1 Employee/Customer (optional).

## Computed values (views in db/02_views.sql)
- `v_bill_lines`: per line subtotal, GST, total (rounded to 2 decimals), plus purchase price for profit.
- `v_bill_totals`: per bill subtotal, GST, gross total, loyalty discount, amount payable.
- Line total = Quantity x Wholesale_Price x (1 + GST_Percentage/100).
- Amount payable = sum of line totals - points redeemed (1 point = Rs 1).
- Profit per line = (Wholesale_Price - Purchase_Price) x Quantity.

## Integrity rules
- Batch: Live_Stock, Purchase_Price, Wholesale_Price >= 0 (database enforces no negative stock).
- Never edit HSN_Tax_Rate rows; never edit price/HSN of a sold batch.
- Stock_Request flow: Pending -> Approved/Rejected (set Handled_By, Remarks) -> Fulfilled. When a new product is
  added to Item, set the request's Item_ID and clear Requested_Item_Name.

## Changes from the friend's original DB (new_schema.txt)
Batch gained Supplier_ID, Purchase_Price, Received_Date and AUTO_INCREMENT. All other IDs got AUTO_INCREMENT.
Stock_Request redesigned (new-product name, quantity, status enum, handler, remarks). Added Loyalty_Transaction,
Employee_Feedback, Users. Added CHECK constraints, an index on Item_Name, and the two views.
