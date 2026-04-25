#!/usr/bin/env python3
"""
Seed the KaraKeep QA demo instance with a user and representative data.

Usage:
    python3 seed.py [--url http://localhost:3000]

Prints credentials and the emulator config command when done.
"""

import argparse
import http.cookiejar
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ── Demo credentials ──────────────────────────────────────────────────────────

EMAIL    = "demo@karakeep.local"
PASSWORD = "Demo1234"
NAME     = "QA Demo"

# ── HTTP helpers ──────────────────────────────────────────────────────────────

jar    = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

_api_key = None


def _request(method, url, data=None, form=False, auth=False):
    body, ct = None, None
    if data is not None:
        if form:
            body = urllib.parse.urlencode(data).encode()
            ct   = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(data).encode()
            ct   = "application/json"

    headers = {}
    if ct:
        headers["Content-Type"] = ct
    if auth and _api_key:
        headers["Authorization"] = f"Bearer {_api_key}"

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with opener.open(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as exc:
        msg = exc.read().decode(errors="replace")
        print(f"  ERROR {exc.code} {method} {url}", file=sys.stderr)
        print(f"  {msg[:300]}", file=sys.stderr)
        raise


def trpc(endpoint, payload):
    return _request("POST", f"{BASE}/api/trpc/{endpoint}", data={"json": payload})


def trpc_query(endpoint, payload=None):
    """tRPC query procedures use GET with input as a URL-encoded JSON param."""
    input_json = urllib.parse.quote(json.dumps({"json": payload or {}}))
    return _request("GET", f"{BASE}/api/trpc/{endpoint}?input={input_json}")


def rest(method, path, data=None):
    return _request(method, f"{BASE}/api/v1/{path}", data=data, auth=True)


# ── Setup steps ───────────────────────────────────────────────────────────────

def wait_for_service():
    print("Waiting for Karakeep to be ready...")
    for attempt in range(40):
        try:
            urllib.request.urlopen(f"{BASE}/api/health", timeout=3)
            print("  Service is ready.")
            return
        except Exception:
            time.sleep(3)
    print("ERROR: Service did not become ready. Is it running?", file=sys.stderr)
    sys.exit(1)


def create_user():
    print(f"Creating user {EMAIL} ...")
    try:
        result = trpc("users.create", {
            "name": NAME, "email": EMAIL,
            "password": PASSWORD, "confirmPassword": PASSWORD,
        })
        role = result["result"]["data"]["json"]["role"]
        print(f"  Created ({role}).")
    except urllib.error.HTTPError as exc:
        if exc.code == 409 or "already" in str(exc.read()).lower():
            print("  User already exists, continuing.")
        else:
            print("  User creation failed — will try to sign in anyway.")


def login():
    print("Signing in...")
    csrf_data = json.loads(
        opener.open(f"{BASE}/api/auth/csrf").read()
    )
    csrf = csrf_data["csrfToken"]

    _request("POST", f"{BASE}/api/auth/callback/credentials", data={
        "email":       EMAIL,
        "password":    PASSWORD,
        "csrfToken":   csrf,
        "callbackUrl": f"{BASE}/",
        "json":        "true",
    }, form=True)
    print("  Signed in.")


def create_api_key():
    global _api_key
    print("Creating API key...")

    # Revoke any existing key with the same name so re-runs don't hit the
    # unique-constraint 500 error.
    try:
        existing = trpc_query("apiKeys.list")
        keys = existing["result"]["data"]["json"]["keys"]
        for k in keys:
            if k["name"] == "qa-demo-key":
                trpc("apiKeys.revoke", {"id": k["id"]})
                print("  Revoked existing qa-demo-key.")
                break
    except Exception:
        pass  # non-fatal; create attempt below will surface any real error

    result = trpc("apiKeys.create", {"name": "qa-demo-key"})
    _api_key = result["result"]["data"]["json"]["key"]
    print("  API key created.")


# ── Data seeding ──────────────────────────────────────────────────────────────

def create_list(name, icon, list_type="manual", query=None):
    payload = {"name": name, "icon": icon}
    if list_type == "smart":
        payload["type"]  = "smart"
        payload["query"] = query
    return rest("POST", "lists", payload)["id"]


def create_bookmark(btype, title, tags, **kwargs):
    payload = {"type": btype, "title": title,
               "tags": [{"name": t} for t in tags], **kwargs}
    return rest("POST", "bookmarks", payload)["id"]


def assign(list_id, bookmark_id):
    rest("PUT", f"lists/{list_id}/bookmarks/{bookmark_id}")


def patch(bookmark_id, **kwargs):
    rest("PATCH", f"bookmarks/{bookmark_id}", kwargs)


def seed():
    print("Creating lists...")
    l_tech   = create_list("Tech Articles",      "🖥️")
    l_read   = create_list("Reading List",        "📚")
    l_sfos   = create_list("SailfishOS",          "⛵")
    l_travel = create_list("Travel",              "✈️")
    create_list("Linux & Open Source", "🐧",
                list_type="smart", query="#linux OR #selfhosted")
    print("  5 lists created (4 manual, 1 smart).")

    print("Creating bookmarks...")
    b_haskell  = create_bookmark("link", "Haskell Language",
                                 ["programming", "functional"],
                                 url="https://haskell.org")
    b_rust     = create_bookmark("link", "The Rust Programming Language",
                                 ["programming", "systems"],
                                 url="https://www.rust-lang.org")
    b_qt       = create_bookmark("link", "Qt 5 Documentation",
                                 ["qt", "programming"],
                                 url="https://doc.qt.io/qt-5")
    b_sfos_dev = create_bookmark("link", "SailfishOS Developer Portal",
                                 ["sailfishos", "mobile"],
                                 url="https://sailfishos.org/develop")
    b_karakeep = create_bookmark("link", "Karakeep — Self-hosted Bookmarks",
                                 ["selfhosted", "tools"],
                                 url="https://github.com/karakeep-app/karakeep")
    b_arch     = create_bookmark("link", "Arch Linux",
                                 ["linux", "sysadmin"],
                                 url="https://archlinux.org")
    b_podman   = create_bookmark("link", "Podman — Daemonless Containers",
                                 ["containers", "linux"],
                                 url="https://podman.io")
    b_oreilly  = create_bookmark("link", "O'Reilly — Technology Books",
                                 ["books", "learning"],
                                 url="https://www.oreilly.com")
    b_lobsters = create_bookmark("link", "Lobsters — Tech Link Aggregator",
                                 ["tech", "community"],
                                 url="https://lobste.rs")
    b_lwn      = create_bookmark("link", "LWN.net — Linux Weekly News",
                                 ["linux", "news"],
                                 url="https://lwn.net")
    b_harbour  = create_bookmark("link", "Jolla Harbour Store",
                                 ["sailfishos", "store"],
                                 url="https://harbour.jolla.com")
    b_sfos_doc = create_bookmark("link", "SailfishOS Documentation",
                                 ["sailfishos", "docs"],
                                 url="https://docs.sailfishos.org")
    b_lp       = create_bookmark("link", "Lonely Planet",
                                 ["travel", "guides"],
                                 url="https://www.lonelyplanet.com")
    b_server   = create_bookmark("text", "Home Server Setup Notes",
                                 ["homelab", "selfhosted"],
                                 text=("Set up a Raspberry Pi with Nextcloud, Karakeep, "
                                       "and Vaultwarden. All behind Caddy reverse proxy "
                                       "on port 443. Open firewall ports 80 and 443."))
    b_trip     = create_bookmark("text", "Europe Trip Planning",
                                 ["travel", "todo"],
                                 text=("- Train connections Vienna to Salzburg\n"
                                       "- Book hostel in Innsbruck\n"
                                       "- Museum pass for Prague"))
    print("  15 bookmarks created.")

    print("Assigning bookmarks to lists...")
    for b in [b_haskell, b_rust, b_qt, b_karakeep, b_arch, b_podman]:
        assign(l_tech, b)
    for b in [b_oreilly, b_lobsters, b_lwn, b_server]:
        assign(l_read, b)
    for b in [b_sfos_dev, b_harbour, b_sfos_doc]:
        assign(l_sfos, b)
    for b in [b_trip, b_lp]:
        assign(l_travel, b)
    print("  Done.")

    print("Setting favourites and archived items...")
    for b in [b_qt, b_karakeep, b_sfos_doc]:
        patch(b, favourited=True)
    for b in [b_arch, b_oreilly]:
        patch(b, archived=True)
    print("  Done.")


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    global BASE

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", default="http://localhost:3000",
                        help="Base URL of the Karakeep instance (default: http://localhost:3000)")
    args = parser.parse_args()
    BASE = args.url.rstrip("/")

    wait_for_service()
    create_user()
    login()
    create_api_key()
    seed()

    emulator_cmd = (
        f"mkdir -p /home/defaultuser/.config/harbour-karakeep && "
        f"printf '[connection]\\\\nserverUrl=http://10.0.2.2:3000\\\\napiKey={_api_key}\\\\n' "
        f"> /home/defaultuser/.config/harbour-karakeep/harbour-karakeep.conf"
    )

    print()
    print("━" * 60)
    print("  Demo environment ready")
    print("━" * 60)
    print(f"  Web UI:   {BASE}")
    print(f"  Username: {EMAIL}")
    print(f"  Password: {PASSWORD}")
    print()
    print("  Emulator config — run via SSH as root:")
    print(f"  {emulator_cmd}")
    print("━" * 60)


if __name__ == "__main__":
    main()
