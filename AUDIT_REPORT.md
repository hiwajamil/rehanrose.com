# Flutter & Firebase Security, Performance, and Clean Code Audit

**Project:** Gull (Rehan Rose)  
**Date:** February 22, 2026  
**Scope:** gull_premium Flutter app + Firestore/Storage rules

---

## Executive Summary

The codebase demonstrates solid foundations: Firestore rules with role-based access, Riverpod state management with appropriate use of `autoDispose`/`keepAlive`, paginated product loading, and image compression before upload. Several security gaps require immediate attention (especially Storage rules for voice messages), and there are opportunities to improve error handling, reduce redundant Firestore reads, and refactor large files.

---

## 1. Security Vulnerabilities

### High Priority

#### 1.1 Voice messages Storage rule allows unauthenticated writes (CRITICAL)

**Location:** `gull_premium/storage.rules` (lines 17–20)

```javascript
match /voice_messages/{fileName} {
  allow read: if true;
  allow write: if true;  // ← Anyone can upload/delete!
}
```

**Risk:** Unauthenticated users can upload or delete arbitrary files under `voice_messages/`. This can lead to abuse (storage costs, malware, overwriting legitimate files).

**Recommendation:** Restrict writes to authenticated users. If voice messages are tied to orders, consider path structure such as `voice_messages/{orderId}/{fileName}` and enforce ownership (e.g. `request.auth.uid == resource.metadata.userId` or similar).

```javascript
match /voice_messages/{fileName} {
  allow read: if true;
  allow write: if request.auth != null;
}
```

(Or stricter: e.g. only allow writes from users who have created an order.)

---

#### 1.2 Add-ons Storage allows any signed-in user to write

**Location:** `gull_premium/storage.rules` (lines 12–15)

```javascript
match /addons/{fileName} {
  allow read: if true;
  allow write: if isSignedIn();  // Any authenticated user!
}
```

**Risk:** Firestore rules restrict add-on writes to admins only, but Storage allows any authenticated user to upload/overwrite addon images.

**Recommendation:** Use Firebase Auth custom claims or a Firestore lookup to ensure only admins can write. Example (requires custom claims):

```javascript
match /addons/{fileName} {
  allow read: if true;
  allow write: if request.auth != null
    && request.auth.token.admin == true;
}
```

Or restrict by a stored admin list in Firestore (similar to your Firestore `admins` pattern), though Storage rules cannot easily do Firestore `get()` for every write. A practical approach is to use Cloud Functions or backend API for add-on image uploads with admin checks.

---

### Medium Priority

#### 1.3 Counters collection is writable by any authenticated user

**Location:** `gull_premium/firestore.rules` (lines 51–53)

```javascript
match /counters/{counterId} {
  allow read, write: if isAuthenticated();
}
```

**Risk:** Any signed-in user (including customers) can read and modify counters (e.g. `bouquet_$prefix`). This could corrupt bouquet code sequences or cause collisions.

**Recommendation:** Restrict to admins and vendors only:

```javascript
match /counters/{counterId} {
  allow read, write: if isAdmin() || isVendor();
}
```

---

#### 1.4 Super admin email hardcoded in source

**Locations:**
- `gull_premium/lib/data/repositories/auth_repository.dart` (line 7): `kSuperAdminEmail = 'hiwa.constructions@gmail.com'`
- Referenced in `admin_dashboard_page.dart`, `bouquet_approval_page.dart`, `dashboard_resolver_page.dart`

**Risk:** Email is exposed in source control. Although Firebase API keys in client apps are expected, this pattern encourages hardcoding other credentials.

**Recommendation:** Move to environment variables or Dart `--dart-define` (e.g. `kSuperAdminEmail = const String.fromEnvironment('SUPER_ADMIN_EMAIL', defaultValue: '')`). Add the real value in CI/CD and local dev config only.

---

#### 1.5 Empty catch blocks swallow errors

**Locations:** Multiple (e.g. `auth_repository.dart` 187/201, `add_on_repository.dart` 73/84/105/121, `bouquet_repository.dart` 281/391, `vendor_controller.dart` 41)

**Risk:** Failures are silent. Malformed data or permission errors go unlogged, making debugging and incident response difficult.

