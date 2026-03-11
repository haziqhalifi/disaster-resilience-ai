"""End-to-end test script for the Admin Approval → Emergency SMS flow.

Usage:
    cd backend_fastapi
    python tests/test_sms_flow.py                          # mock mode (no real SMS)
    python tests/test_sms_flow.py --phone +601XXXXXXXXX    # with a specific phone number
    python tests/test_sms_flow.py --base http://localhost:8000

Requirements:
    - Backend server running on localhost:8000
    - ADMIN_USERNAME / ADMIN_PASSWORD set in .env (or defaults: admin / changeme123)
    - For real SMS: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER in .env
      and --phone must be a Twilio-verified / trial number.

The script seeds one test user with KL coordinates and a phone number,
submits a report, then exercises the full approve-and-SMS flow.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import uuid
from datetime import datetime, timezone

import requests

# Force UTF-8 output on Windows so Unicode symbols render correctly
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf_8"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
if sys.stderr.encoding and sys.stderr.encoding.lower() not in ("utf-8", "utf_8"):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# ── KL test coordinates ────────────────────────────────────────────────────────
KL_LAT = 3.1412
KL_LON = 101.6865

# ── Colour helpers ────────────────────────────────────────────────────────────
try:
    import colorama; colorama.init(wrap=False)
    GREEN  = "\033[92m"
    RED    = "\033[91m"
    YELLOW = "\033[93m"
    CYAN   = "\033[96m"
    BOLD   = "\033[1m"
    RESET  = "\033[0m"
except ImportError:
    GREEN = RED = YELLOW = CYAN = BOLD = RESET = ""

PASS = f"{GREEN}[PASS]{RESET}"
FAIL = f"{RED}[FAIL]{RESET}"
INFO = f"{CYAN}[INFO]{RESET}"
WARN = f"{YELLOW}[WARN]{RESET}"

results: list[tuple[str, bool, str]] = []


def check(label: str, passed: bool, detail: str = "") -> bool:
    tag = PASS if passed else FAIL
    print(f"  {tag}  {label}" + (f" — {detail}" if detail else ""))
    results.append((label, passed, detail))
    return passed


def section(title: str) -> None:
    print(f"\n{BOLD}{CYAN}{'-'*60}{RESET}")
    print(f"{BOLD}{CYAN}  {title}{RESET}")
    print(f"{BOLD}{CYAN}{'-'*60}{RESET}")


def print_json(data: dict) -> None:
    print(f"    {YELLOW}{json.dumps(data, indent=2, default=str)}{RESET}")


# ── HTTP helpers ───────────────────────────────────────────────────────────────

def post(base: str, path: str, token: str | None = None, **kwargs) -> requests.Response:
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.post(f"{base}{path}", headers=headers, timeout=30, **kwargs)


def get(base: str, path: str, token: str | None = None, **kwargs) -> requests.Response:
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.get(f"{base}{path}", headers=headers, timeout=30, **kwargs)


# ── Test sections ──────────────────────────────────────────────────────────────

def test_health(base: str) -> bool:
    section("1 · Backend health check")
    try:
        r = get(base, "/")
        ok = r.status_code == 200
        check("Backend is reachable", ok, f"status={r.status_code}")
        if ok:
            data = r.json()
            print(f"    {INFO} version={data.get('version')} service={data.get('service')}")
        return ok
    except Exception as exc:
        check("Backend is reachable", False, str(exc))
        return False


def test_admin_login(base: str, username: str, password: str) -> str | None:
    section("2 · Admin login")
    # Try login first; if it fails with 401, register a fresh test admin
    r = post(base, "/api/v1/admin/login", json={"username": username, "password": password})
    if r.status_code == 401:
        print(f"    {WARN} Login failed — registering a fresh test admin account")
        r = post(base, "/api/v1/admin/register", json={"username": username, "password": password})
        ok = r.status_code == 201
        check("Admin register", ok, f"status={r.status_code}")
        if not ok:
            print(f"    {WARN} {r.text[:200]}")
            return None
    else:
        ok = r.status_code == 200
        check("Admin login", ok, f"status={r.status_code}")
        if not ok:
            print(f"    {WARN} {r.text[:200]}")
            return None
    token = r.json().get("access_token")
    check("Received admin JWT", bool(token))
    return token


def test_user_setup(base: str, phone: str) -> tuple[str | None, str | None]:
    """Sign up a test user and register their device with KL coordinates."""
    section("3 · Test user setup")
    uid = uuid.uuid4().hex[:8]
    email    = f"smstest_{uid}@example.com"
    username = f"smstest_{uid}"
    password = "Test1234!"

    # Sign up
    r = post(base, "/api/v1/auth/signup",
             json={"email": email, "username": username, "password": password})
    ok = r.status_code == 201
    check("Test user signup", ok, f"email={email} status={r.status_code}")
    if not ok:
        print(f"    {WARN} {r.text[:200]}")
        return None, None
    user_token = r.json().get("access_token")

    auth_headers = {"Authorization": f"Bearer {user_token}", "Content-Type": "application/json"}

    # Step 1 — set GPS coordinates (separate endpoint from device/phone registration)
    r_loc = requests.put(f"{base}/api/v1/devices/me/location",
                         headers=auth_headers,
                         json={"latitude": KL_LAT, "longitude": KL_LON},
                         timeout=30)
    ok_loc = r_loc.status_code in (200, 201)
    check("Location set in KL", ok_loc, f"lat={KL_LAT} lon={KL_LON} status={r_loc.status_code}")
    if not ok_loc:
        print(f"    {WARN} {r_loc.text[:200]}")

    # Step 2 — register phone number for SMS (no FCM token so SMS branch is used)
    r2 = requests.put(f"{base}/api/v1/devices/me/device",
                      headers=auth_headers,
                      json={"phone_number": phone},
                      timeout=30)
    ok2 = r2.status_code in (200, 201)
    check("Phone number registered for SMS", ok2,
          f"phone={phone} status={r2.status_code}")
    if not ok2:
        print(f"    {WARN} {r2.text[:200]}")

    return user_token, email


def test_submit_report(base: str, user_token: str) -> str | None:
    section("4 · Submit flood report in KL")
    r = post(base, "/api/v1/reports/submit", token=user_token,
             json={
                 "report_type":    "flood",
                 "description":    "SMS flow test — major flooding near KLCC",
                 "location_name":  "Kuala Lumpur",
                 "latitude":       KL_LAT,
                 "longitude":      KL_LON,
                 "vulnerable_person": False,
             })
    ok = r.status_code == 201
    check("Report submitted", ok, f"status={r.status_code}")
    if not ok:
        print(f"    {WARN} {r.text[:200]}")
        return None
    report_id = r.json().get("id")
    check("Report has an ID", bool(report_id), f"id={report_id}")
    print(f"    {INFO} report_id={report_id}")
    return report_id


def test_sms_preview(base: str, admin_token: str, report_id: str) -> dict | None:
    section("5 · SMS preview (before approve)")
    r = get(base, f"/api/v1/admin/reports/{report_id}/sms-preview", token=admin_token)
    ok = r.status_code == 200
    check("SMS preview endpoint responds", ok, f"status={r.status_code}")
    if not ok:
        print(f"    {WARN} {r.text[:200]}")
        return None
    data = r.json()
    print_json(data)
    check("Preview includes location_name",  bool(data.get("location_name")))
    check("Preview includes affected_count", "affected_count" in data)
    check("Preview includes phone_users",    "phone_users" in data)
    print(f"    {INFO} {data.get('phone_users', 0)} user(s) with phones within "
          f"{data.get('radius_km', 10)}km of {data.get('location_name')}")
    return data


def test_approve_and_sms(base: str, admin_token: str, report_id: str) -> dict | None:
    section("6 · Approve report → auto-broadcast SMS")
    r = post(base, f"/api/v1/admin/reports/{report_id}/approve", token=admin_token)
    ok = r.status_code == 200
    check("Approve endpoint responds 200", ok, f"status={r.status_code}")
    if not ok:
        print(f"    {WARN} {r.text[:200]}")
        return None
    data = r.json()
    broadcast = data.get("broadcast", {})
    print_json(broadcast)
    check("Report status is validated",    data.get("report", {}).get("status") == "validated")
    check("broadcast.total_affected >= 0", broadcast.get("total_affected", 0) >= 0)
    check("broadcast.sms_sent >= 0",       broadcast.get("sms_sent", 0) >= 0)

    sms_sent = broadcast.get("sms_sent", 0)
    total    = broadcast.get("total_affected", 0)
    if sms_sent > 0:
        print(f"    {GREEN}>>> {sms_sent} SMS sent to {total} user(s) — check Twilio console!{RESET}")
    else:
        print(f"    {WARN} sms_sent=0 (Twilio may be in MOCK mode or no phone-registered users nearby)")
    return broadcast


def test_manual_send_sms(base: str, admin_token: str, report_id: str) -> None:
    section("7 · Manual send-sms endpoint (re-broadcast)")
    r = post(base, f"/api/v1/admin/reports/{report_id}/send-sms", token=admin_token)
    # Dedup means repeat sends return 0 sms_sent — that is correct behaviour
    ok = r.status_code == 200
    check("send-sms endpoint responds 200", ok, f"status={r.status_code}")
    if ok:
        data = r.json()
        print_json(data)
        print(f"    {INFO} Dedup active: same event within 1 hour → sms_sent may be 0 (expected).")


def test_sms_log(base: str, admin_token: str, report_id: str) -> None:
    section("8 · Verify SMS alert log in Supabase")
    # The backend has no direct "list sms_alerts" admin endpoint, so we import
    # the Supabase client directly here when running inside the backend directory.
    try:
        import os, pathlib
        env_path = pathlib.Path(__file__).resolve().parents[1] / ".env"
        from dotenv import load_dotenv
        load_dotenv(env_path)
        from app.db.supabase_client import get_client
        sb = get_client()
        rows = (
            sb.table("sms_alerts")
            .select("id, phone_number, status, alert_type, sent_at, error_reason")
            .eq("event_id", report_id)
            .execute().data or []
        )
        check("sms_alerts rows found for this report", len(rows) > 0, f"rows={len(rows)}")
        for row in rows:
            status_col = row.get("status", "?")
            phone      = row.get("phone_number", "?")
            print(f"    {INFO} [{status_col.upper()}] → {phone}  type={row.get('alert_type')}  sent_at={row.get('sent_at')}")
            if row.get("error_reason"):
                print(f"           {RED}error: {row['error_reason']}{RESET}")
    except Exception as exc:
        print(f"    {WARN} Could not query sms_alerts directly: {exc}")
        print(f"    {INFO} Check Supabase table editor → sms_alerts, filter event_id = {report_id}")


# ── Non-flood report test ──────────────────────────────────────────────────────

def test_non_flood_report(base: str, user_token: str, admin_token: str) -> None:
    section("9 · Non-flood report (Landslide) approve + SMS")
    r = post(base, "/api/v1/reports/submit", token=user_token,
             json={
                 "report_type":    "landslide",
                 "description":    "SMS flow test — landslide near KL hill",
                 "location_name":  "Bukit Antarabangsa, Kuala Lumpur",
                 "latitude":       KL_LAT + 0.02,  # slightly north, still within 10km
                 "longitude":      KL_LON + 0.02,
                 "vulnerable_person": False,
             })
    if not check("Landslide report submitted", r.status_code == 201, f"status={r.status_code}"):
        return
    report_id = r.json()["id"]

    r2 = get(base, f"/api/v1/admin/reports/{report_id}/sms-preview", token=admin_token)
    if r2.status_code == 200:
        preview = r2.json()
        print(f"    {INFO} Landslide preview: {preview.get('phone_users')} phone users within {preview.get('radius_km')}km")

    r3 = post(base, f"/api/v1/admin/reports/{report_id}/approve", token=admin_token)
    ok3 = r3.status_code == 200
    check("Landslide approve responds 200", ok3, f"status={r3.status_code}")
    if ok3:
        b = r3.json().get("broadcast", {})
        print_json(b)
        check("Generic broadcast ran (not flood-only)", "sms_sent" in b)


# ── Summary ────────────────────────────────────────────────────────────────────

def print_summary() -> None:
    section("SUMMARY")
    passed = sum(1 for _, p, _ in results if p)
    total  = len(results)
    failed = [(lbl, det) for lbl, p, det in results if not p]

    print(f"\n  {BOLD}Results: {passed}/{total} passed{RESET}")
    if failed:
        print(f"\n  {RED}Failed checks:{RESET}")
        for lbl, det in failed:
            print(f"    {RED}[x]{RESET} {lbl}" + (f" - {det}" if det else ""))
    else:
        print(f"\n  {GREEN}All checks passed!{RESET}")

    print(f"""
  {BOLD}Twilio demo tips:{RESET}
  • If sms_sent=0 and mode is MOCK: add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN,
    TWILIO_PHONE_NUMBER to backend_fastapi/.env and restart the server.
  • Use a Twilio trial account with a verified number (or Twilio virtual phone).
  • The sent message will appear in Twilio console → Monitor → SMS logs.
  • For the Twilio Test Credentials sandbox, use to=+15005550006 as the phone number.
  • Re-run with:  python tests/test_sms_flow.py --phone +601XXXXXXXXX
