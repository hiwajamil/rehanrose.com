# Security & Performance Audit Report — Gull Premium Flutter App

**Date:** February 26, 2025  
**Scope:** Full codebase audit (Security + Performance)

---

## Executive Summary

- **Firestore rules** are well-structured and enforce role-based access; customers cannot read other users or admin-only data. A few improvements are recommended (admin route redirect, members query consistency).
- **Authentication and role checks** are correct at the data layer; the app should add **route-level redirects** so non-admins never see admin UI.
- **Sensitive data**: Firebase API keys and Google client IDs are in source; **Places API key** and **Super Admin email** are hardcoded. Move secrets to env / build args and ensure `firebase_options.dart` and `google_client_id.dart` are not committed or use placeholders.
- **Images**: Several screens use `Image.network` instead of `AppCachedImage`/`CachedNetworkImage`, causing extra bandwidth and no disk cache.
- **Firebase queries**: Bouquet and order repos use limits/pagination; **add-ons** and **vendors** are fetched without limits; **members** uses a high limit (500) with no pagination.

---

# 1. SECURITY AUDIT

## 1.1 Firebase Firestore Rules

**Verdict: Secure.** Rules correctly restrict access.

| Collection | Read | Write | Notes |
|------------|------|--------|------|
| `users` | Admin or owner only | Admin or owner only | Customers cannot read other users. |
| `admins` | Authenticated (for `isAdmin()` check) | `false` (console only) | Correct. |
| `vendors` | Public | Admin only | Correct. |
| `orders` | Owner or admin | Create: owner; Update/Delete: admin | Correct. |
| `oms_orders` | Admin or vendor (own) | Admin or vendor (own, status only) | Correct. |
| `bouquets` | Public read | Create/update/delete by role | Correct. |
| `addons` | Public | Admin only | Correct. |
| `vendor_applications` | Admin | Create: owner; Update: admin | Correct. |

- **Members (CRM)**: The Members feature reads from `users` with `where('role', isEqualTo: 'customer')`. Firestore rules allow read only when `isAdmin() || isOwner(userId)`. So a customer running that query would only get their own document; **data is protected**. The only risk is **information disclosure** if a customer reaches the admin Members UI (see 1.2).

**Recommendation (Low):** Add a composite index for the members query if not already present:  
`users` collection: `role` (Ascending) + `createdAt` (Descending).

---

## 1.2 Authentication & Role Management

**Verdict: Data layer secure; route layer needs hardening.**

- **Vendor:** Sign-in and `vendorStatusForUidProvider` ensure only approved vendors see the vendor dashboard; Firestore rules restrict vendor writes. **OK.**
- **Admin:** `isAdminForUidProvider` is used in `AdminShellLayout` and some admin pages. **Issue:** When the user is **not** admin, the shell still renders `Scaffold(body: child)`, so the **admin page widget (e.g. MembersListScreen)** is shown. Firestore then returns only the user’s own data (or errors), but the **admin UI is visible**. This is a defense-in-depth and UX issue.

**High priority — Redirect non-admins away from `/admin`:**

- **Current (admin_shell_layout.dart):** When `!isAdmin`, the shell still shows `child` (the admin screen).
- **Fix:** Redirect to `/` or `/dashboard` and optionally show a “Not authorized” message instead of rendering admin content.

**Snippet to fix — redirect in shell:**

```dart
// lib/presentation/widgets/layout/admin_shell_layout.dart
data: (isAdmin) {
  if (!isAdmin) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        GoRouter.of(context).go('/dashboard');
        // Optionally: ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(l10n.adminNotAuthorized));
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return Scaffold(
    body: Row(
      // ... existing admin layout
```

**Better approach — central redirect in router:**  
Add a global `redirect` in `app_router.dart` so that any `/admin` or `/admin/*` route is redirected when the user is not admin (e.g. redirect to `/dashboard`). That way the admin shell does not need to render the child at all for non-admins.

---

## 1.3 Sensitive Data (API Keys, Secrets, Credentials)

**Verdict: High risk.** Several secrets are in source and some are committed.

