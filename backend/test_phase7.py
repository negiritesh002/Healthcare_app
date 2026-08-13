import json
import subprocess
import urllib.request
import urllib.error
import concurrent.futures

BASE_URL = 'http://localhost:8000'

def request(method, path, data=None, headers=None):
    url = f"{BASE_URL}{path}"
    headers = headers or {}
    body = None
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            resp_body = resp.read().decode('utf-8')
            return resp.status, json.loads(resp_body) if resp_body else None
    except urllib.error.HTTPError as e:
        resp_body = e.read().decode('utf-8')
        return e.code, json.loads(resp_body) if resp_body else None

def get_otp_from_redis(phone):
    out = subprocess.check_output(
        ["docker", "compose", "exec", "redis", "redis-cli", "GET", f"otp:{phone}"],
        cwd=r"e:\flutter health care app\backend"
    )
    return out.decode().strip()

def get_doctor_token(phone, name, specialty):
    request("POST", "/auth/send-otp", {"phone": phone})
    otp = get_otp_from_redis(phone)

    code, resp_v = request("POST", "/auth/verify-otp", {"phone": phone, "otp_code": otp})

    if not resp_v or not resp_v.get("exists"):
        code, resp_s = request("POST", "/auth/signup", {
            "full_name": name,
            "phone": phone,
            "medical_specialty": specialty,
            "hospital_clinic_address": "Main Hospital",
            "medical_license_number": "LIC-8888"
        })
        return resp_s["access_token"]
    return resp_v["access_token"]

