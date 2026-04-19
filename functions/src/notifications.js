/**
 * Firebase Cloud Functions for interaction push notifications.
 *
 * Listens to notifications/{notificationId} documents and forwards each new
 * notification to all registered devices under users/{uid}/devices.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

function toStr(value) {
  if (value === null || value === undefined) return null;
  const s = String(value);
  return s.length ? s : null;
}

function titleForType(type) {
  switch (type) {
    case 'account_approved':
      return 'Account approved';
    case 'task_approved':
      return 'Errand approved';
    case 'product_approved':
      return 'Listing approved';
    case 'task_volunteer':
      return 'New volunteer';
    case 'volunteer_accepted':
      return 'You were accepted';
    case 'task_chat_message':
      return 'New task message';
    case 'product_message':
      return 'New marketplace message';
    case 'post_message':
      return 'New post message';
    case 'comment':
      return 'New comment';
    case 'like':
      return 'New like';
    case 'reply':
      return 'New reply';
    case 'announcement':
      return 'New announcement';
    default:
      return 'New notification';
  }
}

function defaultBodyForType(type) {
  switch (type) {
    case 'account_approved':
      return 'Your account has been approved. You can now sign in.';
    case 'task_approved':
      return 'Your errand post is now visible to others.';
    case 'product_approved':
      return 'Your marketplace listing is now visible to others.';
    case 'task_volunteer':
      return 'Someone volunteered for your errand.';
    case 'volunteer_accepted':
      return 'You were accepted as volunteer for an errand.';
    case 'task_chat_message':
      return 'You received a new message in an errand chat.';
    case 'product_message':
      return 'You received a new message about your product.';
    case 'post_message':
      return 'You received a new message on your post.';
    case 'comment':
      return 'Someone commented on your post.';
    case 'like':
      return 'Someone liked your post.';
    case 'reply':
      return 'Someone replied to your message.';
    case 'announcement':
      return 'A new barangay announcement is available.';
    default:
      return 'You have a new notification.';
  }
}

function buildDataPayload(notificationId, data) {
  const type = toStr(data.type) || 'notification';
  const payload = {
    type,
    notificationId: toStr(notificationId) || '',
  };

  const keys = [
    'taskId',
    'productId',
    'postId',
    'commentId',
    'messageId',
    'parentMessageId',
    'announcementId',
    'senderId',
    'userId',
  ];

  for (const key of keys) {
    const value = toStr(data[key]);
    if (value) {
      payload[key] = value;
    }
  }

  if (type === 'announcement') {
    payload.priority = toStr(data.priority) || 'high';
    payload.alertStyle = toStr(data.alertStyle) || 'announcement_priority';
    payload.attemptFullScreen = toStr(data.attemptFullScreen) || 'true';
    payload.title = toStr(data.title) || titleForType(type);
    payload.body = toStr(data.message) || defaultBodyForType(type);
  }

  return payload;
}

function buildSemanticDedupKey(notificationId, userId, data) {
  const type = toStr(data.type) || 'notification';

  // Build strong semantic keys for known notification event types so duplicate
  // docs (from legacy + new pipelines) still emit only one push.
  const taskId = toStr(data.taskId);
  const productId = toStr(data.productId);
  const postId = toStr(data.postId);
  const commentId = toStr(data.commentId);
  const messageId = toStr(data.messageId);
  const parentMessageId = toStr(data.parentMessageId);
  const announcementId = toStr(data.announcementId);
  const senderId = toStr(data.senderId);

  const partsByType = {
    task_chat_message: [userId, taskId, messageId],
    product_message: [userId, productId, messageId],
    reply: [userId, productId || postId, parentMessageId, messageId],
    comment: [userId, postId, commentId || messageId],
    like: [userId, postId, senderId],
    task_volunteer: [userId, taskId, senderId],
    volunteer_accepted: [userId, taskId, senderId],
    task_approved: [userId, taskId],
    product_approved: [userId, productId],
    announcement: [userId, announcementId],
    account_approved: [userId],
  };

  const selected = partsByType[type];
  if (selected) {
    const clean = selected
      .map((v) => (v === null || v === undefined ? '' : String(v).trim()))
      .filter((v) => v.length);
    if (clean.length === selected.length) {
      return `${type}:${clean.join(':')}`;
    }
  }

  return `notification:${notificationId}`;
}

exports.sendPushForNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationId = context.params.notificationId;
    const data = snap.data() || {};
    const userId = toStr(data.userId);

    if (!userId) {
      functions.logger.warn('Notification missing userId', { notificationId });
      return;
    }

    // Strong idempotency guard by notification id.
    const dispatchLockRef = db
      .collection('_notification_dispatch_locks')
      .doc(notificationId);
    try {
      await dispatchLockRef.create({
        notificationId,
        userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      const code = e && e.code;
      if (code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS') {
        functions.logger.info('Duplicate dispatch skipped by lock', {
          notificationId,
          userId,
        });
        return;
      }
      throw e;
    }

    // Semantic idempotency guard. For task chat messages this deduplicates by
    // user + task + message so multiple notification docs still produce one push.
    const semanticKey = buildSemanticDedupKey(notificationId, userId, data);
    const semanticLockRef = db
      .collection('_notification_dispatch_semantic_locks')
      .doc(semanticKey);

    try {
      await semanticLockRef.create({
        notificationId,
        semanticKey,
        userId,
        type: toStr(data.type) || 'notification',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      const code = e && e.code;
      if (code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS') {
        functions.logger.info('Duplicate dispatch skipped by semantic lock', {
          notificationId,
          semanticKey,
          userId,
        });
        return;
      }
      throw e;
    }

    const devicesSnap = await db
      .collection('users')
      .doc(userId)
      .collection('devices')
      .get();

    if (devicesSnap.empty) {
      functions.logger.info('No registered devices for user', {
        notificationId,
        userId,
      });
      return;
    }

    const tokenEntries = [];
    for (const doc of devicesSnap.docs) {
      const row = doc.data() || {};
      const fcmToken = toStr(row.fcmToken);
      if (fcmToken) {
        const installationId = toStr(row.installationId);
        const lastActiveRaw = row.lastActive;
        const lastActiveMs =
          lastActiveRaw && typeof lastActiveRaw.toMillis === 'function'
            ? lastActiveRaw.toMillis()
            : 0;
        tokenEntries.push({
          token: fcmToken,
          ref: doc.ref,
          installationId,
          lastActiveMs,
        });
      }
    }

    if (!tokenEntries.length) {
      functions.logger.info('No valid FCM tokens found on devices', {
        notificationId,
        userId,
      });
      return;
    }

    // Prefer one token per installationId when present, otherwise dedupe by token.
    const dedupedByTarget = new Map();
    for (const entry of tokenEntries) {
      const key = entry.installationId
        ? `install:${entry.installationId}`
        : `token:${entry.token}`;
      const existing = dedupedByTarget.get(key);
      if (!existing || entry.lastActiveMs > existing.lastActiveMs) {
        dedupedByTarget.set(key, entry);
      }
    }
    const dedupedEntries = Array.from(dedupedByTarget.values());

    const type = toStr(data.type) || 'notification';
    const title = titleForType(type);
    const body = toStr(data.message) || defaultBodyForType(type);
    const tokens = dedupedEntries.map((entry) => entry.token);

    const dataPayload = buildDataPayload(notificationId, data);
    const isPriorityAnnouncement =
      dataPayload.type === 'announcement' &&
      dataPayload.alertStyle === 'announcement_priority';

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: dataPayload,
      android: {
        priority: 'high',
        collapseKey: notificationId,
        notification: {
          tag: notificationId,
          channelId: isPriorityAnnouncement
            ? 'linkod_announcements_priority'
            : 'linkod_announcements',
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': notificationId,
        },
        payload: {
          aps: {
            sound: 'default',
            'thread-id': notificationId,
          },
        },
      },
    });

    const staleRefs = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error && result.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        staleRefs.push(dedupedEntries[index].ref);
      }
    });

    if (staleRefs.length) {
      const batch = db.batch();
      staleRefs.forEach((ref) => batch.delete(ref));
      await batch.commit();
    }

    functions.logger.info('Notification push attempted', {
      notificationId,
      userId,
      totalTokens: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      staleTokensRemoved: staleRefs.length,
    });

    await dispatchLockRef.set(
      {
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      },
      { merge: true },
    );

    await semanticLockRef.set(
      {
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      },
      { merge: true },
    );
  });
