const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

initializeApp();

const FUNCTIONS_REGION = 'europe-west1';

function normalizeEmail(value) {
  return (value || '').toString().trim().toLowerCase();
}

/** Same key as Flutter `AppEnv.superAdminEmail`; set on deployed functions if you use the super-admin email bypass server-side. */
const SUPER_ADMIN_EMAIL = normalizeEmail(process.env.SUPER_ADMIN_EMAIL || '');

/**
 * Whether the caller is an admin: `users.role`, `admins/{uid}`, or optional
 * SUPER_ADMIN_EMAIL match (mirrors client when env is set). Firestore rules
 * do not evaluate email; they use role / admins only.
 */
async function isCallerAdmin(db, uid, idTokenEmail) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists && userDoc.data()?.role === 'admin') return true;
  const adminDoc = await db.collection('admins').doc(uid).get();
  if (adminDoc.exists) return true;
  if (SUPER_ADMIN_EMAIL && normalizeEmail(idTokenEmail) === SUPER_ADMIN_EMAIL) return true;
  return false;
}

/**
 * Deletes a customer's Firebase Auth account, then Firestore user doc and `occasions` subcollection.
 * Callable: must be invoked by an authenticated admin.
 */
exports.deleteCustomerUser = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  const callerUid = request.auth.uid;
  const targetUid = request.data?.targetUid;
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid is required.');
  }
  if (callerUid === targetUid) {
    throw new HttpsError('invalid-argument', 'You cannot delete your own account here.');
  }

  const db = getFirestore();
  if (!(await isCallerAdmin(db, callerUid, request.auth.token?.email))) {
    throw new HttpsError('permission-denied', 'Only admins can delete members.');
  }

  const targetDoc = await db.collection('users').doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError('not-found', 'Member not found.');
  }
  if (targetDoc.data()?.role !== 'customer') {
    throw new HttpsError('failed-precondition', 'Only customer accounts can be removed from CRM this way.');
  }

  const auth = getAuth();
  await auth.deleteUser(targetUid);

  const userRef = db.collection('users').doc(targetUid);
  const occSnap = await userRef.collection('occasions').get();
  if (occSnap.docs.length > 0) {
    const batch = db.batch();
    occSnap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  await userRef.delete();

  return { ok: true };
});

/**
 * After the client signs in with a phone OTP credential, updates the password
 * on the Firestore `users` document that matches the token's `phone_number`.
 * Needed when the driver Auth user is email/password-only and phone was never
 * linked (OTP sign-in would otherwise be a different Firebase UID).
 */
exports.resetDriverPasswordWithPhoneOtp = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  const tokenPhone = request.auth.token.phone_number;
  if (!tokenPhone || typeof tokenPhone !== 'string') {
    throw new HttpsError('failed-precondition', 'Phone verification required.');
  }
  const newPassword = request.data?.newPassword;
  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
  }

  const db = getFirestore();
  const snap = await db.collection('users').where('phoneNumber', '==', tokenPhone).limit(2).get();

  if (snap.empty) {
    throw new HttpsError('not-found', 'No account found for this phone number.');
  }
  if (snap.size > 1) {
    throw new HttpsError('failed-precondition', 'Multiple accounts use this phone. Contact support.');
  }

  const targetUid = snap.docs[0].id;
  const auth = getAuth();
  await auth.updateUser(targetUid, { password: newPassword });

  return { ok: true };
});

// Google Places API key for server-side proxy (avoids CORS on web).
// Set via: firebase functions:config:set google_maps.api_key="YOUR_KEY"
const getPlacesApiKey = () =>
  process.env.GOOGLE_PLACES_API_KEY ||
  functions.config().google_maps?.api_key ||
  'AIzaSyA56HwxP_2za24pqTKG9wfZ8MdeGt2GOqY';

const COLLECTION = 'bouquets';

/**
 * Formats IQD price with thousands separators (e.g. 25000 -> "25,000 IQD").
 */
function formatPriceIqd(priceIqd) {
  if (priceIqd == null || typeof priceIqd !== 'number') return '—';
  return priceIqd.toLocaleString('en-US') + ' IQD';
}

/**
 * Escapes HTML for safe use in attributes and text.
 */
