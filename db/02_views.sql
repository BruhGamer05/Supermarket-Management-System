USE supermarket_db;

-- Per-line computed amounts (price and GST are never stored on the bill).
CREATE OR REPLACE VIEW v_bill_lines AS
SELECT bd.Bill_ID, bd.Batch_ID, i.Item_ID, i.Item_Name, bd.Quantity,
       b.Wholesale_Price, b.Purchase_Price, h.HSN_Code, h.GST_Percentage,
       bd.Quantity * b.Wholesale_Price                                        AS Line_Subtotal,
       ROUND(bd.Quantity * b.Wholesale_Price * h.GST_Percentage / 100, 2)     AS Line_GST,
       ROUND(bd.Quantity * b.Wholesale_Price * (1 + h.GST_Percentage/100), 2) AS Line_Total
FROM Bill_Details bd
JOIN Batch b        ON b.Batch_ID = bd.Batch_ID
JOIN Item i         ON i.Item_ID  = b.Item_ID
JOIN HSN_Tax_Rate h ON h.HSN_Code = b.HSN_Code;

-- Per-bill totals; loyalty discount is read from Loyalty_Transaction (1 point = Rs 1).
CREATE OR REPLACE VIEW v_bill_totals AS
SELECT l.Bill_ID,
       SUM(l.Line_Subtotal) AS Subtotal,
       SUM(l.Line_GST)      AS GST_Total,
       SUM(l.Line_Total)    AS Gross_Total,
       COALESCE(r.Points_Discount, 0)                        AS Points_Discount,
       SUM(l.Line_Total) - COALESCE(r.Points_Discount, 0)    AS Amount_Payable
FROM v_bill_lines l
LEFT JOIN (
  SELECT Bill_ID, -SUM(Points_Change) AS Points_Discount
  FROM Loyalty_Transaction WHERE Txn_Type = 'Redeemed' GROUP BY Bill_ID
) r ON r.Bill_ID = l.Bill_ID
GROUP BY l.Bill_ID, r.Points_Discount;
