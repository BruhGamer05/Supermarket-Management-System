-- ============================================================
-- supermarket_db | Stored Procedures | Phase 2
-- Run after 01_schema.sql, 02_views.sql, 03_seed.sql
-- ============================================================
USE supermarket_db;

-- Change the statement delimiter so MySQL doesn't treat semicolons
-- inside the procedure body as the end of the CREATE statement.
DELIMITER $$

-- ============================================================
-- sp_create_bill
-- Creates one complete bill in a single atomic transaction.
--
-- Parameters:
--   p_phone          VARCHAR  Customer phone number.
--                             If found  → links existing customer (loyalty applies).
--                             If new    → auto-creates customer record (loyalty applies).
--                             If NULL   → true walk-in (no loyalty, no record created).
--   p_employee_id    INT      cashier
--   p_payment_method VARCHAR  'Cash' | 'Card' | 'UPI'
--   p_items_json     JSON     array of {item_id, qty}
--                             e.g. '[{"item_id":1,"qty":5},{"item_id":5,"qty":2}]'
--   p_redeem_points  INT      loyalty points the customer wants to redeem (0 = none)
--
-- Output (SELECT at end):
--   new Bill_ID, Customer_ID (NULL if walk-in), Amount_Payable,
--   Points_Redeemed, Points_Earned, Is_New_Customer
--
-- How FEFO works:
--   For each requested item, the procedure picks batches in
--   ascending Expiry_Date order (NULLs last) until the quantity
--   is fulfilled. This means oldest-expiry stock leaves first.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_create_bill$$
CREATE PROCEDURE sp_create_bill(
    IN p_phone          VARCHAR(15),  -- NULL for true walk-in; phone triggers lookup/create
    IN p_employee_id    INT,
    IN p_payment_method VARCHAR(10),
    IN p_items_json     JSON,         -- '[{"item_id":1,"qty":5}, ...]'
    IN p_redeem_points  INT           -- 0 if not redeeming
)
BEGIN
    -- ── Local variables ──────────────────────────────────────
    DECLARE v_customer_id    INT DEFAULT NULL;
    DECLARE v_is_new_cust    TINYINT DEFAULT 0;
    DECLARE v_new_bill_id    INT;
    DECLARE v_batch_id       INT;
    DECLARE v_batch_stock    INT;
    DECLARE v_item_id        INT;
    DECLARE v_qty_needed     INT;
    DECLARE v_qty_take       INT;
    DECLARE v_item_index     INT DEFAULT 0;
    DECLARE v_item_count     INT;
    DECLARE v_loyalty_bal    INT DEFAULT 0;
    DECLARE v_max_redeem     INT;
    DECLARE v_actual_redeem  INT DEFAULT 0;
    DECLARE v_amount_payable DECIMAL(12,2);
    DECLARE v_points_earned  INT DEFAULT 0;
    DECLARE v_done           INT DEFAULT 0;

    -- Cursor: iterate over eligible batches for one item (FEFO order).
    -- Locked with FOR UPDATE so concurrent bills wait for this transaction.
    DECLARE cur_batches CURSOR FOR
        SELECT Batch_ID, Live_Stock
        FROM Batch
        WHERE Item_ID = v_item_id
          AND Live_Stock > 0
        ORDER BY ISNULL(Expiry_Date), Expiry_Date ASC
        FOR UPDATE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- ── Validate payment method ───────────────────────────────
    IF p_payment_method NOT IN ('Cash','Card','UPI') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid payment method. Use Cash, Card or UPI.';
    END IF;

    -- ── Validate redeem amount (non-negative) ─────────────────
    IF p_redeem_points < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Points to redeem cannot be negative.';
    END IF;

    -- ── Resolve Customer_ID from phone number ─────────────────
    -- If phone is NULL → true walk-in, v_customer_id stays NULL.
    -- If phone exists  → find the customer.
    -- If phone is new  → create a minimal customer record and link.
    IF p_phone IS NOT NULL THEN
        SELECT Customer_ID INTO v_customer_id
        FROM Customer WHERE Phone_Number = p_phone
        LIMIT 1;

        -- Phone not found → create a new customer record
        IF v_customer_id IS NULL THEN
            INSERT INTO Customer (First_Name, Last_Name, Phone_Number, Loyalty_Points)
            VALUES ('Walk-in', NULL, p_phone, 0);
            SET v_customer_id = LAST_INSERT_ID();
            SET v_is_new_cust = 1;
        END IF;

        -- Load loyalty balance for the resolved customer
        SELECT Loyalty_Points INTO v_loyalty_bal
        FROM Customer WHERE Customer_ID = v_customer_id;
    END IF;

    -- ── Check customer has enough points to redeem ────────────
    IF v_customer_id IS NOT NULL AND p_redeem_points > 0 THEN
        IF p_redeem_points > v_loyalty_bal THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient loyalty points.';
        END IF;
    END IF;

    -- Walk-in (no phone) cannot redeem points
    IF v_customer_id IS NULL AND p_redeem_points > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Walk-in customers cannot redeem loyalty points.';
    END IF;

    SET v_item_count = JSON_LENGTH(p_items_json);

    IF v_item_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Bill must have at least one item.';
    END IF;

    -- ── BEGIN TRANSACTION ─────────────────────────────────────
    START TRANSACTION;

    -- Step 1: Insert the Bill header (no total stored — computed by views)
    INSERT INTO Bill (Date_Time, Payment_Method, Customer_ID, Employee_ID)
    VALUES (NOW(), p_payment_method, v_customer_id, p_employee_id);

    SET v_new_bill_id = LAST_INSERT_ID();

    -- Step 2: For each item in the JSON array, allocate stock FEFO
    SET v_item_index = 0;
    WHILE v_item_index < v_item_count DO

        -- Read this array element
        SET v_item_id   = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', v_item_index, '].item_id')));
        SET v_qty_needed = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', v_item_index, '].qty')));

        IF v_qty_needed <= 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Item quantity must be positive.';
        END IF;

        -- Open cursor over batches for this item (already locked FOR UPDATE)
        SET v_done = 0;
        OPEN cur_batches;

        fefo_loop: LOOP
            FETCH cur_batches INTO v_batch_id, v_batch_stock;
            IF v_done = 1 OR v_qty_needed = 0 THEN
                LEAVE fefo_loop;
            END IF;

            -- Take as much as available, up to what we still need
            SET v_qty_take = LEAST(v_batch_stock, v_qty_needed);

            -- Insert or add to Bill_Details for this batch
            INSERT INTO Bill_Details (Bill_ID, Batch_ID, Quantity)
            VALUES (v_new_bill_id, v_batch_id, v_qty_take)
            ON DUPLICATE KEY UPDATE Quantity = Quantity + v_qty_take;

            -- Deduct from Batch (CHECK constraint prevents going below 0)
            UPDATE Batch SET Live_Stock = Live_Stock - v_qty_take
            WHERE Batch_ID = v_batch_id;

            SET v_qty_needed = v_qty_needed - v_qty_take;
        END LOOP fefo_loop;

        CLOSE cur_batches;

        -- If we still need more after exhausting all batches → insufficient stock
        IF v_qty_needed > 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient stock for one or more items.';
        END IF;

        SET v_item_index = v_item_index + 1;
    END WHILE;

    -- Step 3: Apply loyalty redemption
    IF v_customer_id IS NOT NULL AND p_redeem_points > 0 THEN
        -- Cap: cannot redeem more than 50% of gross total
        SELECT FLOOR(SUM(Line_Total) * 0.5) INTO v_max_redeem
        FROM v_bill_lines WHERE Bill_ID = v_new_bill_id;

        IF p_redeem_points > v_max_redeem THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Loyalty redemption exceeds 50% of the bill total.';
        END IF;

        SET v_actual_redeem = p_redeem_points;

        -- Log redemption (negative Points_Change = points leaving the account)
        INSERT INTO Loyalty_Transaction (Customer_ID, Bill_ID, Txn_Type, Points_Change, Txn_Date)
        VALUES (v_customer_id, v_new_bill_id, 'Redeemed', -v_actual_redeem, NOW());

        -- Deduct from customer balance
        UPDATE Customer SET Loyalty_Points = Loyalty_Points - v_actual_redeem
        WHERE Customer_ID = v_customer_id;
    END IF;

    -- Step 4: Calculate Amount_Payable; earn loyalty for any identified customer
    SELECT Amount_Payable INTO v_amount_payable
    FROM v_bill_totals WHERE Bill_ID = v_new_bill_id;

    IF v_customer_id IS NOT NULL THEN
        -- Earn 1 point per Rs 100 of amount actually paid
        SET v_points_earned = FLOOR(v_amount_payable / 100);

        IF v_points_earned > 0 THEN
            INSERT INTO Loyalty_Transaction (Customer_ID, Bill_ID, Txn_Type, Points_Change, Txn_Date)
            VALUES (v_customer_id, v_new_bill_id, 'Earned', v_points_earned, NOW());

            UPDATE Customer SET Loyalty_Points = Loyalty_Points + v_points_earned
            WHERE Customer_ID = v_customer_id;
        END IF;
    END IF;

    COMMIT;

    -- ── Return summary to the caller ──────────────────────────
    SELECT v_new_bill_id    AS Bill_ID,
           v_customer_id    AS Customer_ID,
           v_is_new_cust    AS Is_New_Customer,
           v_amount_payable AS Amount_Payable,
           v_actual_redeem  AS Points_Redeemed,
           v_points_earned  AS Points_Earned;

