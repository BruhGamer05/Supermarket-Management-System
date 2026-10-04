-- ============================================================
-- supermarket_db  |  Schema v2  |  Target: MySQL 8.0.16+
-- Run order: 01_schema.sql -> 02_views.sql -> 03_seed.sql
-- WARNING: drops and recreates every table (dev use only).
-- ============================================================
CREATE DATABASE IF NOT EXISTS supermarket_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE supermarket_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Users, Employee_Feedback, Loyalty_Transaction, Stock_Request,
                     Bill_Details, Bill, Batch, Procures, Item, HSN_Tax_Rate,
                     Supplier, Customer, Employee, Category;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE Category (
  Category_ID    INT AUTO_INCREMENT PRIMARY KEY,
  Category_Name  VARCHAR(50) NOT NULL,
  Aisle_Location VARCHAR(20)
);

CREATE TABLE Employee (
  Employee_ID    INT AUTO_INCREMENT PRIMARY KEY,
  Name           VARCHAR(100) NOT NULL,
  Phone_Number   VARCHAR(15) UNIQUE,
  Shift_Schedule VARCHAR(50),
  Category_ID    INT NULL,
  FOREIGN KEY (Category_ID) REFERENCES Category(Category_ID)
);

CREATE TABLE Customer (
  Customer_ID    INT AUTO_INCREMENT PRIMARY KEY,
  First_Name     VARCHAR(50) NOT NULL,
  Last_Name      VARCHAR(50),
  Phone_Number   VARCHAR(15) UNIQUE,
  Loyalty_Points INT NOT NULL DEFAULT 0,
  Shop_Bldg_No   VARCHAR(20),
  Street         VARCHAR(50),
  Area           VARCHAR(50),
  City           VARCHAR(50),
  State          VARCHAR(50),
  PIN_Code       VARCHAR(10),
  CHECK (Loyalty_Points >= 0)
);

CREATE TABLE Supplier (
  Supplier_ID   INT AUTO_INCREMENT PRIMARY KEY,
  Supplier_Name VARCHAR(100) NOT NULL,
  Phone_Number  VARCHAR(15) UNIQUE,
  GSTIN         VARCHAR(20) UNIQUE,
  Shop_Bldg_No  VARCHAR(20),
  Street        VARCHAR(50),
  Area          VARCHAR(50),
  City          VARCHAR(50),
  State         VARCHAR(50),
  PIN_Code      VARCHAR(10)
);

-- Insert-only: never UPDATE or DELETE rows (old bills depend on them).
CREATE TABLE HSN_Tax_Rate (
  HSN_Code       VARCHAR(20) PRIMARY KEY,
  GST_Percentage DECIMAL(5,2) NOT NULL,
  CHECK (GST_Percentage BETWEEN 0 AND 100)
);

CREATE TABLE Item (
  Item_ID     INT AUTO_INCREMENT PRIMARY KEY,
  Item_Name   VARCHAR(100) NOT NULL,
  Category_ID INT NULL,
  FOREIGN KEY (Category_ID) REFERENCES Category(Category_ID),
  INDEX idx_item_name (Item_Name)
);

-- Which supplier sells which item (not a purchase record; purchases live in Batch)
CREATE TABLE Procures (
  Supplier_ID INT NOT NULL,
  Item_ID     INT NOT NULL,
  PRIMARY KEY (Supplier_ID, Item_ID),
  FOREIGN KEY (Supplier_ID) REFERENCES Supplier(Supplier_ID) ON DELETE CASCADE,
  FOREIGN KEY (Item_ID)     REFERENCES Item(Item_ID)         ON DELETE CASCADE
);

-- One batch = one purchase of one item from one supplier.
-- Wholesale_Price = price charged to customers (excludes GST).
-- Do not edit Wholesale_Price / HSN_Code after the batch has been sold from.
CREATE TABLE Batch (
  Batch_ID        INT AUTO_INCREMENT PRIMARY KEY,
  Item_ID         INT NOT NULL,
  Supplier_ID     INT NULL,
  HSN_Code        VARCHAR(20) NOT NULL,
  Purchase_Price  DECIMAL(10,2) NOT NULL DEFAULT 0,
  Wholesale_Price DECIMAL(10,2) NOT NULL,
  Live_Stock      INT NOT NULL DEFAULT 0,
  Received_Date   DATE DEFAULT (CURRENT_DATE),
  Expiry_Date     DATE NULL,
  FOREIGN KEY (Item_ID)     REFERENCES Item(Item_ID),
  FOREIGN KEY (Supplier_ID) REFERENCES Supplier(Supplier_ID),
  FOREIGN KEY (HSN_Code)    REFERENCES HSN_Tax_Rate(HSN_Code),
  CHECK (Live_Stock >= 0),
  CHECK (Purchase_Price >= 0),
  CHECK (Wholesale_Price >= 0)
);

