const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const functions = require('firebase-functions');

initializeApp();

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
      res.set('Access-Control-Allow-Origin', '*');
      res.status(200).json(data);
    } catch (e) {
      console.error('placesAutocomplete proxy error', e);
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