| Location | Content | Risk | Action |
|----------|---------|------|--------|
| `lib/firebase_options.dart` | Web/Android/iOS API keys, project ID, etc. | Medium (Firebase client keys are public but project must be locked by rules) | Prefer FlutterFire code gen from env; ensure not in public repo or use placeholders. |
| `lib/env/google_client_id.dart` | Google OAuth Web client ID | **High** (OAuth client ID in repo) | Move to `.env` or `--dart-define`; do not commit real value. |
| `lib/presentation/pages/product/delivery_map_picker.dart` | `_placesApiKey = 'AIzaSy...'` | **High** (Google API key in repo) | Move to env / build args or backend proxy only. |
| `lib/data/repositories/auth_repository.dart` | `kSuperAdminEmail = '...@gmail.com'` | **High** (super admin identity in repo) | Move to `--dart-define=SUPER_ADMIN_EMAIL=...` only; no default in source. |

**.gitignore:**  
`firebase_options.dart` and `lib/env/google_client_id.dart` are **not** in `.gitignore`; if they contain real keys, they are committed. Add them or use template files (e.g. `google_client_id.dart.example`) and keep real values in env/CI.

**Snippets to fix:**

1) **Places API key — use env / dart-define (delivery_map_picker.dart):**

```dart
// Remove hardcoded key. Use:
const String _placesApiKey = String.fromEnvironment(
  'PLACES_API_KEY',
  defaultValue: '', // or use proxy-only on web
);
// On web you already use proxy; on mobile pass key via --dart-define=PLACES_API_KEY=...
```

2) **Super Admin email — no default in source (auth_repository.dart):**

```dart
// Remove default value from source; require it at build/runtime:
const String kSuperAdminEmail = String.fromEnvironment(
  'SUPER_ADMIN_EMAIL',
  defaultValue: '', // Require set in production
);
// In isAdmin(), treat empty as false or assert in debug.
```

3) **Google Web Client ID:**  
Keep in `lib/env/google_client_id.dart` only for local dev; production should use `String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '')` and set in CI/build. Add `lib/env/google_client_id.dart` to `.gitignore` if it contains a real ID.

---

# 2. PERFORMANCE & OPTIMIZATION AUDIT

## 2.1 Widget Rebuilds & `const` Usage

- **Members list flicker:** `members_repository.dart` already reduces flicker by emitting only when the list of UIDs (and order) changes, not on every snapshot. **Good.**
- **General:** Use `const` constructors where possible (e.g. `SizedBox`, `EdgeInsets`, static widgets) to reduce rebuilds and allocations. The codebase uses `const` in many places; no single critical hotspot was identified. Keep applying `const` for new code.

**Low priority:** Run `dart fix --apply` and consider the `prefer_const_*` lints to tighten `const` usage.

---

## 2.2 Image Handling & Caching

**Verdict: Inconsistent.** The app has `AppCachedImage` (with `cached_network_image` and app cache manager) but several UIs still use `Image.network`, so those images are not cached and use more data.

**Replace `Image.network` with `AppCachedImage` (or `CachedNetworkImage`) in:**

| File | Approx. line | Current | Fix |
|------|-------------|--------|-----|
| `lib/presentation/pages/admin/members/members_list_screen.dart` | 417 | `Image.network(imageUrl, ...)` | Use `AppCachedImage(imageUrl: imageUrl, width: 64, height: 64, fit: BoxFit.cover)` with same borderRadius/clip. |
| `lib/presentation/widgets/oms/oms_order_card.dart` | 136 | `Image.network(order.bouquetImageUrl!, ...)` | Use `AppCachedImage(imageUrl: order.bouquetImageUrl!, width: ..., height: ..., fit: BoxFit.cover)` and keep `key`, placeholder, and error handling in `AppCachedImage` (or use its `errorWidget`). |
| `lib/presentation/pages/admin/admin_orders_page.dart` | 725 | `Image.network(imageUrl, ...)` | Use `AppCachedImage(imageUrl: imageUrl, width: 120, height: 120, fit: BoxFit.cover)`. |
| `lib/presentation/pages/auth/login_screen.dart` | 489 | `Image.network('...google-logo...')` | Use `CachedNetworkImage` or `AppCachedImage` for the Google logo URL. |
| `lib/presentation/pages/auth/registration_screen.dart` | 689 | Same Google logo | Same as login. |

**Example (members_list_screen.dart):**

