-- ============================================================
-- supermarket_db | Insight Views | Phase 2
-- For the Owner dashboard. All read-only.
-- Run after 04_procedures.sql (though order doesn't matter for views)
-- ============================================================
USE supermarket_db;

-- ── 1. Low stock alert ────────────────────────────────────────
-- Items whose total live stock across all batches is <= 50 units.
-- Threshold of 50 is illustrative; adjust as needed.
CREATE OR REPLACE VIEW v_low_stock AS
SELECT i.Item_ID, i.Item_Name, c.Category_Name,
       SUM(b.Live_Stock) AS Total_Stock
FROM Item i
JOIN Category c ON c.Category_ID = i.Category_ID
LEFT JOIN Batch b ON b.Item_ID = i.Item_ID
GROUP BY i.Item_ID, i.Item_Name, c.Category_Name
HAVING Total_Stock <= 50 OR Total_Stock IS NULL
ORDER BY Total_Stock ASC;

-- ── 2. Batches expiring within 30 days (or already expired) ──
CREATE OR REPLACE VIEW v_expiring_batches AS
SELECT b.Batch_ID, i.Item_Name, b.Live_Stock,
       b.Expiry_Date,
       DATEDIFF(b.Expiry_Date, CURDATE()) AS Days_Until_Expiry,
       CASE
           WHEN b.Expiry_Date < CURDATE() THEN 'Expired'
           ELSE 'Expiring Soon'
       END AS Alert_Type
FROM Batch b
JOIN Item i ON i.Item_ID = b.Item_ID
WHERE b.Expiry_Date IS NOT NULL
  AND b.Expiry_Date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
  AND b.Live_Stock > 0
ORDER BY b.Expiry_Date ASC;

-- ── 3. Daily sales summary ─────────────────────────────────────
CREATE OR REPLACE VIEW v_sales_by_day AS
SELECT DATE(bi.Date_Time)        AS Sale_Date,
       COUNT(DISTINCT bi.Bill_ID) AS Bills_Count,
       SUM(vbt.Gross_Total)       AS Gross_Total,
       SUM(vbt.Amount_Payable)    AS Revenue
FROM Bill bi
JOIN v_bill_totals vbt ON vbt.Bill_ID = bi.Bill_ID
GROUP BY DATE(bi.Date_Time)
ORDER BY Sale_Date DESC;

-- ── 4. Monthly sales summary ──────────────────────────────────
CREATE OR REPLACE VIEW v_sales_by_month AS
SELECT DATE_FORMAT(bi.Date_Time,'%Y-%m') AS Month,
       COUNT(DISTINCT bi.Bill_ID)         AS Bills_Count,
       SUM(vbt.Gross_Total)               AS Gross_Total,
       SUM(vbt.Amount_Payable)            AS Revenue
FROM Bill bi
JOIN v_bill_totals vbt ON vbt.Bill_ID = bi.Bill_ID
GROUP BY DATE_FORMAT(bi.Date_Time,'%Y-%m')
ORDER BY Month DESC;

-- ── 5. Sales by category ──────────────────────────────────────
CREATE OR REPLACE VIEW v_sales_by_category AS
SELECT c.Category_Name,
       SUM(vbl.Quantity)         AS Units_Sold,
       SUM(vbl.Line_Total)       AS Revenue
FROM v_bill_lines vbl
JOIN Item i ON i.Item_ID = vbl.Item_ID
JOIN Category c ON c.Category_ID = i.Category_ID
GROUP BY c.Category_Name
ORDER BY Revenue DESC;

-- ── 6. Top 10 items by revenue ────────────────────────────────
CREATE OR REPLACE VIEW v_top_items AS
SELECT i.Item_Name, c.Category_Name,
       SUM(vbl.Quantity)   AS Units_Sold,
       SUM(vbl.Line_Total) AS Revenue
FROM v_bill_lines vbl
JOIN Item i ON i.Item_ID = vbl.Item_ID
JOIN Category c ON c.Category_ID = i.Category_ID
GROUP BY i.Item_ID, i.Item_Name, c.Category_Name
ORDER BY Revenue DESC
LIMIT 10;

-- ── 7. Top 10 customers by spend ─────────────────────────────
CREATE OR REPLACE VIEW v_top_customers AS
SELECT cu.Customer_ID,
       CONCAT(cu.First_Name,' ',cu.Last_Name) AS Customer_Name,
       cu.Phone_Number,
       COUNT(DISTINCT bi.Bill_ID)              AS Total_Bills,
       SUM(vbt.Amount_Payable)                 AS Total_Spend,
       cu.Loyalty_Points
FROM Customer cu
JOIN Bill bi ON bi.Customer_ID = cu.Customer_ID
JOIN v_bill_totals vbt ON vbt.Bill_ID = bi.Bill_ID
GROUP BY cu.Customer_ID, Customer_Name, cu.Phone_Number, cu.Loyalty_Points
ORDER BY Total_Spend DESC
LIMIT 10;

-- ── 8. Profit per item ────────────────────────────────────────
-- Profit = (Wholesale_Price - Purchase_Price) x Quantity sold
CREATE OR REPLACE VIEW v_profit_per_item AS
SELECT i.Item_Name, c.Category_Name,
       SUM(vbl.Quantity)                                        AS Units_Sold,
       SUM((vbl.Wholesale_Price - vbl.Purchase_Price) * vbl.Quantity) AS Gross_Profit
FROM v_bill_lines vbl
JOIN Item i ON i.Item_ID = vbl.Item_ID
JOIN Category c ON c.Category_ID = i.Category_ID
GROUP BY i.Item_ID, i.Item_Name, c.Category_Name
ORDER BY Gross_Profit DESC;

-- ── 9. Employee performance: avg rating + bills handled ───────
CREATE OR REPLACE VIEW v_employee_performance AS
SELECT e.Employee_ID, e.Name AS Employee_Name,
       COUNT(DISTINCT bi.Bill_ID)        AS Bills_Handled,
       ROUND(AVG(ef.Rating), 2)          AS Avg_Rating,
       COUNT(ef.Feedback_ID)             AS Feedbacks_Received
FROM Employee e
LEFT JOIN Bill bi ON bi.Employee_ID = e.Employee_ID
LEFT JOIN Employee_Feedback ef ON ef.Bill_ID = bi.Bill_ID
GROUP BY e.Employee_ID, e.Name
ORDER BY Avg_Rating DESC;

-- ── 10. Product demand from Stock_Request ────────────────────
CREATE OR REPLACE VIEW v_product_demand AS
-- Existing items being requested
SELECT i.Item_Name AS Product,
       COUNT(*) AS Request_Count,
       SUM(sr.Quantity_Requested) AS Total_Qty_Requested,
       'Existing Item' AS Product_Type
FROM Stock_Request sr
JOIN Item i ON i.Item_ID = sr.Item_ID
WHERE sr.Item_ID IS NOT NULL
GROUP BY i.Item_Name

UNION ALL

-- New products being requested (not yet in catalog)
SELECT sr.Requested_Item_Name AS Product,
       COUNT(*) AS Request_Count,
       SUM(sr.Quantity_Requested) AS Total_Qty_Requested,
       'New Product' AS Product_Type
FROM Stock_Request sr
WHERE sr.Requested_Item_Name IS NOT NULL
GROUP BY sr.Requested_Item_Name
ORDER BY Request_Count DESC;

-- ── 11. Restock list: low-stock items with their suppliers ────
CREATE OR REPLACE VIEW v_restock_list AS
SELECT i.Item_Name, c.Category_Name,
       SUM(b.Live_Stock) AS Current_Stock,
       s.Supplier_Name,
       s.Phone_Number    AS Supplier_Phone
FROM Item i
JOIN Category c   ON c.Category_ID = i.Category_ID
LEFT JOIN Batch b ON b.Item_ID     = i.Item_ID
JOIN Procures p   ON p.Item_ID     = i.Item_ID
JOIN Supplier s   ON s.Supplier_ID = p.Supplier_ID
GROUP BY i.Item_ID, i.Item_Name, c.Category_Name, s.Supplier_ID, s.Supplier_Name, s.Phone_Number
HAVING Current_Stock <= 50 OR Current_Stock IS NULL
ORDER BY Current_Stock ASC;
