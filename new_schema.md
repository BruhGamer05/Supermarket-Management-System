# Supermarket Database Schema (MySQL Format)

## Database Tables
```text
mysql> show full tables;
+--------------------------+------------+
| Tables_in_supermarket_db | Table_type |
+--------------------------+------------+
| batch                    | BASE TABLE |
| bill                     | BASE TABLE |
| bill_details             | BASE TABLE |
| category                 | BASE TABLE |
| customer                 | BASE TABLE |
| employee                 | BASE TABLE |
| employee_feedback        | BASE TABLE |
| hsn_tax_rate             | BASE TABLE |
| item                     | BASE TABLE |
| loyalty_transaction      | BASE TABLE |
| procures                 | BASE TABLE |
| stock_request            | BASE TABLE |
| supplier                 | BASE TABLE |
| users                    | BASE TABLE |
| v_bill_lines             | VIEW       |
| v_bill_totals            | VIEW       |
| v_employee_performance   | VIEW       |
| v_expiring_batches       | VIEW       |
| v_low_stock              | VIEW       |
| v_product_demand         | VIEW       |
| v_profit_per_item        | VIEW       |
| v_restock_list           | VIEW       |
| v_sales_by_category      | VIEW       |
| v_sales_by_day           | VIEW       |
| v_sales_by_month         | VIEW       |
| v_top_customers          | VIEW       |
| v_top_items              | VIEW       |
+--------------------------+------------+
```

## Detailed Table Schemas

### Table: `batch`
```text
mysql> describe batch;
+-----------------+---------------+------+-----+-----------+-------------------+
| Field           | Type          | Null | Key | Default   | Extra             |
+-----------------+---------------+------+-----+-----------+-------------------+
| Batch_ID        | int           | NO   | PRI | NULL      | auto_increment    |
| Item_ID         | int           | NO   | MUL | NULL      |                   |
| Supplier_ID     | int           | YES  | MUL | NULL      |                   |
| HSN_Code        | varchar(20)   | NO   | MUL | NULL      |                   |
| Purchase_Price  | decimal(10,2) | NO   |     | 0.00      |                   |
| Wholesale_Price | decimal(10,2) | NO   |     | NULL      |                   |
| Live_Stock      | int           | NO   |     | 0         |                   |
| Received_Date   | date          | YES  |     | curdate() | DEFAULT_GENERATED |
| Expiry_Date     | date          | YES  |     | NULL      |                   |
+-----------------+---------------+------+-----+-----------+-------------------+
```

### Table: `bill`
```text
mysql> describe bill;
+----------------+---------------------------+------+-----+-------------------+-------------------+
| Field          | Type                      | Null | Key | Default           | Extra             |
+----------------+---------------------------+------+-----+-------------------+-------------------+
| Bill_ID        | int                       | NO   | PRI | NULL              | auto_increment    |
| Date_Time      | datetime                  | YES  |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
| Payment_Method | enum('Cash','Card','UPI') | NO   |     | NULL              |                   |
| Customer_ID    | int                       | YES  | MUL | NULL              |                   |
| Employee_ID    | int                       | YES  | MUL | NULL              |                   |
+----------------+---------------------------+------+-----+-------------------+-------------------+
```

### Table: `bill_details`
```text
mysql> describe bill_details;
+----------+------+------+-----+---------+-------+
| Field    | Type | Null | Key | Default | Extra |
+----------+------+------+-----+---------+-------+
| Bill_ID  | int  | NO   | PRI | NULL    |       |
| Batch_ID | int  | NO   | PRI | NULL    |       |
| Quantity | int  | NO   |     | NULL    |       |
+----------+------+------+-----+---------+-------+
```

### Table: `category`
```text
mysql> describe category;
+----------------+-------------+------+-----+---------+----------------+
| Field          | Type        | Null | Key | Default | Extra          |
+----------------+-------------+------+-----+---------+----------------+
| Category_ID    | int         | NO   | PRI | NULL    | auto_increment |
| Category_Name  | varchar(50) | NO   |     | NULL    |                |
| Aisle_Location | varchar(20) | YES  |     | NULL    |                |
+----------------+-------------+------+-----+---------+----------------+
```

