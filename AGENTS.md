# AGENTS.md - rules for the AI agent working on this project

## Who you are working with
A B.Tech CSE student (IIT BHU) doing a DBMS group project (Group 23) with a team. They are new to
building a database-backed system and must be able to explain every design choice in a viva.
So: keep explanations short, go step by step, say *why* before/after each action, and never skip steps.

## Project in one paragraph
Supermarket Management System for a wholesale dealer (Kriyana, Dryfruits, Desi Jadi Booti, Tota Rang
Gulal) in Muzaffarnagar. MySQL 8 database `supermarket_db` + a backend API + (later) a role-based
frontend for Owner, Employee and Customer. Read `PROJECT.md` (requirements and scope), `SCHEMA.md`
(tables and rules) and `TODO.md` (phases and current status) before doing anything.

## Files
- `PROJECT.md`, `SCHEMA.md`, `TODO.md` - source of truth. Keep `TODO.md` updated as you finish tasks.
- `db/01_schema.sql`, `db/02_views.sql`, `db/03_seed.sql` - the database. Already tested on MySQL 8.0.
- `docker-compose.yml` - optional dev MySQL via Docker.
- `Assignment1.pdf` (requirements), `Assignment2.pdf` (ER diagram), `Assignment3.pdf` (relational schema),
  `changes.txt` (TA's requested changes), `new_schema.txt` (DESCRIBE output of the friend's existing DB, before our latest decisions).
  The Assignment PDFs are OLDER than `SCHEMA.md`. Where they disagree, `SCHEMA.md` wins.

## Working rules
1. Read the files above first. Then summarize your understanding in at most 10 lines and list anything unclear.
   Ask before guessing on anything that changes the schema or business rules.
2. Work one TODO phase at a time. Stop at the end of each phase, show results, and wait for the user.
3. Never run `sudo` yourself. Give the user the exact command and wait. Ask before installing anything.
4. `db/01_schema.sql` DROPS and recreates all tables. Never run it against a database that holds data
   the user wants to keep without asking first.
5. Schema changes: edit `db/01_schema.sql` AND `SCHEMA.md` together, and tell the user what changed and why.
6. After any SQL change, reload the database and run the checks in `TODO.md` Phase 1.
7. Do not invent requirements. If something is not in the docs, ask.
8. Report errors honestly with the real message. Do not claim something works until you ran it.

## Business rules (do not break these)
- Prices and totals are NEVER stored on a bill. They are computed through
  `Bill_Details -> Batch (Wholesale_Price, HSN_Code) -> HSN_Tax_Rate`. See views `v_bill_lines`, `v_bill_totals`.
- `HSN_Tax_Rate` is insert-only. If GST changes, insert a new HSN code with the new rate.
  Never UPDATE/DELETE a rate row.
- Never edit `Wholesale_Price` or `HSN_Code` on a batch that has been sold from. A new price = a new batch.
- `Wholesale_Price` is the price charged to customers and EXCLUDES GST. Line total = Qty x Price x (1 + GST%/100).
- Stock lives in `Batch.Live_Stock` and must never go negative (CHECK constraint exists). Billing must run in ONE
  transaction that locks the batch rows (`SELECT ... FOR UPDATE`), checks stock, inserts the bill lines, deducts stock,
  and applies loyalty. Concurrent bills for the last units must not oversell.
- Loyalty (placeholder rules, owner may change): earn 1 point per Rs 100 of amount paid (after GST and discount);
  redeem 1 point = Rs 1 off, max 50% of the bill; walk-in bills (Customer_ID NULL) earn/redeem nothing.
  Every change is logged in `Loyalty_Transaction` (redeemed = negative); `Customer.Loyalty_Points` is the running balance.
- Passwords: store bcrypt (or argon2) hashes only, in `Users.Password_Hash`. Never plain text, never log them.
- Roles: Owner, Employee, Customer. Enforce permissions in the backend, not only in the frontend.
- When billing, stock should be taken from the batch with the earliest expiry first (FEFO) unless told otherwise.