def run_test():
    print("=== STARTING PHASE 7 INTEGRATION & NURSES/AMBULANCE ACCEPTANCE TEST ===")

    # Doctor A & Doctor B Tokens
    token_a = get_doctor_token("+15557778888", "Dr. Florence", "Emergency")
    headers_a = {"Authorization": f"Bearer {token_a}"}

    token_b = get_doctor_token("+15559990000", "Dr. House", "Internal Medicine")
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Create Patients
    _, p_a_json = request("POST", "/patients", {
        "full_name": "Phase 7 Patient Alpha",
        "date_of_birth": "1988-03-25",
        "gender": "male",
        "phone": "+15550007777",
        "chief_complaint": "Chest pain",
        "severity": "critical"
    }, headers=headers_a)
    p_a = p_a_json["id"]

    _, p_b_json = request("POST", "/patients", {
        "full_name": "Phase 7 Patient Beta",
        "date_of_birth": "1995-11-12",
        "gender": "female",
        "phone": "+15550008888",
        "chief_complaint": "Fracture",
        "severity": "medium"
    }, headers=headers_b)
    p_b = p_b_json["id"]

    # ----------------------------------------------------
    # TEST NURSE MODULE
    # ----------------------------------------------------
    print("\n1. Testing Nurse Staff Directory (Shared Resource)...")
    code, nurses = request("GET", "/nurses", headers=headers_a)
    assert code == 200, f"Failed to list nurses: {code}"
    print(f"Seeded Nurses Count: {len(nurses)}")
    assert len(nurses) >= 5, f"Expected 5 seeded nurses, got {len(nurses)}"

    sarah = next(n for n in nurses if "Sarah Jenkins" in n["full_name"])
    print(f"Sarah Jenkins initial status: {sarah['duty_status']}")

    print("\n2. Assigning Nurse Sarah Jenkins to Patient Alpha...")
    code, assign_resp = request("POST", f"/nurses/{sarah['id']}/assign", {
        "patient_id": p_a,
        "notes": "Monitor cardiac vitals every 15 mins"
    }, headers=headers_a)
    assert code == 201, f"Nurse assignment failed: {code}"
    print(f"Assignment ID: {assign_resp['id']}, Nurse: {assign_resp['nurse_name']}, Patient: {assign_resp['patient_name']}")

    # Verify Sarah's duty status updated to 'busy'
    _, nurses_after = request("GET", "/nurses", headers=headers_a)
    sarah_after = next(n for n in nurses_after if n["id"] == sarah["id"])
    print(f"Sarah Jenkins updated status: {sarah_after['duty_status']} (Expected: busy)")
    assert sarah_after["duty_status"] == "busy"

    print("\n3. Testing Doctor Isolation on Nurse Assignment...")
    code, cross_assign = request("POST", f"/nurses/{sarah['id']}/assign", {
        "patient_id": p_b, # Doctor B's patient
    }, headers=headers_a)
    print("Cross Doctor Nurse Assignment HTTP Code:", code, "(Expected: 404)")
    assert code == 404

    # ----------------------------------------------------
    # TEST AMBULANCE MODULE
    # ----------------------------------------------------
    print("\n4. Testing Ambulance Fleet List (Shared Resource)...")
    code, units = request("GET", "/ambulance/units", headers=headers_a)
    assert code == 200
    print(f"Seeded Ambulance Units Count: {len(units)}")
    assert len(units) >= 4, f"Expected 4 seeded units, got {len(units)}"

    print("\n5. Testing Single Ambulance Dispatch Auto-Assignment...")
    code, dispatch_1 = request("POST", "/ambulance/dispatch", {
        "patient_id": p_a,
        "pickup_location": "742 Evergreen Terrace"
    }, headers=headers_a)
    assert code == 201
    print(f"Dispatch 1 ID: {dispatch_1['id']}, Unit Code: {dispatch_1['unit_code']}, Status: {dispatch_1['status']}")
    assert dispatch_1["status"] == "dispatched"
    assert dispatch_1["unit_code"] is not None

    print("\n6. Testing Fleet Exhaustion (Dispatching 5 Requests against 4 Units)...")
    # We already dispatched 1 unit above. Let's dispatch 3 more to exhaust the 4 units.
    dispatches = [dispatch_1]
    for i in range(2, 5):
        code, d = request("POST", "/ambulance/dispatch", {
            "patient_id": p_a,
            "pickup_location": f"Emergency Site #{i}"
        }, headers=headers_a)
        assert code == 201
        print(f"Dispatch #{i} Unit Code: {d['unit_code']}, Status: {d['status']}")
        dispatches.append(d)

    # All 4 units should now be en_route
    _, units_after_4 = request("GET", "/ambulance/units", headers=headers_a)
    available_units = [u for u in units_after_4 if u["status"] == "available"]
    print(f"Available Units after 4 dispatches: {len(available_units)} (Expected: 0)")
    assert len(available_units) == 0

    # 5th Dispatch Request (all units busy) -> should succeed cleanly as pending!
    print("\nAttempting 5th Dispatch Request when all units are busy...")
    code, dispatch_5 = request("POST", "/ambulance/dispatch", {
        "patient_id": p_a,
        "pickup_location": "Overcrowded Site #5"
    }, headers=headers_a)
    assert code == 201
    print(f"Dispatch 5 ID: {dispatch_5['id']}, Unit Code: {dispatch_5['unit_code']} (Expected: None), Status: {dispatch_5['status']} (Expected: pending)")
    assert dispatch_5["status"] == "pending"
    assert dispatch_5["unit_code"] is None

    print("\n7. Testing Completion & Unit Re-Availability...")
    # Complete Dispatch #1
    code, complete_resp = request("PATCH", f"/ambulance/dispatch/{dispatches[0]['id']}", {
        "status": "completed"
    }, headers=headers_a)
    assert code == 200
    print(f"Dispatch #1 Status after complete: {complete_resp['status']}")

    # Check that unit is available again
    _, units_reavail = request("GET", "/ambulance/units", headers=headers_a)
    unit_1_after = next(u for u in units_reavail if u["id"] == dispatches[0]["ambulance_id"])
    print(f"Unit {unit_1_after['unit_code']} status after completion: {unit_1_after['status']} (Expected: available)")
    assert unit_1_after["status"] == "available"

    # ----------------------------------------------------
    # TEST CONCURRENT DISPATCH SAFETY WITH ROW LOCKING
    # ----------------------------------------------------
    print("\n8. Testing Concurrent Dispatch Safety (row locking with_for_update)...")
    # First, complete all existing dispatches so units are fresh
    for d in dispatches:
        if d["ambulance_id"]:
            request("PATCH", f"/ambulance/dispatch/{d['id']}", {"status": "completed"}, headers=headers_a)

    def do_concurrent_dispatch(idx):
        code, resp = request("POST", "/ambulance/dispatch", {
            "patient_id": p_a,
            "pickup_location": f"Concurrent Location #{idx}"
        }, headers=headers_a)
        return resp

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(do_concurrent_dispatch, i) for i in range(4)]
        concurrent_results = [f.result() for f in futures]

    assigned_unit_codes = [r["unit_code"] for r in concurrent_results if r.get("unit_code")]
    print("Concurrent Dispatches Assigned Unit Codes:", assigned_unit_codes)
    # Confirm no two dispatches got assigned the same unit code!
    assert len(assigned_unit_codes) == len(set(assigned_unit_codes)), "Race condition! Duplicate unit code assigned!"
    print("[OK] Row locking safely prevented double-assignment of ambulance units!")

    print("\n[OK] ALL PHASE 7 ACCEPTANCE CRITERIA PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    run_test()