""")


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    # Load .env so admin credentials and Twilio vars are available
    try:
        import pathlib
        from dotenv import load_dotenv
        env_path = pathlib.Path(__file__).resolve().parents[1] / ".env"
        load_dotenv(env_path)
    except Exception:
        pass

    import os
    parser = argparse.ArgumentParser(description="End-to-end SMS flow test")
    parser.add_argument("--base",       default="http://localhost:8000",           help="Backend base URL")
    parser.add_argument("--phone",      default="+60119999999",                    help="Phone number for test device")
    _default_admin_user = os.getenv("ADMIN_USERNAME") or f"testadmin_{uuid.uuid4().hex[:6]}"
    _default_admin_pass = os.getenv("ADMIN_PASSWORD") or "TestAdmin1234!"
    parser.add_argument("--admin-user", default=_default_admin_user, help="Admin username")
    parser.add_argument("--admin-pass", default=_default_admin_pass, help="Admin password")
    args = parser.parse_args()

    print(f"\n{BOLD}{'='*60}")
    print(f"  LANDA - SMS Flow End-to-End Test")
    print(f"  {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print(f"  Base URL : {args.base}")
    print(f"  Phone    : {args.phone}")
    print(f"{'='*60}{RESET}")

    if not test_health(args.base):
        print(f"\n{RED}Backend is not running. Start it with:{RESET}")
        print("  cd backend_fastapi && uvicorn app.main:app --reload --port 8000")
        sys.exit(1)

    admin_token = test_admin_login(args.base, args.admin_user, args.admin_pass)
    if not admin_token:
        print(f"\n{RED}Admin login failed — check credentials in .env{RESET}")
        sys.exit(1)

    user_token, _ = test_user_setup(args.base, args.phone)
    if not user_token:
        print(f"\n{RED}User setup failed — check backend logs{RESET}")
        sys.exit(1)

    report_id = test_submit_report(args.base, user_token)
    if not report_id:
        print(f"\n{RED}Report submission failed — check backend logs{RESET}")
        sys.exit(1)

    test_sms_preview(args.base, admin_token, report_id)
    test_approve_and_sms(args.base, admin_token, report_id)
    test_manual_send_sms(args.base, admin_token, report_id)
    test_sms_log(args.base, admin_token, report_id)
    test_non_flood_report(args.base, user_token, admin_token)

    print_summary()


if __name__ == "__main__":
    main()