```dart
// Before:
child: imageUrl != null && imageUrl.isNotEmpty
    ? Image.network(
        imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderThumb(context),
      )
    : _placeholderThumb(context),

// After:
child: imageUrl != null && imageUrl.isNotEmpty
    ? AppCachedImage(
        imageUrl: imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorIconSize: 28,
      )
    : _placeholderThumb(context),
```

Add `import 'package:gull_premium/presentation/widgets/common/app_cached_image.dart';` (or the correct relative path) where needed.

---

## 2.3 Firebase Queries (Streams, Limits, Pagination)

**Verdict: Mostly good; a few unbounded or large queries.**

| Area | Current | Issue | Recommendation |
|------|--------|--------|----------------|
| Bouquets (listing) | Paginated (e.g. pageSize 10), limits, `startAfterDocument` | None | Keep as is. |
| Orders (admin) | `limit(100)` | OK | Consider pagination if order count grows. |
| Members (CRM) | `limit(500)` | No pagination; 500 docs per stream | Add cursor-based pagination (e.g. `startAfterDocument`) and a smaller page size (e.g. 20–50). |
| Add-ons | `_addOns.get()` | **Unbounded** | Add `.limit(200)` or similar; add-ons are finite but should be capped. |
| Vendors | `collection('vendors').get()` | **Unbounded** | Add `.limit(500)` or paginate if vendor count can grow. |
| Vendor applications | `where('status', 'pending').snapshots()` | Unbounded | Add `.limit(100)` for admin dashboard. |
| `watchBouquetsByVendor` | No limit | Vendor could have many bouquets | Add `.limit(100)` or paginate. |

**Snippets to fix:**

1) **Add-ons (add_on_repository.dart) — add limit:**

```dart
// getAddOns — cap read size
final snap = await _addOns.limit(200).get().timeout(_queryTimeout);
```

2) **Vendors (auth_repository.dart) — add limit:**

```dart
final snap = await _firestore.collection('vendors').limit(500).get();
```

3) **Vendor applications stream (auth_repository.dart) — add limit:**

```dart
return _firestore
    .collection('vendor_applications')
    .where('status', isEqualTo: 'pending')
    .limit(100)
    .snapshots();
```

4) **watchBouquetsByVendor (bouquet_repository.dart) — add limit:**

```dart
return _bouquets
    .where('vendorId', isEqualTo: vendorId)
    .limit(100)
    .snapshots()
    .timeout(_queryTimeout)
    .map(...);
```

5) **Members:** Keep `limit(500)` short-term but add pagination (e.g. `watchCustomersPage(startAfterDocument)`) and a smaller page size so the admin members list does not load 500 docs on first open.

---

# 3. PRIORITY SUMMARY

## High priority

1. **Secrets in source:** Remove hardcoded Places API key, Super Admin email default, and avoid committing real Google Web Client ID; use env / `--dart-define` and optionally `.gitignore` for sensitive files.
2. **Admin route access:** Redirect non-admins away from `/admin` and `/admin/*` (router or shell) so admin UI is never shown to customers/vendors.

## Medium priority

3. **Image caching:** Replace all `Image.network` usages (members list, OMS order card, admin orders, login/register Google logo) with `AppCachedImage` or `CachedNetworkImage`.
4. **Unbounded Firestore reads:** Add `.limit()` to add-ons fetch, vendors fetch, vendor applications stream, and `watchBouquetsByVendor`.

## Low priority

5. **Members CRM:** Add pagination and consider a composite index for `users` (role + createdAt).
6. **Admin orders:** Consider pagination if order volume grows.
7. **Const and lints:** Broaden `const` usage and run `dart fix` / prefer_const lints.

---

# 4. FIREBASE RULES — CAN A CUSTOMER ACCESS ADMIN/VENDOR DATA?

**Short answer: No.**  
Firestore rules enforce:

- **users:** Read/write only for `isAdmin()` or `isOwner(userId)`. A customer can only read/write their own document. The “members” query from the app would only return that one document when run as a customer.
- **admins:** Write disabled; read only for authenticated (to evaluate `isAdmin()`).
- **orders:** Read for owner or admin; customers cannot read other users’ orders.
- **oms_orders:** Read for admin or vendor (own); customers have no read access.
- **vendor_applications:** Read/update for admin only; create for owner only.

So a regular customer cannot read Super Admin or vendor data via Firestore. The only correction needed is **UI/route protection** so non-admins never see admin screens (redirect in router or admin shell).

---

*End of audit report.*
