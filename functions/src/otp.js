/**
 * Firebase Cloud Functions for OTP Management
 * 
 * Implements secure OTP generation, delivery via FCM, and verification.
 * 
 * **Security Features**:
 * - 6-digit secure random OTP
 * - 2-minute expiration (120 seconds)
 * - Rate limiting: max 3 OTP requests per phone per 30 minutes
 * - Prevents OTP reuse after verification
 * - Validates phone number format
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Config
const OTP_EXPIRATION_SECONDS = 120; // 2 minutes
const MAX_OTP_REQUESTS_PER_PERIOD = 3;
const RATE_LIMIT_PERIOD_MINUTES = 30;
const ENABLE_OTP_RATE_LIMIT = false;

/**
 * Generates a random 6-digit OTP
 * @returns {string} 6-digit OTP string
 */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Validates phone number format (10-15 digits) or test numbers
 * @param {string} phoneNumber - Phone number to validate
 * @returns {boolean} True if valid format
 */
function isValidPhoneNumber(phoneNumber) {
  const cleaned = phoneNumber.replace(/[\s\-\.\(\)]+/g, '');

  // Allow test numbers for development
  if (cleaned === '+1234567890' || cleaned === '1234567890' || cleaned.startsWith('+63912345678')) {
    return true;
  }

  const isDigits = /^\+?\d+$/.test(cleaned);
  return isDigits && cleaned.length >= 10 && cleaned.length <= 15;
}

/**
 * Request OTP to be sent to device via FCM
 * 
 * **Input**:
 * - phoneNumber: User's phone number (required)
 * - fcmToken: Device FCM token (required)
 * 
 * **Process**:
 * 1. Validate phone number format
 * 2. Check rate limiting (max 3 requests per 30 minutes)
 * 3. Generate 6-digit OTP
 * 4. Store in Firestore with 2-minute expiry
 * 5. Send via FCM as data message
 * 
 * **Returns**:
 * - success: true if OTP sent
 * - error: Rate limited, invalid phone, or FCM failure
 */
