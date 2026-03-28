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
  const payload = {
    type: toStr(data.type) || 'notification',
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

  return payload;
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
      const fcmToken = toStr(doc.data().fcmToken);
      if (fcmToken) {
        tokenEntries.push({ token: fcmToken, ref: doc.ref });
      }
    }

    if (!tokenEntries.length) {
      functions.logger.info('No valid FCM tokens found on devices', {
        notificationId,
        userId,
      });
      return;
    }

    // Defensive dedupe in case legacy docs contain repeated tokens.
    const dedupedByToken = new Map();
    for (const entry of tokenEntries) {
      if (!dedupedByToken.has(entry.token)) {
        dedupedByToken.set(entry.token, entry);
      }
    }
    const dedupedEntries = Array.from(dedupedByToken.values());

    const type = toStr(data.type) || 'notification';
    const title = titleForType(type);
    const body = toStr(data.message) || defaultBodyForType(type);
    const tokens = dedupedEntries.map((entry) => entry.token);

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: buildDataPayload(notificationId, data),
      android: {
        priority: 'high',
        collapseKey: notificationId,
      },
      apns: {
        headers: {
          'apns-collapse-id': notificationId,
        },
        payload: {
          aps: {
            sound: 'default',
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
  });