function escapeHtml(s) {
  if (s == null || typeof s !== 'string') return '';
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Serves a minimal HTML page with Open Graph meta for a bouquet so that
 * WhatsApp (and other crawlers) show photo, code, and price in the link preview.
 * Real users are redirected to the Flutter app /flower/:id.
 */
exports.getFlowerPreview = onRequest(
  { region: 'europe-west1' },
  async (req, res) => {
    // Path can appear in different props; some proxies send original path in a header
    const pathRaw =
      req.get('x-original-url') ||
      req.get('x-forwarded-path') ||
      req.originalUrl ||
      req.url ||
      req.path ||
      '';
    const path = pathRaw.split('?')[0].split('#')[0].trim() || '';
    const match = path.match(/\/p\/([^/]+)/);
    const id = match ? match[1].trim() : null;

    if (!id) {
      const origin = `${req.protocol || 'https'}://${req.get('host') || 'rehanrose.com'}`;
      res.status(400).type('html').send(
        `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta http-equiv="refresh" content="3;url=${origin}"><title>Invalid link</title></head><body><p>Invalid or incomplete link. Redirecting to <a href="${origin}">Rehan Rose</a>…</p></body></html>`
      );
      return;
    }

    const db = getFirestore();
    const doc = await db.collection(COLLECTION).doc(id).get();

    if (!doc.exists) {
      res.status(404).send('Bouquet not found');
      return;
    }

    const data = doc.data();
    const name = data?.name ?? 'Bouquet';
    const bouquetCode = (data?.bouquetCode ?? '').trim() || id;
    const priceIqd = data?.priceIqd;
    const priceStr = formatPriceIqd(priceIqd);
    const imageUrls = data?.imageUrls;
    const imageUrl = Array.isArray(imageUrls) && imageUrls.length > 0
      ? imageUrls[0]
      : '';

    const origin = `${req.protocol || 'https'}://${req.get('host') || 'rehanrose.com'}`;
    const canonicalUrl = `${origin}/p/${id}`;
    const appUrl = `${origin}/flower/${id}`;

    const title = escapeHtml(name);
    const description = `Code: ${escapeHtml(bouquetCode)} • Price: ${escapeHtml(priceStr)}`;
    const image = imageUrl ? escapeHtml(imageUrl) : '';

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} – Rehan Rose</title>
  <meta property="og:type" content="website">
  <meta property="og:url" content="${canonicalUrl}">
  <meta property="og:title" content="${title} – Rehan Rose">
  <meta property="og:description" content="${description}">
  <meta property="og:image" content="${image}">
  <meta property="og:site_name" content="Rehan Rose">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${title} – Rehan Rose">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${image}">
  <meta http-equiv="refresh" content="0;url=${escapeHtml(appUrl)}">
  <link rel="canonical" href="${canonicalUrl}">
  <script>window.location.replace(${JSON.stringify(appUrl)});</script>
  <style>
    body { font-family: system-ui, sans-serif; padding: 2rem; text-align: center; background: #F9F6F3; }
    a { color: #25D366; }
  </style>
</head>
<body>
  <p>Redirecting to <a href="${escapeHtml(appUrl)}">${title}</a>…</p>
</body>
</html>`;

    res.set('Cache-Control', 'public, max-age=300');
    res.type('html').status(200).send(html);
  }
);

const PLACES_REGION = 'europe-west1';

/**
 * Proxy for Google Places Autocomplete. Called from Flutter web to avoid CORS.
 * GET ?input=...&lat=...&lng=...
 */
exports.placesAutocomplete = onRequest(
  { region: PLACES_REGION, cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.status(204).send('');
      return;
    }
    const input = req.query.input;
    const lat = req.query.lat;
    const lng = req.query.lng;
    if (!input || input.trim() === '') {
      res.status(400).json({ status: 'INVALID_REQUEST', error: 'Missing input' });
      return;
    }
    const apiKey = getPlacesApiKey();
    const url = new URL('https://maps.googleapis.com/maps/api/place/autocomplete/json');
    url.searchParams.set('input', input.trim());
    url.searchParams.set('key', apiKey);
    if (lat != null && lng != null) {
      url.searchParams.set('location', `${lat},${lng}`);
      url.searchParams.set('radius', '50000');
    }
    try {
      const r = await fetch(url.toString());
      const data = await r.json();
      const status = data?.status;
      const errorMessage = data?.error_message;
      if (status && status !== 'OK' && status !== 'ZERO_RESULTS') {
        console.error('[placesAutocomplete] Google Places API error: status=%s, error_message=%s', status, errorMessage || '(none)');
        console.error('[placesAutocomplete] Possible causes: REQUEST_DENIED, BILLING_NOT_ENABLED, OVER_QUERY_LIMIT, INVALID_REQUEST');
      }
      res.set('Access-Control-Allow-Origin', '*');
      res.status(200).json(data);
    } catch (e) {
      console.error('[placesAutocomplete] Proxy error (network/CORS/fetch failure):', e.message || e);
      console.error('[placesAutocomplete] Stack:', e.stack);
      res.set('Access-Control-Allow-Origin', '*');
      res.status(502).json({ status: 'ERROR', error: String(e.message || e) });
    }
  }
);

/**
 * Proxy for Google Place Details. Called from Flutter web to avoid CORS.
 * GET ?place_id=...
 */
exports.placeDetails = onRequest(
  { region: PLACES_REGION, cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.status(204).send('');
      return;
    }
    const placeId = req.query.place_id;
    if (!placeId || placeId.trim() === '') {
      res.status(400).json({ status: 'INVALID_REQUEST', error: 'Missing place_id' });
      return;
    }
    const apiKey = getPlacesApiKey();
    const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
    url.searchParams.set('place_id', placeId.trim());
    url.searchParams.set('fields', 'geometry,name');
    url.searchParams.set('key', apiKey);
    try {
      const r = await fetch(url.toString());
      const data = await r.json();
      res.set('Access-Control-Allow-Origin', '*');
      res.status(200).json(data);
    } catch (e) {
      console.error('placeDetails proxy error', e);
      res.set('Access-Control-Allow-Origin', '*');
      res.status(502).json({ status: 'ERROR', error: String(e.message || e) });
    }
  }
);

/**
 * Parses a Firestore occasion date field into a JS Date.
 * Supports Firestore Timestamp and Date.
 */
function parseOccasionDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') {
    const d = value.toDate();
    return d instanceof Date ? d : null;
  }
  return null;
}

/**
 * Returns true when month/day match, ignoring year.
 */
function isSameMonthDay(date, month, day) {
  return date.getMonth() + 1 === month && date.getDate() === day;
}

/**
 * Split a list into fixed-size chunks (FCM multicast max is 500 tokens/request).
 */
function chunkArray(items, chunkSize) {
  const chunks = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    chunks.push(items.slice(i, i + chunkSize));
  }
  return chunks;
}

/**
 * Persists a notification copy for in-app history.
 */
async function saveUserNotificationCopy(db, userId, { title, body, type }) {
  if (!userId || !title || !body || !type) return;
  await db.collection('users').doc(userId).collection('notifications').add({
    title,
    body,
    type,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });
}

/**
 * Broadcasts a marketing push notification to all users with an FCM token.
 * Triggered when admin UI creates a document in `marketing_notifications`.
 */
exports.sendMarketingBroadcastOnCreate = functions.firestore
  .document('marketing_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const titleEn = (data.title_en || data.title || '').toString().trim();
    const titleKu = (data.title_ku || titleEn).toString().trim();
    const titleAr = (data.title_ar || titleEn).toString().trim();
    const bodyEn = (data.body_en || data.body || '').toString().trim();
    const bodyKu = (data.body_ku || bodyEn).toString().trim();
    const bodyAr = (data.body_ar || bodyEn).toString().trim();
    const notificationId = context.params.notificationId;

    if (!titleEn || !bodyEn) {
      console.log(
        '[sendMarketingBroadcastOnCreate] skipped notificationId=%s reason=missing_title_or_body',
        notificationId
      );
      return null;
    }

    const db = getFirestore();
    const usersSnap = await db
      .collection('users')
      .where('fcmToken', '!=', null)
      .get();

    const tokenGroups = {
      en: [],
      ku: [],
      ar: [],
    };

    const normalizeLanguage = (value) => {
      const lang = (value || '').toString().trim().toLowerCase();
      return ['en', 'ku', 'ar'].includes(lang) ? lang : 'en';
    };

    for (const doc of usersSnap.docs) {
      const userData = doc.data() || {};
      const token = (userData.fcmToken || '').toString().trim();
      if (!token) continue;
      const language = normalizeLanguage(userData.language);
      tokenGroups[language].push({ uid: doc.id, token });
    }

    const tokensEn = tokenGroups.en;
    const tokensKu = tokenGroups.ku;
    const tokensAr = tokenGroups.ar;
    const tokens = [...tokensEn, ...tokensKu, ...tokensAr];
    if (tokens.length === 0) {
      console.log(
        '[sendMarketingBroadcastOnCreate] no_tokens notificationId=%s',
        notificationId
      );
      return null;
    }

    let successCount = 0;
    let failureCount = 0;
    const deadTokens = new Set();

    const sendForLanguage = async (language, languageEntries, title, body) => {
      if (languageEntries.length === 0) return;
      const languageChunks = chunkArray(languageEntries, 500);

      for (const chunk of languageChunks) {
        const chunkTokens = chunk.map((entry) => entry.token);
        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunkTokens,
          notification: { title, body },
          data: {
            type: 'marketing_broadcast',
            notificationId,
            language,
          },
        });

        successCount += response.successCount;
        failureCount += response.failureCount;

        const saveCopyPromises = [];
        response.responses.forEach((r, index) => {
          const entry = chunk[index];
          if (r.success) return;
          const code = r.error?.code || '';
          const isDeadToken =
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token';
          if (isDeadToken) {
            deadTokens.add(entry?.token);
          } else {
            console.error(
              '[sendMarketingBroadcastOnCreate] send failed notificationId=%s language=%s code=%s tokenTail=%s',
              notificationId,
              language,
              code || 'unknown',
              (entry?.token || '').slice(-8)
            );
          }
          return null;
        });

        response.responses.forEach((r, index) => {
          if (!r.success) return;
          const entry = chunk[index];
          if (!entry?.uid) return;
          saveCopyPromises.push(
            saveUserNotificationCopy(db, entry.uid, {
              title,
              body,
              type: 'marketing_broadcast',
            })
          );
        });
        if (saveCopyPromises.length > 0) {
          await Promise.all(saveCopyPromises);
        }
      }
    };

    await sendForLanguage('en', tokensEn, titleEn, bodyEn);
    await sendForLanguage('ku', tokensKu, titleKu || titleEn, bodyKu || bodyEn);
    await sendForLanguage('ar', tokensAr, titleAr || titleEn, bodyAr || bodyEn);

    if (deadTokens.size > 0) {
      const deadTokenList = Array.from(deadTokens);
      await Promise.all(
        deadTokenList.map(async (token) => {
          const deadUsersSnap = await db
            .collection('users')
            .where('fcmToken', '==', token)
            .get();
          if (deadUsersSnap.empty) return;
          const batch = db.batch();
          deadUsersSnap.docs.forEach((doc) => {
            batch.set(
              doc.ref,
              { fcmToken: admin.firestore.FieldValue.delete() },
              { merge: true }
            );
          });
          await batch.commit();
        })
      );
    }

    await snap.ref.set(
      {
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        attemptedTokens: tokens.length,
        successCount,
        failureCount,
        languageBreakdown: {
          en: tokensEn.length,
          ku: tokensKu.length,
          ar: tokensAr.length,
        },
      },
      { merge: true }
    );

    console.log(
      '[sendMarketingBroadcastOnCreate] done notificationId=%s attempted=%d success=%d failure=%d deadTokens=%d',
      notificationId,
      tokens.length,
      successCount,
      failureCount,
      deadTokens.size
    );
    return null;
  });

/**
 * Daily retention robot:
 * - Finds users with fcmToken
 * - Looks for occasions exactly 7 days from "today" (month/day only)
 * - Sends a luxury reminder with REMIND10 code
 */
exports.sendOccasionReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Baghdad')
  .onRun(async () => {
    const db = getFirestore();
    const now = new Date();
    const targetDate = new Date(now);
    targetDate.setDate(now.getDate() + 7);
    const targetMonth = targetDate.getMonth() + 1;
    const targetDay = targetDate.getDate();

    const usersSnap = await db
      .collection('users')
      .where('fcmToken', '!=', null)
      .get();

    let sentCount = 0;
    let checkedUsers = 0;

    for (const userDoc of usersSnap.docs) {
      checkedUsers += 1;
      const userData = userDoc.data() || {};
      const fcmToken = (userData.fcmToken || '').toString().trim();
      if (!fcmToken) continue;

      const occasionsSnap = await userDoc.ref.collection('occasions').get();
      if (occasionsSnap.empty) continue;

      for (const occasionDoc of occasionsSnap.docs) {
        const occasion = occasionDoc.data() || {};
        const occasionDate = parseOccasionDate(occasion.date);
        if (!occasionDate) continue;
        if (!isSameMonthDay(occasionDate, targetMonth, targetDay)) continue;

        const relation = (occasion.relation || 'Loved one').toString().trim() || 'Loved one';
        const occasionName = (occasion.name || 'Special Day').toString().trim() || 'Special Day';
        const body = `Next week is ${relation}'s ${occasionName}! Let Rehan Rose prepare the perfect gift. Use code REMIND10 for 10% off.`;

        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: '✨ A Special Day is Approaching!',
              body,
            },
            data: {
              type: 'occasion_reminder',
              promoCode: 'REMIND10',
              relation,
              occasionName,
              occasionId: occasionDoc.id,
            },
          });
          await saveUserNotificationCopy(db, userDoc.id, {
            title: '✨ A Special Day is Approaching!',
            body,
            type: 'occasion_reminder',
          });
          sentCount += 1;
        } catch (error) {
          const code = error?.code || '';
          const isDeadToken =
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token';

          if (isDeadToken) {
            await userDoc.ref.set(
              { fcmToken: admin.firestore.FieldValue.delete() },
              { merge: true }
            );
          } else {
            console.error(
              '[sendOccasionReminders] FCM send failed for user=%s occasion=%s code=%s',
              userDoc.id,
              occasionDoc.id,
              code || 'unknown'
            );
          }
        }
      }
    }

    console.log(
      '[sendOccasionReminders] done checkedUsers=%d sent=%d targetMonth=%d targetDay=%d',
      checkedUsers,
      sentCount,
      targetMonth,
      targetDay
    );
    return null;
  });

