const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

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
    const path = req.path || req.url || '';
    const match = path.match(/^\/p\/([^/?#]+)/);
    const id = match ? match[1].trim() : null;

    if (!id) {
      res.status(400).send('Bad request: missing bouquet id');
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
