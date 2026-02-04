"""Set CORS on the Firebase Storage bucket so web can load/upload images.
Uses the Firebase Admin SDK service account key (pass path as first arg or set
GOOGLE_APPLICATION_CREDENTIALS). Run from project root:
  python gull_premium/set_storage_cors.py
  python gull_premium/set_storage_cors.py path/to/key.json
"""
import os
import sys

def main():
    key_path = (
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    )
    if not key_path or not os.path.isfile(key_path):
        print("Usage: python set_storage_cors.py [path/to/service-account-key.json]")
        print("Or set GOOGLE_APPLICATION_CREDENTIALS to the key file path.")
        sys.exit(1)

    try:
        from google.oauth2 import service_account
        from google.cloud import storage
    except ImportError:
        print("Install: pip install google-cloud-storage")
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_file(key_path)
    client = storage.Client(credentials=credentials, project=credentials.project_id)
    bucket_name = "gull-48040.firebasestorage.app"
    bucket = client.get_bucket(bucket_name)

    bucket.cors = [
        {
            "origin": ["*"],
            "method": ["GET", "HEAD", "PUT", "POST", "OPTIONS"],
            "responseHeader": [
                "Content-Type",
                "Authorization",
                "Content-Length",
                "Content-Disposition",
            ],
            "maxAgeSeconds": 3600,
        }
    ]
    bucket.patch()
    print(f"CORS set on gs://{bucket_name}. Reload your app.")


if __name__ == "__main__":
    main()
