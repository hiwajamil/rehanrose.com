# Environment variables (secrets) setup

The app reads **API keys and secrets** from a local file so they are never committed. Follow these steps on your machine.

---

## 1. Create your local env file

In the **`gull_premium`** folder (same folder as `pubspec.yaml`), create a file named **`env.json`**.

You can copy the example file:

- **Windows (PowerShell):**  
  `Copy-Item env.json.example env.json`
- **macOS/Linux:**  
  `cp env.json.example env.json`

Or create `env.json` manually with this structure:

```json
{
  "PLACES_API_KEY": "",
  "GOOGLE_WEB_CLIENT_ID": "",
  "SUPER_ADMIN_EMAIL": ""
}
```

---

## 2. Fill in the values

Edit **`env.json`** and paste your real values (no quotes inside the value except for the JSON string):

| Key | Where to get it | Required for |
|-----|-----------------|--------------|
| **PLACES_API_KEY** | [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → Create API key (enable Places API) | Map/address autocomplete (mobile). On web the app uses a proxy. |
| **GOOGLE_WEB_CLIENT_ID** | [Firebase Console](https://console.firebase.google.com/) → Your project → Authentication → Sign-in method → Google → **Web client ID** (e.g. `123456789-xxxx.apps.googleusercontent.com`) | “Continue with Google” sign-in |
| **SUPER_ADMIN_EMAIL** | Your own admin email (e.g. `your-admin@gmail.com`) | Bypass for admin access without adding the user to the `admins` collection |

**Example (with placeholder values):**

```json
{
  "PLACES_API_KEY": "AIzaSy...your-google-places-api-key",
  "GOOGLE_WEB_CLIENT_ID": "123456789-xxxxxxxxxx.apps.googleusercontent.com",
  "SUPER_ADMIN_EMAIL": "your-admin@gmail.com"
}
```

Leave a key as `""` if you don’t need that feature (e.g. no Google sign-in or no super admin).

---

## 3. Run the app with the env file

From the **`gull_premium`** folder, run:

```bash
flutter run --dart-define-from-file=env.json
```

For VS Code / Cursor, add to your launch configuration (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (with env)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define-from-file=env.json"
      ]
    }
  ]
}
```

For Android Studio / IntelliJ: Run → Edit Configurations → add `--dart-define-from-file=env.json` to **Additional run args**.

---

## 4. Security

- **`env.json`** is in **`.gitignore`** — do not commit it.
- **`env.json.example`** is committed as a template with empty values.
- For **CI/CD or production**, pass the same keys via your pipeline’s secret store and use `--dart-define=PLACES_API_KEY=...` (and the other keys) or a generated `env.json` that is not committed.

---

## 5. Production build (rehanrose.com)

**`env.json` is only used when you run the app locally.** The site at **rehanrose.com** is built with `flutter build web` and deployed to Firebase Hosting. For the super admin (**hiwa.constructions@gmail.com**) to work on rehanrose.com, you must pass `SUPER_ADMIN_EMAIL` at **build time**.

From the **`gull_premium`** folder, build for production using your env file:

```bash
flutter build web --dart-define-from-file=env.json
```

Then deploy (e.g. `firebase deploy --only hosting`). The built app will have the super admin email baked in, so sign-in at https://rehanrose.com/admin will work for that email.

**If you build without `--dart-define-from-file=env.json`** (or without `--dart-define=SUPER_ADMIN_EMAIL=hiwa.constructions@gmail.com`), the deployed app will have no super admin bypass — only users listed in the Firestore **`admins`** collection will be able to sign in at /admin.

**CI/CD:** Store `SUPER_ADMIN_EMAIL` as a secret in your pipeline and pass it when running `flutter build web`, for example:

```bash
flutter build web --dart-define=SUPER_ADMIN_EMAIL=hiwa.constructions@gmail.com
```

(Use your pipeline’s secret reference instead of the literal email.)

---

## 6. Without env file

If you run without `--dart-define-from-file=env.json`:

- **Google sign-in** and **Places (map) search** may not work until the keys are set.
- **Super admin** bypass will be disabled (only users in the `admins` collection will be treated as admin).

The app will still run; features that need these keys will fail or be disabled.
