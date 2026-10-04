USE supermarket_db;

-- ── Test A: Known customer by phone (Rekha = 9820000002), redeem 30 points ──
CALL sp_create_bill('9820000002', 2, 'Card', '[{"item_id":12,"qty":5}]', 30);

-- ── Test B: New phone number → auto-create customer, earn points ──
CALL sp_create_bill('9999999999', 1, 'Cash', '[{"item_id":10,"qty":2}]', 0);

-- ── Test C: True walk-in (NULL phone), no loyalty ──
CALL sp_create_bill(NULL, 3, 'Cash', '[{"item_id":11,"qty":1}]', 0);

-- Verify the new customer was created for Test B
SELECT Customer_ID, First_Name, Phone_Number, Loyalty_Points FROM Customer ORDER BY Customer_ID DESC LIMIT 3;