-- No stored total: computed in 02_views.sql (v_bill_lines, v_bill_totals).
-- Customer_ID is NULL for walk-in customers (no loyalty points).
CREATE TABLE Bill (
  Bill_ID        INT AUTO_INCREMENT PRIMARY KEY,
  Date_Time      DATETIME DEFAULT CURRENT_TIMESTAMP,
  Payment_Method ENUM('Cash','Card','UPI') NOT NULL,
  Customer_ID    INT NULL,
  Employee_ID    INT NULL,
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID),
  FOREIGN KEY (Employee_ID) REFERENCES Employee(Employee_ID)
);

CREATE TABLE Bill_Details (
  Bill_ID  INT NOT NULL,
  Batch_ID INT NOT NULL,
  Quantity INT NOT NULL,
  PRIMARY KEY (Bill_ID, Batch_ID),
  FOREIGN KEY (Bill_ID)  REFERENCES Bill(Bill_ID),
  FOREIGN KEY (Batch_ID) REFERENCES Batch(Batch_ID),
  CHECK (Quantity > 0)
);

-- Either Item_ID (existing item, out of stock) OR Requested_Item_Name (new product).
CREATE TABLE Stock_Request (
  Request_ID          INT AUTO_INCREMENT PRIMARY KEY,
  Customer_ID         INT NOT NULL,
  Item_ID             INT NULL,
  Requested_Item_Name VARCHAR(100) NULL,
  Quantity_Requested  INT NOT NULL DEFAULT 1,
  Request_Date        DATETIME DEFAULT CURRENT_TIMESTAMP,
  Status              ENUM('Pending','Approved','Rejected','Fulfilled') NOT NULL DEFAULT 'Pending',
  Handled_By          INT NULL,
  Remarks             VARCHAR(255) NULL,
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID),
  FOREIGN KEY (Item_ID)     REFERENCES Item(Item_ID),
  FOREIGN KEY (Handled_By)  REFERENCES Employee(Employee_ID),
  CHECK (Quantity_Requested > 0),
  CHECK ((Item_ID IS NOT NULL) <> (Requested_Item_Name IS NOT NULL))
);

-- Points_Change: positive = Earned, negative = Redeemed.
CREATE TABLE Loyalty_Transaction (
  Txn_ID        INT AUTO_INCREMENT PRIMARY KEY,
  Customer_ID   INT NOT NULL,
  Bill_ID       INT NOT NULL,
  Txn_Type      ENUM('Earned','Redeemed') NOT NULL,
  Points_Change INT NOT NULL,
  Txn_Date      DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID),
  FOREIGN KEY (Bill_ID)     REFERENCES Bill(Bill_ID)
);

-- One feedback per bill; the employee is Bill.Employee_ID.
CREATE TABLE Employee_Feedback (
  Feedback_ID   INT AUTO_INCREMENT PRIMARY KEY,
  Bill_ID       INT NOT NULL UNIQUE,
  Rating        TINYINT NOT NULL,
  Comments      VARCHAR(500),
  Feedback_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (Bill_ID) REFERENCES Bill(Bill_ID),
  CHECK (Rating BETWEEN 1 AND 5)
);

-- Login. Owner has no Employee/Customer link. Store bcrypt hashes only.
CREATE TABLE Users (
  User_ID       INT AUTO_INCREMENT PRIMARY KEY,
  Username      VARCHAR(50) NOT NULL UNIQUE,
  Password_Hash VARCHAR(255) NOT NULL,
  Role          ENUM('Owner','Employee','Customer') NOT NULL,
  Employee_ID   INT NULL UNIQUE,
  Customer_ID   INT NULL UNIQUE,
  FOREIGN KEY (Employee_ID) REFERENCES Employee(Employee_ID),
  FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID),
  CHECK (
    (Role = 'Owner'    AND Employee_ID IS NULL     AND Customer_ID IS NULL) OR
    (Role = 'Employee' AND Employee_ID IS NOT NULL AND Customer_ID IS NULL) OR
    (Role = 'Customer' AND Customer_ID IS NOT NULL AND Employee_ID IS NULL)
  )
);