### Table: `customer`
```text
mysql> describe customer;
+----------------+-------------+------+-----+---------+----------------+
| Field          | Type        | Null | Key | Default | Extra          |
+----------------+-------------+------+-----+---------+----------------+
| Customer_ID    | int         | NO   | PRI | NULL    | auto_increment |
| First_Name     | varchar(50) | NO   |     | NULL    |                |
| Last_Name      | varchar(50) | YES  |     | NULL    |                |
| Phone_Number   | varchar(15) | YES  | UNI | NULL    |                |
| Loyalty_Points | int         | NO   |     | 0       |                |
| Shop_Bldg_No   | varchar(20) | YES  |     | NULL    |                |
| Street         | varchar(50) | YES  |     | NULL    |                |
| Area           | varchar(50) | YES  |     | NULL    |                |
| City           | varchar(50) | YES  |     | NULL    |                |
| State          | varchar(50) | YES  |     | NULL    |                |
| PIN_Code       | varchar(10) | YES  |     | NULL    |                |
+----------------+-------------+------+-----+---------+----------------+
```

### Table: `employee`
```text
mysql> describe employee;
+----------------+--------------+------+-----+---------+----------------+
| Field          | Type         | Null | Key | Default | Extra          |
+----------------+--------------+------+-----+---------+----------------+
| Employee_ID    | int          | NO   | PRI | NULL    | auto_increment |
| Name           | varchar(100) | NO   |     | NULL    |                |
| Phone_Number   | varchar(15)  | YES  | UNI | NULL    |                |
| Shift_Schedule | varchar(50)  | YES  |     | NULL    |                |
| Category_ID    | int          | YES  | MUL | NULL    |                |
+----------------+--------------+------+-----+---------+----------------+
```

### Table: `employee_feedback`
```text
mysql> describe employee_feedback;
+---------------+--------------+------+-----+-------------------+-------------------+
| Field         | Type         | Null | Key | Default           | Extra             |
+---------------+--------------+------+-----+-------------------+-------------------+
| Feedback_ID   | int          | NO   | PRI | NULL              | auto_increment    |
| Bill_ID       | int          | NO   | UNI | NULL              |                   |
| Rating        | tinyint      | NO   |     | NULL              |                   |
| Comments      | varchar(500) | YES  |     | NULL              |                   |
| Feedback_Date | datetime     | YES  |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+---------------+--------------+------+-----+-------------------+-------------------+
```

### Table: `hsn_tax_rate`
```text
mysql> describe hsn_tax_rate;
+----------------+--------------+------+-----+---------+-------+
| Field          | Type         | Null | Key | Default | Extra |
+----------------+--------------+------+-----+---------+-------+
| HSN_Code       | varchar(20)  | NO   | PRI | NULL    |       |
| GST_Percentage | decimal(5,2) | NO   |     | NULL    |       |
+----------------+--------------+------+-----+---------+-------+
```

### Table: `item`
```text
mysql> describe item;
+-------------+--------------+------+-----+---------+----------------+
| Field       | Type         | Null | Key | Default | Extra          |
+-------------+--------------+------+-----+---------+----------------+
| Item_ID     | int          | NO   | PRI | NULL    | auto_increment |
| Item_Name   | varchar(100) | NO   | MUL | NULL    |                |
| Category_ID | int          | YES  | MUL | NULL    |                |
+-------------+--------------+------+-----+---------+----------------+
```

### Table: `loyalty_transaction`
```text
mysql> describe loyalty_transaction;
+---------------+---------------------------+------+-----+-------------------+-------------------+
| Field         | Type                      | Null | Key | Default           | Extra             |
+---------------+---------------------------+------+-----+-------------------+-------------------+
| Txn_ID        | int                       | NO   | PRI | NULL              | auto_increment    |
| Customer_ID   | int                       | NO   | MUL | NULL              |                   |
| Bill_ID       | int                       | NO   | MUL | NULL              |                   |
| Txn_Type      | enum('Earned','Redeemed') | NO   |     | NULL              |                   |
| Points_Change | int                       | NO   |     | NULL              |                   |
| Txn_Date      | datetime                  | YES  |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+---------------+---------------------------+------+-----+-------------------+-------------------+
```

