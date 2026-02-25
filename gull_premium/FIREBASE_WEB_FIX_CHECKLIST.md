# Fix "Unable to sign in" / Google Sign-In on Web

The app code and Web client ID are already set. **You must complete these steps in Firebase and Google Cloud** (about 2 minutes). No code changes needed after this.

**Automate with Python (optional):** From `gull_premium/scripts` run:

- **Easiest (Windows PowerShell):** run the launcher (installs deps and runs the script):
  ```powershell
  .\run_firebase_fix.ps1
  ```
- **Or manually** (use `python -m` when `pip` / `playwright` are not in PATH):
  ```powershell
  python -m pip install -r requirements-firebase-fix.txt
  python -m playwright install chromium
  python firebase_web_fix.py
  ```
The script opens the console pages and tries to add the settings for you; if the UI has changed, it will guide you step by step.
R
---

## Step 1: Firebase – Authorized domains

1. Open **[Firebase Console](https://console.firebase.google.com/)** and select project **gull-48040**.
2. Go to **Authentication** → **Settings** (or **Sign-in method** tab) → **Authorized domains**.
3. Ensure these are in the list (add any that are missing):
   - **localhost** (for `http://localhost:PORT` when running `flutter run -d chrome`)
   - Your production domain, e.g. **rehanrose.com**, if you deploy there.
4. Click **Save** if you added anything.

---

## Step 2: Google Cloud – Authorized JavaScript origins (for the Web client)

1. Open **[Google Cloud Console](https://console.cloud.google.com/)** and select the **same project** as Firebase (gull-48040).
2. Go to **APIs & Services** → **Credentials**.
3. Under **OAuth 2.0 Client IDs**, click your **Web client** (the one whose Client ID is `1012920953592-q4g5b7u1a6bq1alj8ugi3fbmnpufjbab.apps.googleusercontent.com`).  
   If you only see "Web client (auto created by Google Service)" or similar, click that.
4. Under **Authorized JavaScript origins**, add (if not already there):
   - `http://localhost:5000`  
   - `http://localhost:8080`  
   - `http://127.0.0.1:5000`  
   - Your live URL when you deploy, e.g. `https://rehanrose.com`
5. Under **Authorized redirect URIs**, Firebase typically needs (add if missing):
   - `https://gull-48040.firebaseapp.com/__/auth/handler`
6. Click **Save**.

---

## Step 3: Test again

1. Restart the app: `flutter run -d chrome` (or your usual run).
2. Open the sign-in screen and tap **Continue with Google**.

If it still fails, check the browser console (F12 → Console) for the exact error and ensure the origin you’re using (e.g. `http://localhost:XXXX`) is in both Firebase authorized domains and Google Cloud authorized JavaScript origins.