END$$


-- ============================================================
-- sp_receive_stock
-- Records a new delivery: creates a Batch row.
-- A new price or new expiry = new batch (never edit an old one).
--
-- Parameters:
--   p_item_id        INT
--   p_supplier_id    INT
--   p_hsn_code       VARCHAR   must already exist in HSN_Tax_Rate
--   p_purchase_price DECIMAL   what we paid the supplier per unit
--   p_wholesale_price DECIMAL  what we charge customers (excl. GST)
--   p_quantity       INT       units received
--   p_received_date  DATE
--   p_expiry_date    DATE      NULL if no expiry
--   p_check_procures TINYINT   1 = validate supplier sells this item via Procures
-- ============================================================
DROP PROCEDURE IF EXISTS sp_receive_stock$$
CREATE PROCEDURE sp_receive_stock(
    IN p_item_id         INT,
    IN p_supplier_id     INT,
    IN p_hsn_code        VARCHAR(20),
    IN p_purchase_price  DECIMAL(10,2),
    IN p_wholesale_price DECIMAL(10,2),
    IN p_quantity        INT,
    IN p_received_date   DATE,
    IN p_expiry_date     DATE,          -- NULL if no expiry
    IN p_check_procures  TINYINT        -- 1 = enforce Procures link
)
BEGIN
    DECLARE v_procures_count INT DEFAULT 0;
    DECLARE v_new_batch_id   INT;

    -- Optionally verify the supplier sells this item
    IF p_check_procures = 1 THEN
        SELECT COUNT(*) INTO v_procures_count
        FROM Procures
        WHERE Supplier_ID = p_supplier_id AND Item_ID = p_item_id;

        IF v_procures_count = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'This supplier is not linked to this item in Procures. Add the link first or pass p_check_procures=0.';
        END IF;
    END IF;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity received must be positive.';
    END IF;

    INSERT INTO Batch (Item_ID, Supplier_ID, HSN_Code, Purchase_Price, Wholesale_Price, Live_Stock, Received_Date, Expiry_Date)
    VALUES (p_item_id, p_supplier_id, p_hsn_code, p_purchase_price, p_wholesale_price, p_quantity, p_received_date, p_expiry_date);

    SET v_new_batch_id = LAST_INSERT_ID();

    SELECT v_new_batch_id AS New_Batch_ID, p_quantity AS Stock_Added;
