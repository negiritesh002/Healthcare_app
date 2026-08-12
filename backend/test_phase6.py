import json
import subprocess
import urllib.request
import urllib.error

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

    if not resp_v.get("exists"):
        code, resp_s = request("POST", "/auth/signup", {
            "full_name": name,
            "phone": phone,
            "medical_specialty": specialty,
            "hospital_clinic_address": "Main Clinic",
            "medical_license_number": "LIC-9999"
        })
        return resp_s["access_token"]
    return resp_v["access_token"]

def run_test():
    print("=== STARTING PHASE 6 INTEGRATION & LAB/PHARMACY ACCEPTANCE TEST ===")

    # Doctor A & Doctor B Tokens
    token_a = get_doctor_token("+15556667777", "Dr. Frankenstein", "Pathology")
    headers_a = {"Authorization": f"Bearer {token_a}"}

    token_b = get_doctor_token("+15558889999", "Dr. Jekyll", "Pharmacology")
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Create Patients
    _, p_a_json = request("POST", "/patients", {
        "full_name": "Lab Patient Alpha",
        "date_of_birth": "1990-05-15",
        "gender": "male",
        "phone": "+15550001111",
        "chief_complaint": "Blood check",
        "severity": "low"
    }, headers=headers_a)
    p_a = p_a_json["id"]

    _, p_b_json = request("POST", "/patients", {
        "full_name": "Lab Patient Beta",
        "date_of_birth": "1992-08-20",
        "gender": "female",
        "phone": "+15550002222",
        "chief_complaint": "Allergy",
        "severity": "low"
    }, headers=headers_b)
    p_b = p_b_json["id"]

    # 1. Lab Order
    print("\n1. Testing Lab Order Creation...")
    code, lab_order = request("POST", "/lab/orders", {
        "patient_id": p_a,
        "test_type": "Complete Blood Count",
        "notes": "Fast for 12 hours"
    }, headers=headers_a)
    assert code == 201, f"Lab order creation failed with code {code}"
    print("Created Lab Order ID:", lab_order["id"])

    print("\n2. Patching Lab Order Status...")
    code, patch_lab = request("PATCH", f"/lab/orders/{lab_order['id']}", {
        "status": "completed",
        "result_notes": "Normal CBC"
    }, headers=headers_a)
    assert code == 200
    print("Patched Lab Order Status:", patch_lab["status"], "-", patch_lab["result_notes"])

    print("\n3. Testing Doctor Isolation on Lab Orders...")
    code, cross_lab = request("POST", "/lab/orders", {
        "patient_id": p_b,
        "test_type": "Lipid Profile"
    }, headers=headers_a)
    print("Cross Doctor Lab HTTP Status Code:", code, "(Expected: 404)")
    assert code == 404

    # 2. Pharmacy
    print("\n4. Testing Pharmacy Seed Data...")
    code, meds = request("GET", "/pharmacy/medicines", headers=headers_a)
    assert code == 200
    print("Seeded Medicines Count:", len(meds))
    assert len(meds) >= 8

    amox = next(m for m in meds if "Amoxicillin" in m["name"])
    metf = next(m for m in meds if "Metformin" in m["name"])
    initial_amox_stock = amox["stock_qty"]
    initial_metf_stock = metf["stock_qty"]
    print("Amoxicillin initial stock:", initial_amox_stock)
    print("Metformin initial stock:", initial_metf_stock)

    print("\n5. Creating Multi-Item Prescription...")
    code, presc = request("POST", "/pharmacy/prescriptions", {
        "patient_id": p_a,
        "items": [
            {"medicine_id": amox["id"], "quantity": 5},
            {"medicine_id": metf["id"], "quantity": 10}
        ]
    }, headers=headers_a)
    assert code == 201
    print("Created Prescription ID:", presc["id"])

    print("\n6. Dispensing Prescription & Checking Stock Decrement...")
    code, dispense = request("PATCH", f"/pharmacy/prescriptions/{presc['id']}", {
        "status": "dispensed"
    }, headers=headers_a)
    assert code == 200
    print("Dispensed Prescription Status:", dispense["status"])

    _, meds_after = request("GET", "/pharmacy/medicines", headers=headers_a)
    amox_after = next(m for m in meds_after if m["id"] == amox["id"])
    metf_after = next(m for m in meds_after if m["id"] == metf["id"])
    print(f"Amox stock after dispense: {amox_after['stock_qty']} (Expected: {initial_amox_stock - 5})")
    print(f"Metf stock after dispense: {metf_after['stock_qty']} (Expected: {initial_metf_stock - 10})")

    assert amox_after["stock_qty"] == initial_amox_stock - 5
    assert metf_after["stock_qty"] == initial_metf_stock - 10

    # 3. Excess stock test
    print("\n7. Testing Excess Stock Rejection...")
    code, excess_presc = request("POST", "/pharmacy/prescriptions", {
        "patient_id": p_a,
        "items": [
            {"medicine_id": amox["id"], "quantity": 9999}
        ]
    }, headers=headers_a)

    code_excess, excess_dispense = request("PATCH", f"/pharmacy/prescriptions/{excess_presc['id']}", {
        "status": "dispensed"
    }, headers=headers_a)
    print("Excess Dispense HTTP Status Code:", code_excess, "(Expected: 400)")
    print("Excess Dispense Error Detail:", excess_dispense.get("detail"))
    assert code_excess == 400

    print("\n[OK] ALL PHASE 6 ACCEPTANCE CRITERIA PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    run_test()
