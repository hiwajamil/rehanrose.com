#!/usr/bin/env python3
"""
Automate adding Firebase authorized domains and Google Cloud OAuth origins
so Google Sign-In works on web (localhost and production).

Requirements:
  pip install playwright
  playwright install chromium
  (On Windows if 'pip' not in PATH: python -m pip install playwright)

Usage:
  cd gull_premium/scripts
  python firebase_web_fix.py

You will be prompted to log in to Firebase and Google Cloud in the browser
if not already logged in. The script then adds:
  - Firebase Auth: authorized domain "localhost"
  - Google Cloud: authorized JavaScript origins for localhost and production
"""

import sys
import time

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Install Playwright: pip install playwright")
    print("Then: playwright install chromium")
    sys.exit(1)

# Your project IDs and values (from gull_premium)
FIREBASE_PROJECT_ID = "gull-48040"
WEB_CLIENT_ID = "1012920953592-q4g5b7u1a6bq1alj8ugi3fbmnpufjbab.apps.googleusercontent.com"
ORIGINS_TO_ADD = [
    "http://localhost:5000",
    "http://localhost:8080",
    "http://127.0.0.1:5000",
    "https://rehanrose.com",
]
REDIRECT_URI = "https://gull-48040.firebaseapp.com/__/auth/handler"

FIREBASE_AUTH_SETTINGS_URL = (
    f"https://console.firebase.google.com/project/{FIREBASE_PROJECT_ID}/authentication/settings"
)
GCP_CREDENTIALS_URL = (
    f"https://console.cloud.google.com/apis/credentials?project={FIREBASE_PROJECT_ID}"
)


def open_pages_and_guide(context):
    """Open Firebase and Google Cloud pages; guide user to add settings."""
    page = context.new_page()
    page.goto(FIREBASE_AUTH_SETTINGS_URL, wait_until="domcontentloaded", timeout=60000)
    print("\n[1] Opened Firebase Authentication settings.")
    print("    If you're not logged in, sign in now in the browser.")
    print("    Then add 'localhost' under Authorized domains if it's missing:")
    print("    → Click 'Add domain' → type localhost → Save.\n")
    input("    Press Enter here when done (or to skip)... ")

    page.goto(GCP_CREDENTIALS_URL, wait_until="domcontentloaded", timeout=60000)
    print("\n[2] Opened Google Cloud Credentials.")
    print("    Click your 'Web client' (OAuth 2.0 Client IDs).")
    print("    Under 'Authorized JavaScript origins' add (if missing):")
    for o in ORIGINS_TO_ADD:
        print(f"      - {o}")
    print("    Under 'Authorized redirect URIs' add (if missing):")
    print(f"      - {REDIRECT_URI}")
    print("    Click Save.\n")
    input("    Press Enter here when done... ")

    page.close()


def try_automate_firebase_domain(context):
    """Try to add 'localhost' to Firebase authorized domains."""
    page = context.new_page()
    page.goto(FIREBASE_AUTH_SETTINGS_URL, wait_until="networkidle", timeout=60000)
    time.sleep(2)

    # Look for "Add domain" or similar button
    add_btn = page.get_by_role("button", name="Add domain")
    if add_btn.count == 0:
        add_btn = page.locator('button:has-text("Add domain")')
    if add_btn.count == 0:
        add_btn = page.get_by_text("Add domain")

    if add_btn.count > 0:
        add_btn.first.click()
        time.sleep(1)
        # Often an input appears for the domain name
        inp = page.locator('input[type="text"], input[placeholder*="domain"], input[name*="domain"]')
        if inp.count > 0:
            inp.first.fill("localhost")
            time.sleep(0.5)
            page.keyboard.press("Enter")
            time.sleep(1)
            print("[Firebase] Added domain 'localhost'.")
        else:
            print("[Firebase] Add-domain dialog opened; please type 'localhost' and Save in the browser.")
    else:
        print("[Firebase] Could not find 'Add domain' button; add 'localhost' manually on the opened page.")

    page.close()


def try_automate_gcp_origins(context):
    """Try to open OAuth client edit and add origins."""
    page = context.new_page()
    page.goto(GCP_CREDENTIALS_URL, wait_until="networkidle", timeout=60000)
    time.sleep(2)

    # Click the Web client row (often contains the client ID or "Web client")
    try:
        row = page.locator('tr:has-text("Web client"), tr:has-text("1012920953592")')
        if row.count > 0:
            row.first.click()
            time.sleep(2)
    except Exception:
        pass

    # Look for "Authorized JavaScript origins" section and "ADD URI"
    add_uri_btn = page.get_by_role("button", name="ADD URI")
    if add_uri_btn.count == 0:
        add_uri_btn = page.locator('button:has-text("ADD URI"), button:has-text("Add URI")')
    if add_uri_btn.count == 0:
        add_uri_btn = page.get_by_text("ADD URI")

    if add_uri_btn.count > 0:
        for origin in ORIGINS_TO_ADD:
            try:
                add_uri_btn.first.click()
                time.sleep(0.8)
                inp = page.locator('input[type="url"], input[placeholder*="URI"], input[aria-label*="origin"]')
                if inp.count > 0:
                    inp.last.fill(origin)
                    time.sleep(0.3)
                add_uri_btn = page.locator('button:has-text("ADD URI"), button:has-text("Add URI")')
            except Exception:
                break
        print("[Google Cloud] Attempted to add JavaScript origins; check the page and Save if needed.")
    else:
        print("[Google Cloud] Open your Web client, add the URIs under Authorized JavaScript origins, then Save.")

    page.close()


def main():
    print("Firebase & Google Cloud – Web Sign-In fix")
    print("==========================================")
    print("This script will open the Firebase and Google Cloud console pages.")
    print("You may need to log in in the browser.\n")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context(viewport={"width": 1280, "height": 900})
        context.set_default_timeout(20000)

        try:
            print("Opening Firebase Console...")
            try_automate_firebase_domain(context)
        except Exception as e:
            print(f"Automation (Firebase) failed: {e}")

        try:
            print("\nOpening Google Cloud Console...")
            try_automate_gcp_origins(context)
        except Exception as e:
            print(f"Automation (GCP) failed: {e}")

        print("\nOpening both console pages so you can add anything missing and Save.")
        open_pages_and_guide(context)

        input("\nPress Enter to close the browser... ")
        context.close()
        browser.close()

    print("\nDone. Run your Flutter web app and try 'Continue with Google' again.")


if __name__ == "__main__":
    main()
