# Follower Feature Plan (Facebook-like, Additive-Only)

Date: 2026-04-07
Scope: Resident app (`linkod-codebase`) + existing Cloud Functions notification pipeline.
Constraint: Add new collections/services/widgets/functions only. No broad refactor of current post/notification architecture.

## 1) Goals

1. Residents can `Follow` and `Unfollow` sellers (and optionally any post author if desired).
2. When followed seller creates a new post, followers receive push notifications.
3. UX should feel Facebook-like:
   - Follow button on author/seller surfaces.
   - Follower count and following state are visible.
   - Follow actions are instant and reversible.
4. Use the current pattern where writing a document in `notifications` triggers push dispatch.

## 2) Existing Architecture Fit (Why this is additive)

You already have:

1. `notifications/{notificationId}` as single source for push intents.
2. Cloud Function trigger `sendPushForNotification` in `functions/src/notifications.js` that fans out to all `users/{uid}/devices/*` tokens with dedup/lock handling.
3. Client-side push navigation that already supports `postId`, `notificationId`, and type-based handling.
4. Post creation in `PostsService.createPost(...)` and UI in `CreatePostScreen`.

Result: follower notifications can be implemented by adding:

1. A follower graph data model in Firestore.
2. A trigger/service that creates `notifications` docs for followers when a post is created.
3. Lightweight UI additions for follow/unfollow state.

No need to redesign push architecture.

## 3) Data Model (Recommended)

Use a denormalized dual-write model for efficient queries in both directions.

### 3.1 Collections/Subcollections

1. `users/{sellerId}/followers/{followerId}`
2. `users/{followerId}/following/{sellerId}`

Document shape (both sides):

- `sellerId` (string)
- `followerId` (string)
- `createdAt` (serverTimestamp)
- `sellerNameSnapshot` (string, optional)
- `followerNameSnapshot` (string, optional)
- `sellerAvatarSnapshot` (string, optional for future)

### 3.2 Counters on `users/{uid}`

Add optional counter fields:

- `followersCount` (int)
- `followingCount` (int)

Update with transaction/batch during follow/unfollow to support instant UI badges and profile stats.

### 3.3 Notification doc type

Add new notification `type` values:

- `new_post_from_following`
- (optional future) `new_product_from_following`

Notification payload fields:

- `userId` (receiver/follower)
- `senderId` (seller/post author)
- `type`
- `postId`
- `isRead: false`
- `message` (e.g., `"<SellerName> posted a new update"`)
- `createdAt`

## 4) Firestore Security Rules Changes (Additive)

Update `firestore.rules` with these new blocks:

1. `match /users/{userId}/followers/{followerId}`
   - Read: signed-in users (or owner-only if stricter privacy desired).
   - Create/Delete: only authenticated user where `request.auth.uid == followerId`.
   - Prevent self-follow by validating `userId != followerId`.

2. `match /users/{userId}/following/{sellerId}`
   - Read: owner-only (`request.auth.uid == userId`) or signed-in if social graph is public.
   - Create/Delete: only owner (`request.auth.uid == userId`) and `sellerId != userId`.

3. Allow notification create for new type:
   - Easiest path: done by Cloud Functions Admin SDK (bypasses rules).
   - If client-side fanout is used, extend `notifications` create rule for `new_post_from_following` and validate relationship.

Recommended: do fanout in Cloud Function to avoid heavy client writes and rules complexity.

## 5) Cloud Functions Plan (Preferred server-side fanout)

## 5.1 Trigger choice

Create a new function trigger:

- `onCreate('posts/{postId}')`

When a post is created:

1. Read post author `sellerId = post.userId`.
2. Query `users/{sellerId}/followers` (page in batches).
3. For each follower, write one document into `notifications`.
4. Existing `sendPushForNotification` trigger handles delivery.

This follows Firebase guidance for event-driven fanout and keeps mobile client thin.

## 5.2 Idempotency and duplicate prevention

Because Firestore triggers are at-least-once:

1. Create deterministic notification IDs for follower-post pairs:
   - Example ID: `follow_post_${postId}_${followerId}`
2. Use `.create(...)` semantics (fails if exists), or lock collection pattern.
3. Skip if followerId equals sellerId.

## 5.3 Scale and chunking

For high-follower sellers:

1. Process followers in pages (e.g., 300-500 docs per batch).
2. Use batched writes for notification docs.
3. If needed, hand off to Cloud Tasks for large fanout later.

Given current app scale, direct paged batching is sufficient for phase 1.

## 6) Mobile App Additions (No Refactor)

## 6.1 New service: `followers_service.dart`

Add methods:

1. `Future<void> followSeller(String sellerId, {String? sellerName})`
2. `Future<void> unfollowSeller(String sellerId)`
3. `Stream<bool> isFollowingStream(String sellerId)`
4. `Stream<int> followersCountStream(String sellerId)`
5. `Stream<List<String>> followingIdsStream(String userId)` (for future feed ranking/filter)

Implementation notes:

1. Use Firestore batch/transaction to dual-write `followers` + `following` and update counters.
2. Guard self-follow.
3. Keep method signatures small and consistent with current service style.

## 6.2 UI placement (Facebook-like)

Phase 1 placement (minimal surface changes):