/**
 * Updates customer loyalty tier after an order is completed/delivered.
 * Triggered only on status transition to a terminal successful state.
 */
exports.updateUserTierOnOrderComplete = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeStatus = (before.status || '').toString().toLowerCase().trim();
    const afterStatus = (after.status || '').toString().toLowerCase().trim();
    const completedStatuses = new Set(['completed', 'delivered']);

    const statusJustCompleted =
      !completedStatuses.has(beforeStatus) && completedStatuses.has(afterStatus);
    if (!statusJustCompleted) return null;

    const userId = (after.userId || '').toString().trim();
    const orderTotalRaw = after.totalPrice;
    const orderTotalPrice = typeof orderTotalRaw === 'number' ? orderTotalRaw : Number(orderTotalRaw || 0);

    if (!userId || !Number.isFinite(orderTotalPrice) || orderTotalPrice <= 0) {
      return null;
    }

    const db = getFirestore();
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return null;

    const userData = userSnap.data() || {};
    const currentSpentRaw = userData.totalSpent;
    const currentSpent = typeof currentSpentRaw === 'number' ? currentSpentRaw : Number(currentSpentRaw || 0);
    const newTotalSpent = (Number.isFinite(currentSpent) ? currentSpent : 0) + orderTotalPrice;

    let newTier = 'silver';
    if (newTotalSpent >= 500000) {
      newTier = 'platinum';
    } else if (newTotalSpent >= 250000) {
      newTier = 'gold';
    }

    await userRef.set(
      {
        totalSpent: newTotalSpent,
        tier: newTier,
      },
      { merge: true }
    );

    return null;
  });