### Table: `procures`
```text
mysql> describe procures;
+-------------+------+------+-----+---------+-------+
| Field       | Type | Null | Key | Default | Extra |
+-------------+------+------+-----+---------+-------+
| Supplier_ID | int  | NO   | PRI | NULL    |       |
| Item_ID     | int  | NO   | PRI | NULL    |       |
+-------------+------+------+-----+---------+-------+
```

### Table: `stock_request`
```text
mysql> describe stock_request;
+---------------------+---------------------------------------------------+------+-----+-------------------+-------------------+
| Field               | Type                                              | Null | Key | Default           | Extra             |
+---------------------+---------------------------------------------------+------+-----+-------------------+-------------------+
| Request_ID          | int                                               | NO   | PRI | NULL              | auto_increment    |
| Customer_ID         | int                                               | NO   | MUL | NULL              |                   |
| Item_ID             | int                                               | YES  | MUL | NULL              |                   |
| Requested_Item_Name | varchar(100)                                      | YES  |     | NULL              |                   |
| Quantity_Requested  | int                                               | NO   |     | 1                 |                   |
| Request_Date        | datetime                                          | YES  |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
| Status              | enum('Pending','Approved','Rejected','Fulfilled') | NO   |     | Pending           |                   |
| Handled_By          | int                                               | YES  | MUL | NULL              |                   |
| Remarks             | varchar(255)                                      | YES  |     | NULL              |                   |
+---------------------+---------------------------------------------------+------+-----+-------------------+-------------------+
```

### Table: `supplier`
```text
mysql> describe supplier;
+---------------+--------------+------+-----+---------+----------------+
| Field         | Type         | Null | Key | Default | Extra          |
+---------------+--------------+------+-----+---------+----------------+
| Supplier_ID   | int          | NO   | PRI | NULL    | auto_increment |
| Supplier_Name | varchar(100) | NO   |     | NULL    |                |
| Phone_Number  | varchar(15)  | YES  | UNI | NULL    |                |
| GSTIN         | varchar(20)  | YES  | UNI | NULL    |                |
| Shop_Bldg_No  | varchar(20)  | YES  |     | NULL    |                |
| Street        | varchar(50)  | YES  |     | NULL    |                |
| Area          | varchar(50)  | YES  |     | NULL    |                |
| City          | varchar(50)  | YES  |     | NULL    |                |
| State         | varchar(50)  | YES  |     | NULL    |                |
| PIN_Code      | varchar(10)  | YES  |     | NULL    |                |
+---------------+--------------+------+-----+---------+----------------+
```

### Table: `users`
```text
mysql> describe users;
+---------------+-------------------------------------+------+-----+---------+----------------+
| Field         | Type                                | Null | Key | Default | Extra          |
+---------------+-------------------------------------+------+-----+---------+----------------+
| User_ID       | int                                 | NO   | PRI | NULL    | auto_increment |
| Username      | varchar(50)                         | NO   | UNI | NULL    |                |
| Password_Hash | varchar(255)                        | NO   |     | NULL    |                |
| Role          | enum('Owner','Employee','Customer') | NO   |     | NULL    |                |
| Employee_ID   | int                                 | YES  | UNI | NULL    |                |
| Customer_ID   | int                                 | YES  | UNI | NULL    |                |
+---------------+-------------------------------------+------+-----+---------+----------------+
```

### Table: `v_bill_lines`
```text
mysql> describe v_bill_lines;
+-----------------+---------------+------+-----+---------+-------+
| Field           | Type          | Null | Key | Default | Extra |
+-----------------+---------------+------+-----+---------+-------+
| Bill_ID         | int           | NO   |     | NULL    |       |
| Batch_ID        | int           | NO   |     | NULL    |       |
| Item_ID         | int           | NO   |     | 0       |       |
| Item_Name       | varchar(100)  | NO   |     | NULL    |       |
| Quantity        | int           | NO   |     | NULL    |       |
| Wholesale_Price | decimal(10,2) | NO   |     | NULL    |       |
| Purchase_Price  | decimal(10,2) | NO   |     | 0.00    |       |
| HSN_Code        | varchar(20)   | NO   |     | NULL    |       |
| GST_Percentage  | decimal(5,2)  | NO   |     | NULL    |       |
| Line_Subtotal   | decimal(20,2) | NO   |     | 0.00    |       |
| Line_GST        | decimal(24,2) | YES  |     | NULL    |       |
| Line_Total      | decimal(25,2) | YES  |     | NULL    |       |
+-----------------+---------------+------+-----+---------+-------+
```

