# gull_premium

A new Flutter project.

## Firebase Storage (web)

If you see **"HTTP request failed, statusCode: 0"** when publishing bouquets or loading bouquet images on web, the Storage bucket needs CORS. Apply it once using either option below.

### Option A: Google Cloud Shell (no install, works on Windows)

1. Open [Google Cloud Console](https://console.cloud.google.com) and select project **gull-48040**.
2. Click **Activate Cloud Shell** (terminal icon in the top-right).
3. In Cloud Shell, create the CORS file and apply it:
   ```bash
   cat > cors.json << 'EOF'
   [
     {
       "origin": ["*"],
       "method": ["GET", "HEAD", "PUT", "POST", "OPTIONS"],
       "responseHeader": ["Content-Type", "Authorization", "Content-Length", "Content-Disposition"],
       "maxAgeSeconds": 3600
     }
   ]
   EOF
   gsutil cors set cors.json gs://gull-48040.firebasestorage.app
   ```
4. Reload your app; images should load and uploads should succeed.

### Option B: Local terminal (after installing Google Cloud SDK)

1. Install [Google Cloud CLI for Windows](https://cloud.google.com/sdk/docs/install-sdk#windows) and ensure **gsutil** is on your PATH (restart the terminal after install).
2. From the **gull_premium** folder:
   ```bash
   gsutil cors set storage_cors.json gs://gull-48040.firebasestorage.app
   ```
3. Reload your app.