1. In post header widget (`_PostHeader` in `post_card.dart`):
   - If current user is not post owner, show compact `Follow`/`Following` button next to author metadata.
2. In resident profile dialog (optional in same phase):
   - Add larger primary follow button and follower count.

Button behavior:

1. Tap `Follow` -> optimistic update to `Following`, revert on failure.
2. Tap `Following` -> confirm unfollow bottom sheet (Facebook-like safeguard).

## 6.3 Notification handling in app

`PushNotificationHandler` already routes notification types with `postId` and `notificationId`.

Add one type mapping in local title/body fallback:

- `new_post_from_following` => title `New post from someone you follow`

Navigation can reuse existing `postId` handling; no new deep-link screen needed.

## 7) Feed Behavior (Facebook-like, but incremental)

Phase 1 (fastest delivery):

1. Keep current feed query unchanged.
2. Add social signal only through notifications.

Phase 2 (optional enhancement):

1. Add `Following` feed filter/tab (show only posts where `post.userId in followingIds`).
2. Add ranking boost for followed authors in Home feed (if sorting layer exists).

This keeps phase 1 minimal-risk and additive.

## 8) Firestore Indexes

Likely new indexes needed:

1. `users/{uid}/followers` ordered by `createdAt` desc (if you show follower list with recency).
2. `users/{uid}/following` ordered by `createdAt` desc.
3. If adding filtered notifications view by type + createdAt, index for:
   - `notifications`: `userId ASC, isRead ASC, createdAt DESC` (many already implicitly needed)
   - or `userId ASC, type ASC, createdAt DESC` for follower-specific inbox sections.

Keep index additions explicit in `firestore.indexes.json` only for queries actually used.

## 9) Rollout Plan (Phased)

## Phase A: Data + Rules + Service skeleton

1. Add rules for `followers` and `following` subcollections.
2. Add `FollowersService` with follow/unfollow/isFollowing/followerCount.
3. Add basic unit checks for self-follow and duplicate follow.

Exit criteria:

- Follow/unfollow works across app restarts.
- Counts update correctly.

## Phase B: UI integration

1. Add Follow button to post header.
2. Connect button to `FollowersService` stream + actions.
3. Add loading/optimistic/error states.

Exit criteria:

- User can follow from feed with <2 taps.
- State remains consistent after refresh.

## Phase C: Server fanout notifications

1. Add Cloud Function: `onCreate(posts/{postId})` -> create follower notifications.
2. Add dedup deterministic notification IDs.
3. Verify push received by multiple follower test devices.

Exit criteria:

- New seller post generates notifications for followers.
- No duplicate push for same follower/post.

## Phase D: Hardening and analytics

1. Add logs for fanout counts and failures.
2. Add monitoring for stale tokens (already handled by existing push function).
3. Add basic metrics fields (optional): `followerFanoutCount` on post doc.

Exit criteria:

- Observability available for support/debugging.

## 10) Testing Checklist

Functional:

1. Follow seller from post card.
2. Unfollow seller from `Following` state.
3. Cannot follow self.
4. Duplicate follow does not create duplicate docs.
5. Seller posts new content -> follower gets one push.
6. Push tap opens post detail.

Edge cases:

1. Follower has no devices registered -> notification doc still created, no crash.
2. Seller with many followers -> batches process without timeout.
3. Network interruption during follow -> UI rollback and snackbar error.

Security:

1. User cannot create follower docs for another user.
2. User cannot forge follow relation where `followerId != request.auth.uid`.

## 11) Risk Assessment and Mitigation

1. Risk: Trigger duplicate execution.
   - Mitigation: deterministic notification IDs + create-only semantics.
2. Risk: Large fanout write load.
   - Mitigation: paged batched writes, later Cloud Tasks if needed.
3. Risk: Rules complexity for client-created cross-user notifications.
   - Mitigation: prefer server-created notification docs.
4. Risk: Counter drift.
   - Mitigation: transaction updates; optional periodic repair script.

## 12) Internet-Based Guidance Applied

The plan aligns with Firebase docs best practices:

1. Firestore event triggers are at-least-once -> idempotent function design required.
2. Use batch writes for multi-document atomic updates where no reads are required.
3. Keep Firestore documents lightweight; use subcollections for relationship graphs.
4. FCM interaction handling should support foreground/background/terminated states and deep linking by data payload (already present in your app).

## 13) Exact Additive File Targets (Implementation phase)

Resident app:

1. Add `lib/services/followers_service.dart`
2. Update `lib/widgets/post_card.dart` (inject follow button in `_PostHeader`)
3. Optional update `lib/widgets/resident_profile_dialog.dart` (follow CTA)
4. Optional update `lib/services/push_notification_handler.dart` (type label fallback)

Backend:

1. Add `functions/src/follower_notifications.js`
2. Update `functions/src/index.js` exports

Config:

1. Update `firestore.rules` with `followers/following` matches
2. Update `firestore.indexes.json` only as required by new queries

## 14) Suggested First Implementation Slice (smallest valuable)

If you want to start immediately with minimum risk:

1. Build `FollowersService` + rules.
2. Add Follow button in `post_card.dart`.
3. Add Cloud Function post-create fanout with deterministic notification IDs.

This yields full user-visible value (follow + notified on new posts) without touching existing feed architecture.