/**
 * Notifies the customer (FCM) when an OMS order moves into "preparing".
 * OMS documents live in `oms_orders` (Super Admin create + vendor status updates).
 */
exports.notifyUserOnOrderPreparing = functions.firestore
  .document('oms_orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeStatus = change.before.data()?.status;
    const afterStatus = change.after.data()?.status;

    if (beforeStatus === 'preparing' || afterStatus !== 'preparing') {
      return null;
    }

    const after = change.after.data() || {};
    const userId = (after.userId || '').toString().trim();
    if (!userId) return null;

    const db = getFirestore();
    const userSnap = await db.collection('users').doc(userId).get();
    if (!userSnap.exists) return null;

    const fcmToken = (userSnap.data()?.fcmToken || '').toString().trim();
    if (!fcmToken) return null;

    const orderId = context.params.orderId;

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Order Accepted! 🎉',
          body:
            'The vendor has started preparing your order. It will be ready soon!',
        },
        data: {
          orderId,
          type: 'order_status',
          status: 'preparing',
        },
      });
      await saveUserNotificationCopy(db, userId, {
        title: 'Order Accepted! 🎉',
        body: 'The vendor has started preparing your order. It will be ready soon!',
        type: 'order_status',
      });
    } catch (error) {
      const code = error?.code || '';
      const isDeadToken =
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token';

      if (isDeadToken) {
        await db.collection('users').doc(userId).set(
          { fcmToken: admin.firestore.FieldValue.delete() },
          { merge: true }
        );
      } else {
        console.error(
          '[notifyUserOnOrderPreparing] FCM send failed order=%s user=%s code=%s',
          orderId,
          userId,
          code || 'unknown'
        );
      }
    }

    return null;
  });
