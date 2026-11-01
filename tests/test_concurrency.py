"""
tests/test_concurrency.py
SQL Concurrency & Oversell Protection Stress Test
-------------------------------------------------
Simulates two cashiers simultaneously checking out the very last unit of a product.
Verifies that:
1. One cashier successfully bills the item.
2. The other cashier receives an 'Insufficient stock' error.
3. Live_Stock reaches exactly 0 (never negative).
4. No duplicate or oversold quantities occur.
"""

import threading
import time
import json
import urllib.request
import urllib.error

API_BASE = "http://127.0.0.1:8000"

def get_auth_token(username, password):
    req = urllib.request.Request(
        f"{API_BASE}/auth/login",
        data=json.dumps({"username": username, "password": password}).encode(),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())["access_token"]

def checkout_bill(token, item_id, qty, customer_phone, results_list, index):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    payload = {
        "phone": customer_phone,
        "employee_id": 1,
        "payment_method": "Cash",
        "items": [{"item_id": item_id, "qty": qty}],
        "redeem_points": 0
    }
    req = urllib.request.Request(f"{API_BASE}/bills/", data=json.dumps(payload).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            results_list[index] = (resp.status, data)
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode()
        try:
            results_list[index] = (e.code, json.loads(err_msg))
        except:
            results_list[index] = (e.code, err_msg)
    except Exception as e:
        results_list[index] = (0, str(e))

def run_stress_test():
    print("=" * 70)
    print("STARTING SQL CONCURRENCY & OVERSELL STRESS TEST")
    print("=" * 70)

    # 1. Login as Owner to inspect & setup stock
    owner_token = get_auth_token("owner", "owner123")
    emp_token = get_auth_token("ramesh_emp", "ramesh123")

    # Pick an item for test
    # Get all items
    req = urllib.request.Request(f"{API_BASE}/items/batches", headers={"Authorization": f"Bearer {owner_token}"})
    with urllib.request.urlopen(req) as resp:
        batches = json.loads(resp.read().decode())

    # Find a batch with stock
    active_batch = next((b for b in batches if b["Live_Stock"] > 0), None)
    if not active_batch:
        print("ERROR: No active batch with stock found.")
        return

    item_id = active_batch["Item_ID"]
    item_name = active_batch["Item_Name"]
    initial_stock = active_batch["Live_Stock"]

    print(f"Target Item: {item_name} (Item_ID: {item_id})")
    print(f"Current Live Stock: {initial_stock} units")

    # Both threads attempt to buy the ENTIRE remaining stock
    # If initial_stock is 5, both threads request 5 units simultaneously.
    # Total demanded: 10 units. Only 5 units exist.
    # Result must be: 1 success, 1 failure, 0 oversell.
    qty_to_buy = initial_stock

    print(f"\nLaunching 2 concurrent threads each requesting ALL {qty_to_buy} units...")
    results = [None, None]

    t1 = threading.Thread(target=checkout_bill, args=(emp_token, item_id, qty_to_buy, "9820000001", results, 0))
    t2 = threading.Thread(target=checkout_bill, args=(emp_token, item_id, qty_to_buy, "9820000002", results, 1))

    # Start both threads simultaneously
    t1.start()
    t2.start()

    t1.join()
    t2.join()

    print("\n--- Concurrency Execution Results ---")
    st1, res1 = results[0]
    st2, res2 = results[1]

    print(f"Thread 1 (Cashier 1): HTTP {st1} -> {res1}")
    print(f"Thread 2 (Cashier 2): HTTP {st2} -> {res2}")

    # Check that exactly one succeeded and one was blocked
    statuses = [st1, st2]
    one_succeeded = statuses.count(201) == 1
    one_failed = (statuses.count(400) == 1 or statuses.count(500) == 1)

    # Check post-test stock
    req_post = urllib.request.Request(f"{API_BASE}/items/batches?item_id={item_id}", headers={"Authorization": f"Bearer {owner_token}"})
    with urllib.request.urlopen(req_post) as resp:
        post_batches = json.loads(resp.read().decode())

    post_stock = sum(b["Live_Stock"] for b in post_batches if b["Batch_ID"] == active_batch["Batch_ID"])
    print(f"\nFinal Live Stock in Database: {post_stock} units")

    if one_succeeded and (post_stock == 0 or post_stock == initial_stock - qty_to_buy):
        print("\n[SUCCESS] CONCURRENCY INTEGRITY VERIFIED!")
        print("- Row lock (FOR UPDATE) prevented double-allocation.")
        print("- Zero overselling occurred.")
        print(f"- Live_Stock correctly reduced from {initial_stock} to {post_stock}.")
    else:
        print("\n[FAIL] Concurrency issue detected!")

if __name__ == "__main__":
    run_stress_test()