### Table: `v_bill_totals`
```text
mysql> describe v_bill_totals;
+-----------------+---------------+------+-----+---------+-------+
| Field           | Type          | Null | Key | Default | Extra |
+-----------------+---------------+------+-----+---------+-------+
| Bill_ID         | int           | NO   |     | NULL    |       |
| Subtotal        | decimal(42,2) | YES  |     | NULL    |       |
| GST_Total       | decimal(46,2) | YES  |     | NULL    |       |
| Gross_Total     | decimal(47,2) | YES  |     | NULL    |       |
| Points_Discount | decimal(32,0) | NO   |     | 0       |       |
| Amount_Payable  | decimal(48,2) | YES  |     | NULL    |       |
+-----------------+---------------+------+-----+---------+-------+
```

### Table: `v_employee_performance`
```text
mysql> describe v_employee_performance;
+--------------------+--------------+------+-----+---------+-------+
| Field              | Type         | Null | Key | Default | Extra |
+--------------------+--------------+------+-----+---------+-------+
| Employee_ID        | int          | NO   |     | 0       |       |
| Employee_Name      | varchar(100) | NO   |     | NULL    |       |
| Bills_Handled      | bigint       | NO   |     | 0       |       |
| Avg_Rating         | decimal(6,2) | YES  |     | NULL    |       |
| Feedbacks_Received | bigint       | NO   |     | 0       |       |
+--------------------+--------------+------+-----+---------+-------+
```

### Table: `v_expiring_batches`
```text
mysql> describe v_expiring_batches;
+-------------------+--------------+------+-----+---------+-------+
| Field             | Type         | Null | Key | Default | Extra |
+-------------------+--------------+------+-----+---------+-------+
| Batch_ID          | int          | NO   |     | 0       |       |
| Item_Name         | varchar(100) | NO   |     | NULL    |       |
| Live_Stock        | int          | NO   |     | 0       |       |
| Expiry_Date       | date         | YES  |     | NULL    |       |
| Days_Until_Expiry | int          | YES  |     | NULL    |       |
| Alert_Type        | varchar(13)  | NO   |     |         |       |
+-------------------+--------------+------+-----+---------+-------+
```

### Table: `v_low_stock`
```text
mysql> describe v_low_stock;
+---------------+---------------+------+-----+---------+-------+
| Field         | Type          | Null | Key | Default | Extra |
+---------------+---------------+------+-----+---------+-------+
| Item_ID       | int           | NO   |     | 0       |       |
| Item_Name     | varchar(100)  | NO   |     | NULL    |       |
| Category_Name | varchar(50)   | NO   |     | NULL    |       |
| Total_Stock   | decimal(32,0) | YES  |     | NULL    |       |
+---------------+---------------+------+-----+---------+-------+
```

### Table: `v_product_demand`
```text
mysql> describe v_product_demand;
+---------------------+---------------+------+-----+---------+-------+
| Field               | Type          | Null | Key | Default | Extra |
+---------------------+---------------+------+-----+---------+-------+
| Product             | varchar(100)  | YES  |     | NULL    |       |
| Request_Count       | bigint        | NO   |     | 0       |       |
| Total_Qty_Requested | decimal(32,0) | YES  |     | NULL    |       |
| Product_Type        | varchar(13)   | NO   |     |         |       |
+---------------------+---------------+------+-----+---------+-------+
```