**Recommendation:** Log errors in debug mode or to a crash/analytics service:

```dart
} catch (e, st) {
  debugPrint('Add-on parse failed for doc ${doc.id}: $e');
  debugPrintStack(stackTrace: st);
}
```

---

### Low Priority

#### 1.6 WhatsApp phone number hardcoded

**Location:** `gull_premium/lib/core/services/whatsapp_service.dart` (lines 7–8)

**Risk:** Low. Phone number is not a secret, but changing it requires a code change.

**Recommendation:** Consider `--dart-define` or env config for flexibility.

---

#### 1.7 Firebase API keys in source

**Location:** `gull_premium/lib/firebase_options.dart`

**Note:** This is expected for Flutter/Firebase. Keys are restricted by Firebase Console (HTTP referrer, package name, etc.). Ensure `firebase_options.dart` is not in `.gitignore` (it is generated and committed). Use API key restrictions in Firebase Console (Application restrictions, API restrictions).

---

## 2. Performance Bottlenecks

### High Priority

#### 2.1 Bouquet repository fetches 2× limit, uses half

**Location:** `gull_premium/lib/data/repositories/bouquet_repository.dart`

Example (lines 56–78, 131–162):

```dart
query = _bouquets
    .where('approvalStatus', isEqualTo: 'approved')
    .limit(_limit * 2);  // Fetches 100
// ...
final list = _parseBouquetDocs(snap.docs).take(_limit).toList();  // Uses 50
```

**Impact:** Unnecessary Firestore reads (50 extra per request). Repeats in `getBouquets`, `getBouquetsPage`, `watchBouquets`, etc.

**Recommendation:** Use `limit(_limit)` (or `limit`) consistently. If you need a buffer for filtering/sorting, document the reason and keep it minimal.

---

### Medium Priority

#### 2.2 Missing `const` modifiers

**Observation:** Many widgets (e.g. `SizedBox`, `EdgeInsets`, `Padding`, `Icon`) can be `const` but are not. Example in `flower_card.dart`:

```dart
// Before
SizedBox(height: widget.isCompact ? 4 : 8),

// After (where values are constant)
const SizedBox(height: 8),
```

**Recommendation:** Run `dart fix --apply` and add `const` where constructors allow it to reduce widget rebuilds.

---

#### 2.3 GridView.count / ListView with small fixed lists

**Locations:**
- `landing_page.dart` (line 291): `GridView.count` for `kEmotionCategories` (small)
- `manage_add_ons_landing_page.dart` (line 146): `GridView.count` for 3–4 categories
- `vendor_shell_layout.dart` (line 147): `ListView` for nav items (~10)

**Impact:** Low for these small lists. For large dynamic lists, prefer `ListView.builder` / `GridView.builder`; current usage is acceptable.

---

#### 2.4 ConnectivityService never disposed

**Location:** `gull_premium/lib/controllers/connectivity_controller.dart`

```dart
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();  // No ref.onDispose
});
```

**Impact:** `ConnectivityService` holds a `StreamSubscription` and `StreamController`. For a long-lived app, this is usually acceptable; for tests or short-lived flows, it could leak.

**Recommendation:** Add `ref.onDispose(() => ref.read(connectivityServiceProvider).dispose())` if the provider is ever overridden or recreated. For a global Provider, the leak is minor.

---

### Low Priority

#### 2.5 Image decoding on main thread

**Location:** `gull_premium/lib/core/utils/image_compression_service.dart` (line 133)

`img.decodeImage(bytes)` can be CPU-heavy for large images.

**Recommendation:** Consider `compute()` for decode/compress on large images:

```dart
final dimensions = await compute(_decodeDimensionsIsolate, bytes);
```

---

## 3. Clean Code & Architecture

### High Priority

#### 3.1 Split oversized files

| File | Lines | Suggestion |
|------|-------|------------|
| `bouquet_approval_page.dart` | ~1,223 | Extract `_ApprovalCard`, `_RejectBouquetDialog`, tab content widgets into separate files |
| `landing_page.dart` | ~880 | Extract `_HeroSection`, `_CategoryCardsSection`, `_ProductsSection`, `_BouquetGrid`, `_TrustSection` into `landing/` widgets |
| `manage_add_ons_page.dart` | ~654 | Extract dialogs and list item widgets |