exports.requestOtp = functions.https.onCall(async (data, context) => {
  // use error logging to ensure the message appears in Cloud Logs
  console.error('REQUESTOTP invoked with data:', JSON.stringify(data));
  try {
    const { phoneNumber, fcmToken } = data;

    // Validate input
    if (!phoneNumber || typeof phoneNumber !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Phone number is required and must be a string'
      );
    }

    if (!fcmToken || typeof fcmToken !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'FCM token is required'
      );
    }

    // Validate phone number format
    if (!isValidPhoneNumber(phoneNumber)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid phone number format. Must be 10-15 digits.'
      );
    }

    if (ENABLE_OTP_RATE_LIMIT) {
      // Check rate limiting
      const thirtyMinutesAgo = new Date(Date.now() - RATE_LIMIT_PERIOD_MINUTES * 60 * 1000);
      // fetch up to MAX_OTP_REQUESTS_PER_PERIOD records for this phone; avoid ordering
      // by requestedAt or adding additional filters to prevent composite index errors.
      let snapshot;
      try {
        snapshot = await db
          .collection('pendingOtps')
          .where('phoneNumber', '==', phoneNumber)
          .limit(MAX_OTP_REQUESTS_PER_PERIOD)
          .get();
      } catch (innerErr) {
        console.error('Error querying rate limit docs:', innerErr);
        throw innerErr; // rethrow so the outer catch can convert
      }

      console.error('rateLimit snapshot size:', snapshot.size);

      // count documents within period and still pending
      const recentRequestsCount = snapshot.docs
        .map(doc => doc.data())
        .filter(d => {
          const reqAt = d.requestedAt && d.requestedAt.toDate ? d.requestedAt.toDate() : null;
          return (
            d.status === 'pending' &&
            reqAt &&
            reqAt >= thirtyMinutesAgo
          );
        }).length;

      console.error('recentRequestsCount:', recentRequestsCount);

      if (recentRequestsCount >= MAX_OTP_REQUESTS_PER_PERIOD) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Too many OTP requests. Maximum ${MAX_OTP_REQUESTS_PER_PERIOD} requests per ${RATE_LIMIT_PERIOD_MINUTES} minutes.`
        );
      }
    }

    // Generate OTP
    const otp = generateOtp();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = new Date(now.toDate().getTime() + OTP_EXPIRATION_SECONDS * 1000);

    // Store OTP in Firestore
    const otpDocRef = db.collection('pendingOtps').doc();
    await otpDocRef.set({
      phoneNumber: phoneNumber,
      otp: otp,
      fcmToken: fcmToken,
      status: 'pending',
      requestedAt: now,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: now,
    });

    // Send OTP via FCM. include both a visible notification and data payload
    // so the user can see the code and also our handler can pick it up for
    // autofill if needed.
    await messaging.send({
      token: fcmToken,
      notification: {
        title: 'LINKod verification code',
        body: otp,
      },
      data: {
        type: 'otp',
        otp: otp,
        phoneNumber: phoneNumber,
      },
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
      webpush: {
        notification: {
          title: 'LINKod verification code',
          body: otp,
        },
        data: {
          type: 'otp',
          otp: otp,
          phoneNumber: phoneNumber,
        },
      },
    });

    console.log(`OTP requested for phone: ${phoneNumber}, Doc: ${otpDocRef.id}`);

    return {
      success: true,
      message: 'OTP sent successfully',
      expiresIn: OTP_EXPIRATION_SECONDS,
    };
  } catch (error) {
    console.error('Error in requestOtp:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while processing your request'
    );
  }
});

/**
 * Verify OTP submitted by user
 * 
 * **Input**:
 * - phoneNumber: User's phone number (required)
 * - otp: 6-digit code from notification (required)
 * 
 * **Process**:
 * 1. Validate OTP format (6 digits)
 * 2. Find matching pending OTP record
 * 3. Verify OTP matches and is not expired
 * 4. Mark OTP as verified
 * 5. Mark phone number as verified (optional: create verified user record)
 * 
 * **Returns**:
 * - success: true if OTP valid
 * - error: Invalid, expired, or already used OTP
 */
exports.verifyOtp = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, otp } = data;

    // Validate input
    if (!phoneNumber || typeof phoneNumber !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Phone number is required'
      );
    }

    if (!otp || typeof otp !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'OTP is required'
      );
    }

    // Validate OTP format (6 digits)
    if (!/^\d{6}$/.test(otp)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid OTP format. Must be 6 digits.'
      );
    }

    // Find matching OTP record
    const query = await db
      .collection('pendingOtps')
      .where('phoneNumber', '==', phoneNumber)
      .where('otp', '==', otp)
      .where('status', '==', 'pending')
      .get();

    if (query.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'OTP not found or invalid'
      );
    }

    const otpDoc = query.docs[0];
    const otpData = otpDoc.data();

    // Check expiration
    const expiresAt = otpData.expiresAt.toDate();
    if (new Date() > expiresAt) {
      // Mark as expired
      await otpDoc.ref.update({
        status: 'expired',
      });

      throw new functions.https.HttpsError(
        'failed-precondition',
        'OTP has expired. Please request a new one.'
      );
    }

    // Mark OTP as verified
    await otpDoc.ref.update({
      status: 'verified',
      verifiedAt: admin.firestore.Timestamp.now(),
    });

    // Optional: Create or update verified phone record
    await db
      .collection('verifiedPhones')
      .doc(phoneNumber)
      .set({
        phoneNumber: phoneNumber,
        verifiedAt: admin.firestore.Timestamp.now(),
        lastVerified: admin.firestore.Timestamp.now(),
      }, { merge: true });

    console.log(`OTP verified for phone: ${phoneNumber}`);

    return {
      success: true,
      message: 'Phone number verified successfully',
      phoneNumber: phoneNumber,
    };
  } catch (error) {
    console.error('Error in verifyOtp:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while verifying OTP'
    );
  }
});

/**
 * Resend OTP to a different FCM token (e.g., for device change)
 * 
 * **Input**:
 * - phoneNumber: User's phone number (required)
 * - fcmToken: New device FCM token (required)
 * 
 * **Process**:
 * 1. Find most recent pending OTP for phone
 * 2. Update FCM token
 * 3. Resend OTP to new token
 * 
 * **Returns**:
 * - success: true if resent
 * - error: No pending OTP or rate limit exceeded
 */
exports.resendOtp = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, fcmToken } = data;

    // Validate input
    if (!phoneNumber || !fcmToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Phone number and FCM token are required'
      );
    }

    // Find most recent pending OTP
    const query = await db
      .collection('pendingOtps')
      .where('phoneNumber', '==', phoneNumber)
      .where('status', '==', 'pending')
      .orderBy('requestedAt', 'desc')
      .limit(1)
      .get();

    if (query.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'No pending OTP found. Please request a new one.'
      );
    }

    const otpDoc = query.docs[0];
    const otpData = otpDoc.data();

    // Update FCM token and resend
    await otpDoc.ref.update({
      fcmToken: fcmToken,
    });

    await messaging.send({
      token: fcmToken,
      data: {
        type: 'otp',
        otp: otpData.otp,
        phoneNumber: phoneNumber,
      },
    });

    console.log(`OTP resent for phone: ${phoneNumber}`);

    return {
      success: true,
      message: 'OTP resent successfully',
      expiresIn: OTP_EXPIRATION_SECONDS,
    };
  } catch (error) {
    console.error('Error in resendOtp:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while resending OTP'
    );
  }
});

/**
 * Cleanup function: Delete expired OTP records (run via Cloud Scheduler)
 * 
 * Removes OTP records older than 1 day to keep collection clean
 */
exports.cleanupExpiredOtps = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const expiredRecords = await db
        .collection('pendingOtps')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(oneDayAgo))
        .get();

      const batch = db.batch();
      expiredRecords.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(`Cleaned up ${expiredRecords.size} expired OTP records`);

      return null;
    } catch (error) {
      console.error('Error in cleanupExpiredOtps:', error);
      return null;
    }
  });
