/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions/v2/options");
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

/**
 * Updates customer loyalty tier when an order becomes completed/delivered.
 * v1 Firestore trigger as requested.
 */
exports.updateUserTierOnOrderComplete = functions.firestore
    .document("orders/{orderId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      const beforeStatus = (before.status || "").toString().toLowerCase().trim();
      const afterStatus = (after.status || "").toString().toLowerCase().trim();
      const completedStatuses = new Set(["completed", "delivered"]);
      const statusJustCompleted =
      !completedStatuses.has(beforeStatus) && completedStatuses.has(afterStatus);

      if (!statusJustCompleted) return null;

      const userId = (after.userId || "").toString().trim();
      const totalPriceRaw = after.totalPrice;
      const totalPrice = typeof totalPriceRaw === "number" ?
      totalPriceRaw :
      Number(totalPriceRaw || 0);

      if (!userId || !Number.isFinite(totalPrice) || totalPrice <= 0) {
        return null;
      }

      const userRef = admin.firestore().collection("users").doc(userId);
      const userSnap = await userRef.get();
      if (!userSnap.exists) return null;

      const userData = userSnap.data() || {};
      const currentTotalRaw = userData.totalSpent;
      const currentTotal = typeof currentTotalRaw === "number" ?
      currentTotalRaw :
      Number(currentTotalRaw || 0);
      const safeCurrentTotal = Number.isFinite(currentTotal) ? currentTotal : 0;
      const newTotalSpent = safeCurrentTotal + totalPrice;

      let newTier = "Silver";
      if (newTotalSpent >= 500000) {
        newTier = "Platinum";
      } else if (newTotalSpent >= 250000) {
        newTier = "Gold";
      }

      await userRef.set(
          {
            totalSpent: newTotalSpent,
            tier: newTier,
          },
          {merge: true},
      );

      return null;
    });