**Recommendation:** One main concept per file. Use `part`/`part of` sparingly; prefer separate files and imports.

---

#### 3.2 Improve error handling in repositories

**Pattern:** Many `catch (_)` blocks return fallbacks without logging.

**Recommendation:**
- Use a shared error logger (e.g. Firebase Crashlytics).
- In critical paths (e.g. order creation), propagate errors to the UI with user-friendly messages.
- Consider a `Result<T, E>` or `Either` style for operations that can fail.

---

### Medium Priority

#### 3.3 Input validation before Firestore writes

**Observation:** `trim()` is used in many places; stronger validation is sporadic. No centralized validation for:
- Max lengths (names, descriptions, rejection notes)
- Sanitization (e.g. stripping script tags, control characters)
- Type constraints (e.g. `priceIqd` non-negative)

**Recommendation:**
- Add a validation layer (e.g. `AddOnValidator`, `OrderValidator`) before repository calls.
- Firestore rules can enforce schema; add `request.resource.data` validation for critical fields.

---

#### 3.4 Provider organization

**Observation:** Providers are split across `auth_controller.dart`, `bouquets_controller.dart`, `order_controller.dart`, etc. Naming is clear.

**Recommendation:** Consider a `providers/` barrel file or index for discovery. Document which providers are long-lived vs `autoDispose`.

---

### Low Priority

#### 3.5 Duplicate super-admin check logic

**Locations:** `auth_repository.dart`, `admin_dashboard_page.dart`, `bouquet_approval_page.dart`, `dashboard_resolver_page.dart`

**Recommendation:** Centralize in `AuthRepository.isAdmin()` and use that everywhere. Avoid duplicating email checks in UI.

---

## 4. Actionable Prioritized List

### High Priority

| # | Category | Item | Action |
|---|----------|------|--------|
| 1 | Security | Voice messages Storage `allow write: if true` | Restrict to `request.auth != null` (or stricter) |
| 2 | Security | Add-ons Storage writable by any user | Restrict to admins (custom claims or backend) |
| 3 | Security | Counters writable by any user | Restrict to `isAdmin() \|\| isVendor()` |
| 4 | Performance | Bouquet repo fetches 2× limit | Use `limit` equal to actual need |
| 5 | Clean Code | `bouquet_approval_page.dart` ~1,223 lines | Extract card, dialog, and tab widgets |
| 6 | Clean Code | Empty catch blocks | Add `debugPrint`/Crashlytics logging |

### Medium Priority

| # | Category | Item | Action |
|---|----------|------|--------|
| 7 | Security | Super admin email hardcoded | Move to `--dart-define` or env |
| 8 | Performance | Missing `const` | Run `dart fix` and add `const` where applicable |
| 9 | Clean Code | `landing_page.dart` ~880 lines | Extract sections into separate widgets |
| 10 | Clean Code | Input validation | Add validators before Firestore writes |
| 11 | Clean Code | Error handling | Centralize logging and user-facing error messages |

### Low Priority

| # | Category | Item | Action |
|---|----------|------|--------|
| 12 | Security | WhatsApp number hardcoded | Consider env/config |
| 13 | Performance | ConnectivityService disposal | Add `ref.onDispose` if provider lifecycle matters |
| 14 | Performance | Image decode on main thread | Use `compute()` for large images |
| 15 | Clean Code | Duplicate super-admin check | Centralize in `AuthRepository` |
| 16 | Clean Code | Provider organization | Add barrel file and brief docs |

---

## 5. Positive Highlights

- Firestore rules use `isAdmin()`, `isVendor()`, `isOwner()` helpers and restrict collections appropriately (users, orders, products, bouquets, admins).
- Paginated product loading with `getBouquetsPage` and infinite scroll.
- Image compression (WebP, size limits) before upload.
- `mounted` checks before `setState`/navigation after async gaps.
- Riverpod used with `autoDispose` for user-scoped data and `keepAlive` for cached lists.
- Consistent `cached_network_image` usage for remote images.
- VideoPlayerController disposed in `_HeroSection`.

---

*Generated as part of a Security, Performance, and Clean Code audit. Apply changes incrementally and test after each modification.*
