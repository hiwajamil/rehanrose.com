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

## Image compression (vendor uploads)

All vendor uploads (bouquets and add-on images) are compressed **on the client** before upload:

- **Format:** JPG/PNG/HEIC → **WebP** (fallback to JPEG if WebP is unsupported on the platform).
- **Full-size:** Max width **1080px**, aspect ratio preserved, **80%** quality.
- **Thumbnails:** Bouquet images get a **300×300** (fit) thumbnail for listing grids; product detail uses the full-size URL.

This is implemented in `lib/core/utils/image_compression_service.dart` using `flutter_image_compress` and the `image` package for dimension-based resizing.

### Optional: Firebase Resize Images extension (server-side backup)

To add a **server-side** resize step (e.g. in case some clients upload without compression), you can install the official Firebase extension:

1. Open [Firebase Console](https://console.firebase.google.com) → your project → **Extensions**.
2. Click **Install extension** and search for **“Resize Images”** (by Firebase).
3. Configure the trigger (e.g. Storage path `bouquets/{vendorId}/{fileName}`), **max width** (e.g. 1080), **max height**, and output format (e.g. WebP).
4. The extension runs in the cloud when files are uploaded and writes resized versions (you can replace originals or write to a different path).

This is optional; the app already compresses before upload.
