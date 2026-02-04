const admin = require('firebase-admin');

const serviceAccountPath = process.argv[2];
const uid = process.argv[3];

if (!serviceAccountPath || !uid) {
  console.error('Usage: node set_admin.js <service_account.json> <uid>');
  process.exit(1);
}

// Load service account JSON from provided path.
// eslint-disable-next-line import/no-dynamic-require, global-require
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const firestore = admin.firestore();

async function run() {
  await firestore.collection('admins').doc(uid).set(
    {
      role: 'super_admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log('Admin role granted for UID:', uid);
}

run().catch((error) => {
  console.error('Failed to grant admin role:', error);
  process.exit(1);
});