### Table: `v_profit_per_item`
```text
mysql> describe v_profit_per_item;
+---------------+---------------+------+-----+---------+-------+
| Field         | Type          | Null | Key | Default | Extra |
+---------------+---------------+------+-----+---------+-------+
| Item_Name     | varchar(100)  | NO   |     | NULL    |       |
| Category_Name | varchar(50)   | NO   |     | NULL    |       |
| Units_Sold    | decimal(32,0) | YES  |     | NULL    |       |
| Gross_Profit  | decimal(43,2) | YES  |     | NULL    |       |
+---------------+---------------+------+-----+---------+-------+
```

### Table: `v_restock_list`
```text
mysql> describe v_restock_list;
+----------------+---------------+------+-----+---------+-------+
| Field          | Type          | Null | Key | Default | Extra |
+----------------+---------------+------+-----+---------+-------+
| Item_Name      | varchar(100)  | NO   |     | NULL    |       |
| Category_Name  | varchar(50)   | NO   |     | NULL    |       |
| Current_Stock  | decimal(32,0) | YES  |     | NULL    |       |
| Supplier_Name  | varchar(100)  | NO   |     | NULL    |       |
| Supplier_Phone | varchar(15)   | YES  |     | NULL    |       |
+----------------+---------------+------+-----+---------+-------+
```

### Table: `v_sales_by_category`
```text
mysql> describe v_sales_by_category;
+---------------+---------------+------+-----+---------+-------+
| Field         | Type          | Null | Key | Default | Extra |
+---------------+---------------+------+-----+---------+-------+
| Category_Name | varchar(50)   | NO   |     | NULL    |       |
| Units_Sold    | decimal(32,0) | YES  |     | NULL    |       |
| Revenue       | decimal(47,2) | YES  |     | NULL    |       |
+---------------+---------------+------+-----+---------+-------+
```

### Table: `v_sales_by_day`
```text
mysql> describe v_sales_by_day;
+-------------+---------------+------+-----+---------+-------+
| Field       | Type          | Null | Key | Default | Extra |
+-------------+---------------+------+-----+---------+-------+
| Sale_Date   | date          | YES  |     | NULL    |       |
| Bills_Count | bigint        | NO   |     | 0       |       |
| Gross_Total | decimal(65,2) | YES  |     | NULL    |       |
| Revenue     | decimal(65,2) | YES  |     | NULL    |       |
+-------------+---------------+------+-----+---------+-------+
```

### Table: `v_sales_by_month`
```text
mysql> describe v_sales_by_month;
+-------------+---------------+------+-----+---------+-------+
| Field       | Type          | Null | Key | Default | Extra |
+-------------+---------------+------+-----+---------+-------+
| Month       | varchar(7)    | YES  |     | NULL    |       |
| Bills_Count | bigint        | NO   |     | 0       |       |
| Gross_Total | decimal(65,2) | YES  |     | NULL    |       |
| Revenue     | decimal(65,2) | YES  |     | NULL    |       |
+-------------+---------------+------+-----+---------+-------+
```

### Table: `v_top_customers`
```text
mysql> describe v_top_customers;
+----------------+---------------+------+-----+---------+-------+
| Field          | Type          | Null | Key | Default | Extra |
+----------------+---------------+------+-----+---------+-------+
| Customer_ID    | int           | NO   |     | 0       |       |
| Customer_Name  | varchar(101)  | YES  |     | NULL    |       |
| Phone_Number   | varchar(15)   | YES  |     | NULL    |       |
| Total_Bills    | bigint        | NO   |     | 0       |       |
| Total_Spend    | decimal(65,2) | YES  |     | NULL    |       |
| Loyalty_Points | int           | NO   |     | 0       |       |
+----------------+---------------+------+-----+---------+-------+
```

### Table: `v_top_items`
```text
mysql> describe v_top_items;
+---------------+---------------+------+-----+---------+-------+
| Field         | Type          | Null | Key | Default | Extra |
+---------------+---------------+------+-----+---------+-------+
| Item_Name     | varchar(100)  | NO   |     | NULL    |       |
| Category_Name | varchar(50)   | NO   |     | NULL    |       |
| Units_Sold    | decimal(32,0) | YES  |     | NULL    |       |
| Revenue       | decimal(47,2) | YES  |     | NULL    |       |
+---------------+---------------+------+-----+---------+-------+
```

