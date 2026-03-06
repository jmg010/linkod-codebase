# Firebase Storage setup (Pay As You Go)

This app uses **Firebase Storage** for image uploads and downloads. Your project already uses the bucket `linkod-db.firebasestorage.app` (see `lib/firebase_options.dart`).

## 1. Enable Storage in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) → your project **linkod-db**.
2. Go to **Build** → **Storage**.
3. Click **Get started**.
4. Choose **Production mode** (we use custom rules from the repo).
5. Pick a location (e.g. **asia-southeast1** to match Firestore).
6. Create the bucket.

## 2. Deploy Storage rules

Storage rules are in the **admin** repo. From the admin codebase root:

```bash
cd d:\GitHub\linkod_admin\linkod-admincodebase
firebase deploy --only storage
```

Rules allow:
- **proof/** – authenticated users upload proof of residence (read: authenticated).
- **profiles/{userId}** – user can write their own profile image (read: public).
- **posts/** and **products/** – authenticated upload, public read.

Size limits: 10 MB for proof/post/product images, 5 MB for profile.

## 3. What’s wired in the app

| Feature | Upload | Download |
|--------|--------|----------|
| **Proof of residence** (create account) | Yes → `proof/{uid}_{ts}.jpg`; URL in `awaitingApproval.proofOfResidenceUrl` | Admin/app shows via `Image.network(url)` |
| **Re-apply proof** | Yes → same path; URL in `users.proofOfResidenceUrl` | Same |
| **Profile photo** (edit profile) | Yes → `profiles/{uid}.jpg`; URL in `users.profileImageUrl` | Menu and profile use `profileImageUrl` |
| **Post/announcement images** | Yes → `posts/{uid}_{ts}_{i}.jpg`; URLs in post `imageUrls` | Post card and detail use `Image.network` |
| **Product images** | Yes → `products/{uid}_{ts}_{i}.jpg`; URLs in product `imageUrls` | Product list/detail use `Image.network` |

Download is always via the stored URL (no extra Storage API in the app).

## 4. Dependencies

- **linkod-codebase**: `firebase_storage: ^12.3.0` in `pubspec.yaml`. Run `flutter pub get`.
- **linkod-admin**: no code changes; only `firebase.json` and `storage.rules` for deploy.

## 5. Pay As You Go

Storage and bandwidth are billed per use. Keep image sizes reasonable (the app uses `imageQuality: 80`–`85` and optional `maxWidth`/`maxHeight` where applicable) to control costs.
