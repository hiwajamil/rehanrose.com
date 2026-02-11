# Firebase Hosting – rehanrose.com

So that **rehanrose.com** shows the app (and not a blank or “nothing” page), do these in the Firebase Console.

## 1. Add custom domain in Hosting

1. Open [Firebase Console → Hosting](https://console.firebase.google.com/project/gull-48040/hosting).
2. Click **Add custom domain**.
3. Enter **rehanrose.com** (and **www.rehanrose.com** if you use www).
4. Follow the steps and add the **A** and **CNAME** records at your domain registrar (Firebase will show the exact values).
5. Wait until the domain shows **Connected**.

## 2. Add domain to Authorized domains (Auth)

1. Open [Firebase Console → Authentication](https://console.firebase.google.com/project/gull-48040/authentication/providers).
2. Go to the **Settings** tab → **Authorized domains**.
3. Click **Add domain** and add:
   - **rehanrose.com**
   - **www.rehanrose.com** (if you use www)

Without this, the app can load but Firebase Auth (and sometimes the app) may fail on rehanrose.com.

## 3. Deploy from this project

From the project root:

```bash
cd gull_premium
flutter build web
./scripts/patch_service_worker.ps1   # avoids Cache API error for 206 responses (e.g. video)
cd ..
firebase deploy
```

On Windows PowerShell: `.\scripts\patch_service_worker.ps1`

After DNS and the steps above are done, **https://rehanrose.com** should show the Rehan Rose app.
