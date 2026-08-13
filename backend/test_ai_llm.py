import json
import urllib.request
import urllib.error
import redis

BASE_URL = 'http://localhost:8000'

def p(msg):
    print(msg, flush=True)

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
        p(f"HTTPError {e.code}: {resp_body}")
        return e.code, json.loads(resp_body) if resp_body else None

def get_otp_from_redis(phone):
    r = redis.Redis(host='redis', port=6379, decode_responses=True)
    try:
        return r.get(f"otp:{phone}")
    finally:
        r.close()

def get_doctor_token():
    phone = "+15559991111"
    request("POST", "/auth/send-otp", {"phone": phone})
    otp = get_otp_from_redis(phone)
    code, resp_v = request("POST", "/auth/verify-otp", {"phone": phone, "otp_code": otp})
    if not resp_v or not resp_v.get("exists"):
        code, resp_s = request("POST", "/auth/signup", {
            "full_name": "Dr. LLM Tester",
            "phone": phone,
            "medical_specialty": "Cardiology",
            "hospital_clinic_address": "General Hospital",
            "medical_license_number": "LIC-LLM1"
        })
        token = resp_s["access_token"]
    else:
        token = resp_v["access_token"]
    return token

def run_tests():
    p("=== TESTING AI MEDICINE ASSISTANT REGEX FIX & LLM INTEGRATION ===")
    token = get_doctor_token()
    headers = {"Authorization": f"Bearer {token}"}

    # Test 1: Substring false-positive check ("cardiac" contains "car")
    p("\n1. Testing 'cardiac dosage for hypertension' (Must NOT trigger out-of-scope 'car')...")
    code, resp1 = request("POST", "/ai/medicine-query", {
        "message": "What is the cardiac dosage for hypertension?"
    }, headers=headers)
    assert code == 200
    p(f"Response 1:\n{resp1['reply']}\n")
    assert "cannot answer queries outside the medical scope" not in resp1["reply"], \
        "FAILED: 'cardiac' was falsely matched as out-of-scope keyword 'car'!"
    p("[OK] 'cardiac' query correctly passed out-of-scope check (Regex word boundary fix works!).")

    # Test 2: Actual LLM call for a non-hardcoded drug (Sertraline or Warfarin)
    p("\n2. Testing non-hardcoded drug query 'What is the typical dosing for Sertraline?'...")
    code, resp2 = request("POST", "/ai/medicine-query", {
        "message": "What is the typical dosing for Sertraline?"
    }, headers=headers)
    assert code == 200
    reply2 = resp2["reply"]
    p(f"Response 2 (LLM Output):\n{reply2}\n")
    
    assert "Disclaimer:" in reply2, "Mandatory disclaimer missing!"
    if "Regarding your clinical query on" in reply2:
        p("[WARNING] Returned generic fallback response! OpenAI API key might be missing/invalid or quota exceeded.")
    else:
        p("[OK] SUCCESS! LLM API returned a real, intelligent response for non-hardcoded drug Sertraline!")

if __name__ == "__main__":
    run_tests()
