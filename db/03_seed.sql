-- Sample data for development/testing only (names, phones, GSTINs, prices are fictional;
-- GST rates are illustrative - verify before real use).
-- Run after 01_schema.sql and 02_views.sql. Users are NOT seeded here: the backend creates
-- users with bcrypt-hashed passwords (see TODO.md).
USE supermarket_db;

INSERT INTO Category (Category_Name, Aisle_Location) VALUES
 ('Kriyana','A1'),('Dryfruits','B2'),('Desi Jadi Booti','C3'),('Tota Rang Gulal','D4');

INSERT INTO Employee (Name, Phone_Number, Shift_Schedule, Category_ID) VALUES
 ('Ramesh Verma','9810000001','Morning 8-4',1),
 ('Sunita Devi','9810000002','Morning 8-4',2),
 ('Imran Khan','9810000003','Evening 2-10',4),
 ('Pooja Sharma','9810000004','Evening 2-10',3);

INSERT INTO Customer (First_Name, Last_Name, Phone_Number, Shop_Bldg_No, Street, Area, City, State, PIN_Code) VALUES
 ('Anil','Gupta','9820000001','12','Railway Road','Civil Lines','Muzaffarnagar','Uttar Pradesh','251001'),
 ('Rekha','Singhal','9820000002','45','Meerut Road','Shastri Nagar','Muzaffarnagar','Uttar Pradesh','251001'),
 ('Vikram','Jain','9820000003','7','Subhash Chowk','Old City','Muzaffarnagar','Uttar Pradesh','251002'),
 ('Farhan','Ahmed','9820000004','21','Kachehri Road','Khalapar','Muzaffarnagar','Uttar Pradesh','251001'),
 ('Suman','Tyagi','9820000005','3','Bhopa Road','Gandhi Colony','Muzaffarnagar','Uttar Pradesh','251001');

INSERT INTO Supplier (Supplier_Name, Phone_Number, GSTIN, Shop_Bldg_No, Street, Area, City, State, PIN_Code) VALUES
 ('Narayan Agro Traders','9830000001','09AAAFN7008D1ZL','15','Mandi Road','Anaj Mandi','Muzaffarnagar','Uttar Pradesh','251001'),
 ('Shree Dryfruit House','9830000002','07AABCS1234F1Z5','88','Khari Baoli','Old Delhi','Delhi','Delhi','110006'),
 ('Himalaya Herbs & Colours','9830000003','09AACCH5678K1Z2','4','Station Road','Haridwar Bypass','Saharanpur','Uttar Pradesh','247001');

INSERT INTO HSN_Tax_Rate (HSN_Code, GST_Percentage) VALUES
 ('1006',5.00),('1101',5.00),('1701',5.00),('1512',5.00),('0910',5.00),
 ('0801',5.00),('0802',5.00),('0806',5.00),('1211',12.00),('3212',18.00);

INSERT INTO Item (Item_Name, Category_ID) VALUES
 ('Basmati Rice',1),('Sugar',1),('Mustard Oil',1),('Turmeric Powder',1),
 ('Cashew (Kaju)',2),('Almonds (Badam)',2),('Raisins (Kishmish)',2),
 ('Ashwagandha Root',3),('Tulsi Leaves Dried',3),
 ('Holi Gulal Red',4),('Holi Gulal Green',4),('Wheat Flour (Atta)',1);

INSERT INTO Procures (Supplier_ID, Item_ID) VALUES
 (1,1),(1,2),(1,3),(1,12),(2,4),(2,5),(2,6),(2,7),(3,8),(3,9),(3,10),(3,11);

INSERT INTO Batch (Item_ID, Supplier_ID, HSN_Code, Purchase_Price, Wholesale_Price, Live_Stock, Received_Date, Expiry_Date) VALUES
 (1,1,'1006',80,92,500,'2026-09-10','2027-09-10'),
 (2,1,'1701',40,44,800,'2026-09-12','2027-06-01'),
 (3,1,'1512',130,145,300,'2026-09-15','2027-03-15'),
 (4,2,'0910',150,170,200,'2026-09-18','2027-08-01'),
 (5,2,'0801',650,720,120,'2026-09-20','2027-02-20'),
 (6,2,'0802',620,690,0,'2026-08-01','2026-12-31'),
 (7,2,'0806',280,320,90,'2026-09-22','2027-01-10'),
 (8,3,'1211',220,260,60,'2026-09-05','2026-10-20'),
 (9,3,'1211',180,210,45,'2026-08-20','2026-09-30'),
 (10,3,'3212',60,75,400,'2026-09-01',NULL),
 (11,3,'3212',60,75,350,'2026-09-01',NULL),
 (12,1,'1101',32,36,1000,'2026-09-25','2026-12-25'),
 (1,1,'1006',85,98,300,'2026-10-01','2027-10-01');

INSERT INTO Bill (Bill_ID, Date_Time, Payment_Method, Customer_ID, Employee_ID) VALUES
 (1,'2026-09-28 11:15:00','UPI', 1,1),
 (2,'2026-09-29 16:40:00','Cash',2,2),
 (3,'2026-10-01 10:05:00','Card',3,1),
 (4,'2026-10-02 12:30:00','UPI', 2,2),
 (5,'2026-10-03 18:20:00','Cash',NULL,3);

INSERT INTO Bill_Details (Bill_ID, Batch_ID, Quantity) VALUES
 (1,1,100),(1,5,5),
 (2,5,20),(2,7,10),(2,4,15),
 (3,2,200),(3,3,40),(3,12,100),
 (4,13,50),(4,10,60),
 (5,11,20),(5,10,10);

-- Stock deduction for the seeded bills
UPDATE Batch b JOIN (SELECT Batch_ID, SUM(Quantity) AS q FROM Bill_Details GROUP BY Batch_ID) s
  ON s.Batch_ID = b.Batch_ID
SET b.Live_Stock = b.Live_Stock - s.q;

-- Loyalty: customer 2 redeems 100 points on bill 4, then earns on the amount paid
INSERT INTO Loyalty_Transaction (Customer_ID, Bill_ID, Txn_Type, Points_Change, Txn_Date)
VALUES (2,4,'Redeemed',-100,'2026-10-02 12:30:00');

INSERT INTO Loyalty_Transaction (Customer_ID, Bill_ID, Txn_Type, Points_Change, Txn_Date)
SELECT b.Customer_ID, t.Bill_ID, 'Earned', FLOOR(t.Amount_Payable / 100), b.Date_Time
FROM v_bill_totals t JOIN Bill b ON b.Bill_ID = t.Bill_ID
WHERE b.Customer_ID IS NOT NULL;

UPDATE Customer c
SET c.Loyalty_Points = COALESCE((SELECT SUM(Points_Change) FROM Loyalty_Transaction t
                                 WHERE t.Customer_ID = c.Customer_ID), 0);

INSERT INTO Employee_Feedback (Bill_ID, Rating, Comments) VALUES
 (1,5,'Quick billing and helpful with prices'),
 (2,3,'Had to wait a long time at the counter');

INSERT INTO Stock_Request (Customer_ID, Item_ID, Requested_Item_Name, Quantity_Requested, Status, Handled_By, Remarks) VALUES
 (3,6,NULL,20,'Pending',NULL,NULL),
 (1,NULL,'Pistachio (Pista)',10,'Pending',NULL,NULL),
 (4,NULL,'Organic Jaggery',25,'Approved',1,'Will order from Narayan Agro Traders');
