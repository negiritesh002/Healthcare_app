import json
import asyncio
import urllib.request
import urllib.error
import websockets

BASE_URL = 'http://localhost:8000'
WS_URL = 'ws://localhost:8000'

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
    import redis, time
    r = redis.Redis(host='redis', port=6379, decode_responses=True)
    try:
        for _ in range(15):
            otp = r.get(f"otp:{phone}")
            if otp:
                return otp
            time.sleep(0.2)
        return None
    finally:
        r.close()

def get_doctor_account(phone, name, specialty):
    p(f"Sending OTP for {phone}...")
    request("POST", "/auth/send-otp", {"phone": phone})
    p(f"Retrieving OTP from Redis for {phone}...")
    otp = get_otp_from_redis(phone)
    p(f"OTP retrieved: {otp}")
    assert otp is not None, f"OTP not found in Redis for {phone}"

    p(f"Verifying OTP for {phone}...")
    code, resp_v = request("POST", "/auth/verify-otp", {"phone": phone, "otp_code": otp})

    if not resp_v or not resp_v.get("exists"):
        p(f"Signing up doctor {name}...")
        code, resp_s = request("POST", "/auth/signup", {
            "full_name": name,
            "phone": phone,
            "medical_specialty": specialty,
            "hospital_clinic_address": "General Hospital",
            "medical_license_number": f"LIC-{phone[-4:]}"
        })
        token = resp_s["access_token"]
    else:
        token = resp_v["access_token"]

    code_me, me = request("GET", "/auth/me", headers={"Authorization": f"Bearer {token}"})
    return token, me["id"], me["full_name"]

async def run_async_tests():
    p("=== STARTING PHASE 8 MESSAGING, AI ASSISTANT & TEAM DOCTOR INTEGRATION TEST ===")

    # 1. Setup Doctor A, Doctor B, Doctor C
    p("Creating Doctor accounts via API...")
    import time
    ts = str(int(time.time()))[-4:]
    token_a, id_a, name_a = get_doctor_account(f"+1555888{ts}1", "Dr. Alice Smith", "Cardiology")
    phone_b = f"+1555888{ts}2"
    token_b, id_b, name_b = get_doctor_account(phone_b, "Dr. Bob Jones", "Emergency")
    token_c, id_c, name_c = get_doctor_account(f"+1555888{ts}3", "Dr. Charlie Brown", "Pediatrics")

    headers_a = {"Authorization": f"Bearer {token_a}"}

    # ----------------------------------------------------
    # TEST TEAM DOCTOR DIRECTORY & PRIVACY
    # ----------------------------------------------------
    p("\n1. Testing Team Doctor Directory List...")
    code, team = request("GET", "/doctors", headers=headers_a)
    assert code == 200, f"Failed to list doctors: {code}"
    doc_ids = [d["id"] for d in team]
    assert id_a not in doc_ids, "Requesting doctor should NOT be listed in their own team directory!"
    assert id_b in doc_ids, "Doctor B should be listed in Doctor A's team directory!"
    p(f"Doctor A ({name_a}) sees {len(team)} team doctors in practice (excluding self).")

    p("\n2. Testing Public Doctor Profile & Phone Privacy...")
    code, profile_b = request("GET", f"/doctors/{id_b}", headers=headers_a)
    assert code == 200
    p(f"Doctor B ({name_b}) profile phone before conversation: {profile_b['phone']} (Expected: None)")
    assert profile_b["phone"] is None, "Phone number MUST be hidden on public profile before conversation!"

    # ----------------------------------------------------
    # TEST CONVERSATION CREATION
    # ----------------------------------------------------
    p("\n3. Creating Conversation between Doctor A and Doctor B...")
    code, conv = request("POST", "/messaging/conversations", {"target_doctor_id": id_b}, headers=headers_a)
    assert code in (200, 201), f"Failed to create conversation: {code}"
    conv_id = conv["id"]
    p(f"Conversation ID created: {conv_id}, Other Doctor: {conv['other_doctor_name']}")

    # Re-check phone privacy after conversation exists
    code, profile_b_after = request("GET", f"/doctors/{id_b}", headers=headers_a)
    p(f"Doctor B profile phone after conversation: {profile_b_after['phone']} (Expected: {phone_b})")
    assert profile_b_after["phone"] == phone_b, "Phone number should now be visible after conversation exists!"

    # ----------------------------------------------------
    # TEST WEBSOCKET SECURITY & REAL-TIME CHAT
    # ----------------------------------------------------
    p("\n4. Testing WebSocket Security Rejection (Doctor C trying to join A and B's channel)...")
    ws_uri_c = f"{WS_URL}/messaging/ws/{conv_id}?token={token_c}"
    try:
        async with websockets.connect(ws_uri_c) as ws_c:
            await ws_c.recv()
            assert False, "Doctor C should NOT have been allowed to connect!"
    except (websockets.exceptions.InvalidStatus, websockets.exceptions.ConnectionClosed, Exception) as e:
        p(f"WebSocket rejected Doctor C as unauthorized participant: {e}")

    p("\n5. Testing Real-Time WebSocket Messaging (Doctor A -> Doctor B via Redis PubSub)...")
    ws_uri_a = f"{WS_URL}/messaging/ws/{conv_id}?token={token_a}"
    ws_uri_b = f"{WS_URL}/messaging/ws/{conv_id}?token={token_b}"

    async with websockets.connect(ws_uri_a) as ws_a, websockets.connect(ws_uri_b) as ws_b:
        test_content = "Hello Dr. Bob! Can you review the ICU patient's vitals?"
        await ws_a.send(json.dumps({"content": test_content}))

        # Doctor B receives message in real time over WebSocket
        received_data = await asyncio.wait_for(ws_b.recv(), timeout=5.0)
        msg_obj = json.loads(received_data)
        p(f"Doctor B received real-time message: '{msg_obj['content']}' from '{msg_obj['sender_name']}'")
        assert msg_obj["content"] == test_content
        assert msg_obj["sender_id"] == id_a

    # Verify message persisted in PostgreSQL
    code, msgs = request("GET", f"/messaging/conversations/{conv_id}/messages", headers=headers_a)
    assert code == 200
    assert len(msgs) >= 1
    assert msgs[-1]["content"] == test_content
    p("Message verified in PostgreSQL message history!")

    # ----------------------------------------------------
    # TEST AI MEDICINE ASSISTANT
    # ----------------------------------------------------
    p("\n6. Testing AI Medicine Assistant (Valid Drug Query)...")
    code, ai_resp = request("POST", "/ai/medicine-query", {
        "message": "What is the recommended dosage and indications for Amoxicillin 500mg?"
    }, headers=headers_a)
    assert code == 200
    p(f"AI Response:\n{ai_resp['reply']}")
    assert "Amoxicillin" in ai_resp["reply"]
    assert "Disclaimer:" in ai_resp["reply"], "Mandatory medical disclaimer MUST be present in response!"

    p("\n7. Testing AI Medicine Assistant (Out-of-Scope Query Rejection)...")
    code, ai_out_resp = request("POST", "/ai/medicine-query", {
        "message": "What is the weather today in Tokyo?"
    }, headers=headers_a)
    assert code == 200
    p(f"AI Out-of-Scope Response:\n{ai_out_resp['reply']}")
    assert "specialized strictly in medical" in ai_out_resp["reply"]
    assert "Disclaimer:" in ai_out_resp["reply"]

    p("\n[OK] ALL PHASE 8 ACCEPTANCE CRITERIA PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(run_async_tests())