END$$


-- ============================================================
-- sp_resolve_stock_request
-- Approves, rejects, or fulfils a Stock_Request.
-- If approving a new-product request and the item has been added
-- to the Item table, pass its Item_ID to link it and clear the name.
--
-- Parameters:
--   p_request_id   INT
--   p_new_status   VARCHAR  'Approved' | 'Rejected' | 'Fulfilled'
--   p_handled_by   INT      Employee_ID resolving the request
--   p_remarks      VARCHAR  notes (reason for rejection, ETA, etc.)
--   p_item_id      INT      NULL unless fulfilling a new-product request
--                           (links the newly created Item to the request)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_resolve_stock_request$$
CREATE PROCEDURE sp_resolve_stock_request(
    IN p_request_id INT,
    IN p_new_status VARCHAR(20),    -- 'Approved' | 'Rejected' | 'Fulfilled'
    IN p_handled_by INT,
    IN p_remarks    VARCHAR(255),
    IN p_item_id    INT             -- NULL unless linking a new Item
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_existing_item  INT;

    -- Validate the new status value
    IF p_new_status NOT IN ('Approved','Rejected','Fulfilled') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status must be Approved, Rejected or Fulfilled.';
    END IF;

    -- Read current state of the request
    SELECT Status, Item_ID INTO v_current_status, v_existing_item
    FROM Stock_Request WHERE Request_ID = p_request_id;

    -- Enforce flow: Pending → Approved/Rejected; Approved → Fulfilled
    IF v_current_status = 'Fulfilled' OR v_current_status = 'Rejected' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request is already closed (Fulfilled or Rejected).';
    END IF;

    IF v_current_status = 'Pending' AND p_new_status = 'Fulfilled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot Fulfil a Pending request directly. Approve it first.';
    END IF;

    -- If linking a new Item (for new-product requests), clear the free-text name
    IF p_item_id IS NOT NULL THEN
        UPDATE Stock_Request
        SET Status              = p_new_status,
            Handled_By          = p_handled_by,
            Remarks             = p_remarks,
            Item_ID             = p_item_id,
            Requested_Item_Name = NULL
        WHERE Request_ID = p_request_id;
    ELSE
        UPDATE Stock_Request
        SET Status     = p_new_status,
            Handled_By = p_handled_by,
            Remarks    = p_remarks
        WHERE Request_ID = p_request_id;
    END IF;

    SELECT p_request_id AS Request_ID, p_new_status AS New_Status;
END$$

DELIMITER ;
