# Google Sign-In ("Continue with Gmail") Setup

Follow these steps so "Continue with Gmail" works in the app.

## 1. Get the Web client ID

1. Open [Firebase Console](https://console.firebase.google.com/) and select project **Rehan Rose** (gull-48040).
2. Go to **Authentication** → **Sign-in method** → **Google**.
3. If Google is not enabled, enable it and set support email.
4. In **Web SDK configuration**, copy the **Web client ID** (looks like `1012920953592-xxxxxxxxxx.apps.googleusercontent.com`).
5. Paste it into **`lib/env/google_client_id.dart`** — replace the empty string:

   ```dart
   const String kGoogleWebClientId = '1012920953592-YOUR_PASTED_ID.apps.googleusercontent.com';
   ```

   **Alternative:** Instead of editing the file, either:
   - Run from terminal: `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com`
   - Or in VS Code/Cursor: use the **"Flutter (with Google Sign-In)"** launch configuration and replace `PASTE_YOUR_WEB_CLIENT_ID` in `.vscode/launch.json` with your full Web client ID.

## 2. Android: Add your SHA-1 in Firebase

For Google Sign-In to work on Android, your app’s SHA-1 must be registered in Firebase.

1. In Firebase Console, go to **Project settings** (gear) → **Your apps**.
2. Select your **Android** app (package name `com.example.rehan_rose`). If it doesn’t exist, add an Android app with this package name.
3. In **SHA certificate fingerprints**, add:
   - **Debug SHA-1:** `71:E9:CC:71:10:3A:B9:CE:42:39:1A:AC:AC:F4:B4:29:69:A7:52:B2`
   - **Debug SHA-256 (optional):** `BD:D6:04:25:62:60:64:F9:F7:0C:A9:21:18:17:85:A7:6D:53:D1:6A:94:FB:F9:D5:2F:5E:A1:A2:70:2F:0D:5A`
4. Save.

To get a new signing report later (e.g. for release):

```bash
cd gull_premium/android
./gradlew signingReport
```

## 3. Web (if you deploy to web)

**If you see "Unable to sign in" or "Assertion failed" on web**, follow **[FIREBASE_WEB_FIX_CHECKLIST.md](FIREBASE_WEB_FIX_CHECKLIST.md)** to add authorized domains in Firebase and Google Cloud.

In **`web/index.html`**, the Google Sign-In meta tag and GSI script are already set. To use a different Web client ID:

```html
<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
```

Use the same Web client ID as in step 1.

## 4. Run the app

After step 1 (and 2 for Android), run the app and try **Continue with Gmail**. It should open the Google account picker and sign in.
