# Notification System Test Plan

## Overview
This document outlines test cases for the LinkOD notification system covering push notifications (FCM) and in-app red indicator notifications.

## Test Environment Setup

### Prerequisites
- [ ] Firebase Emulator Suite running (Firestore, Functions, Auth)
- [ ] Two test user accounts (User A, User B)
- [ ] Admin panel access
- [ ] Physical device or emulator with FCM token registered

### Firebase Emulator Commands
```bash
# Start emulators
firebase emulators:start --only firestore,functions

# Deploy rules to emulator
firebase emulators:exec --only firestore 'firebase deploy --only firestore:rules'
```

---

## 1. Post Interactions Test Cases

### TC-001: Like Notification
**Steps:**
1. User A creates a new post
2. User B likes User A's post

**Expected Results:**
- [ ] Firestore: `notifications` collection has new doc with:
  - `userId`: User A's UID
  - `senderId`: User B's UID
  - `type`: `'like'`
  - `postId`: Post ID
  - `isRead`: `false`
- [ ] Firestore: User A's `unreadNotificationCount` incremented by 1
- [ ] FCM: User A receives push notification: "New like"
- [ ] Red indicator: User A sees badge on notifications icon

**Navigation Test:**
- [ ] Tap notification → Opens `PostDetailScreen` with the post

---

### TC-002: Comment Notification
**Steps:**
1. User A creates a post
2. User B comments on the post

**Expected Results:**
- [ ] Firestore: Notification doc created with `type: 'comment'`
- [ ] `unreadNotificationCount` incremented
- [ ] FCM push received

**Navigation Test:**
- [ ] Tap notification → Opens `PostDetailScreen` with `openCommentsOnLoad: true`

---

## 2. Product/Marketplace Test Cases

### TC-003: Product Message Notification
**Steps:**
1. User A creates a product listing
2. User B sends a message about the product

**Expected Results:**
- [ ] Firestore: Notification doc with:
  - `type`: `'product_message'`
  - `productId`: Product ID
  - `messageId`: Message document ID
- [ ] Seller's (User A) `unreadNotificationCount` incremented
- [ ] FCM push: "Product message"

**Navigation Test:**
- [ ] Tap notification → Opens `ProductDetailScreen` with message thread

---

### TC-004: Reply Notification (NEW - Priority Test)
**Steps:**
1. User A sends a message on a product
2. User B replies to User A's message (with `parentId`)

**Expected Results:**
- [ ] Firestore: Notification doc with:
  - `type`: `'reply'`
  - `productId`: Product ID
  - `parentMessageId`: User A's original message ID
  - `userId`: User A's UID (parent message sender)
- [ ] User A's `unreadNotificationCount` incremented
- [ ] FCM push: "Reply" - "User B replied to your message"

**Navigation Test:**
- [ ] Tap notification → Opens `ProductDetailScreen` showing the reply

---

### TC-005: Self-Reply (No Notification)
**Steps:**
1. User A sends a message
2. User A replies to their own message

**Expected Results:**
- [ ] NO notification created (sender == parent sender)
- [ ] NO FCM push sent
- [ ] Message still saved to Firestore

---

### TC-006: Product Approved Notification
**Steps:**
1. User submits product (status: Pending)
2. Admin approves via Approvals screen

**Expected Results:**
- [ ] FCM push with `type: 'product_approved'`
- [ ] No Firestore notification doc (admin-initiated only)
- [ ] Push title: "Listing approved"

**Navigation Test:**
- [ ] Tap → Opens `ProductDetailScreen`

---

## 3. Task/Errand Test Cases

### TC-007: Task Volunteer Notification
**Steps:**
1. User A creates an errand
2. User B volunteers

**Expected Results:**
- [ ] Firestore: `type: 'task_volunteer'` notification
- [ ] FCM push: "New volunteer"

---

### TC-008: Volunteer Accepted Notification
**Steps:**
1. User B volunteers for User A's task
2. User A accepts the volunteer

**Expected Results:**
- [ ] Firestore: `type: 'volunteer_accepted'` notification to User B
- [ ] FCM push: "Volunteer accepted"

---

### TC-009: Task Chat Message
**Steps:**
1. User A creates task, assigns to User B
2. User B sends chat message

**Expected Results:**
- [ ] Firestore: `type: 'task_chat_message'` to User A
- [ ] Task-level `unreadMessagesCount` incremented
- [ ] FCM push sent

---

## 4. Account & Admin Test Cases

### TC-010: Account Approved
**Steps:**
1. New user registers (status: Pending)
2. Admin approves via User Management

**Expected Results:**
- [ ] FCM push: `type: 'account_approved'`
- [ ] User can now login

---

### TC-011: Announcement Push
**Steps:**
1. Admin creates announcement
2. Clicks "Send as Push Notification"

**Expected Results:**
- [ ] FCM multicast to all users
- [ ] Users receive push even if app is killed

---

## 5. Edge Cases

### TC-012: No Notification on Self-Action
**Steps:**
1. User A likes their own post

**Expected:** NO notification created

---

### TC-013: Invalid FCM Token Handling
**Steps:**
1. User has invalid/expired FCM token
2. Trigger any notification

**Expected:**
- [ ] Error logged in Cloud Functions
- [ ] App doesn't crash
- [ ] Firestore notification still created

---

### TC-014: Deleted Parent Message (Reply)
**Steps:**
1. User A sends message
2. User A deletes message
3. User B tries to reply (UI shouldn't allow, but test API level)

**Expected:**
- [ ] No crash
- [ ] Reply saved but no notification (parent doesn't exist)

---

## Test Data Cleanup

After testing, clean up test data:

```javascript
// Run in Firebase Console or emulator
const db = firebase.firestore();

// Delete test notifications
await db.collection('notifications')
  .where('userId', 'in', [userA.uid, userB.uid])
  .get()
  .then(snap => snap.docs.forEach(doc => doc.ref.delete()));

// Reset unread counts
await db.collection('users').doc(userA.uid).update({
  unreadNotificationCount: 0
});
```

---

## Automated Test Commands

```bash
# Run unit tests
flutter test test/reply_notification_test.dart

# Run integration tests
flutter test test/notification_integration_test.dart

# Run all tests
flutter test
```

---

## Sign-off Checklist

- [ ] All 14 test cases passed
- [ ] Push notifications received on physical device
- [ ] Red indicator badges update correctly
- [ ] Navigation works from all notification types
- [ ] No console errors in Cloud Functions
- [ ] Firestore rules allow all expected operations
