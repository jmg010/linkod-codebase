# OTP Deployment & Testing Checklist

Complete checklist for deploying and testing the OTP push notification system.

## Pre-Deployment Setup

### 1. Project Dependencies ✓

- [x] `firebase_core` package
- [x] `firebase_messaging` package
- [x] `cloud_firestore` package
- [x] `flutter_local_notifications` package
- [x] `firebase_functions` (Node.js in `functions/`)
- [x] `firebase-admin` (in `functions/`)

Run: `flutter pub get` and `cd functions && npm install`

### 2. Firebase Project Configuration

- [ ] Firebase Project created at console.firebase.google.com
- [ ] Firestore Database created (select region: US-Central or Europe-West)
- [ ] Cloud Messaging enabled (Settings > Cloud Messaging)
- [ ] Cloud Functions enabled (requires Blaze billing plan)
- [ ] Authentication service enabled

### 3. Android Setup

- [ ] Google Services JSON downloaded (`google-services.json`)
- [ ] File placed in `android/app/google-services.json`
- [ ] Google Services plugin configured in `android/app/build.gradle`:
  ```gradle
  plugins {
      id 'com.google.gms.google-services'
  }
  ```
- [ ] Firebase messaging dependency in `android/app/build.gradle`:
  ```gradle
  dependencies {
      implementation 'com.google.firebase:firebase-messaging'
  }
  ```
- [ ] App target Android API 16+ (for Firebase)
- [ ] Notification icon exists: `android/app/src/main/res/mipmap/ic_launcher.png`

### 4. iOS Setup

- [ ] Development Team selected in Xcode
- [ ] Push Notification capability added in Xcode
- [ ] Background Modes > Remote notifications enabled
- [ ] iOS platform minimum version: 11.0 or higher
- [ ] CocoaPods dependencies updated: `cd ios && pod install`
- [ ] APNs certificate configured in Firebase Console

### 5. Code Files Created

- [x] `lib/services/otp_service.dart` - OTP state management
- [x] `lib/screens/phone_registration_screen.dart` - Phone input
- [x] `lib/screens/otp_verification_screen.dart` - OTP verification
- [x] `lib/services/push_notification_handler.dart` - UPDATED for OTP
- [x] `functions/src/otp.js` - Cloud Functions
- [x] `functions/src/index.js` - Function exports

### 6. Configuration Files

- [ ] `firestore.rules` updated with OTP security rules
- [ ] `.firebaserc` configured for correct Firebase project
- [ ] `firebase.json` configured (usually auto-generated)

## Deployment Steps

### Step 1: Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies (if not done)
npm install

# Deploy OTP functions
firebase deploy --only functions:requestOtp,functions:verifyOtp,functions:resendOtp,functions:cleanupExpiredOtps

# Or deploy all functions
firebase deploy --only functions
```

**Expected Output**:

```
✔  Deploy complete!

Functions deployed:
  requestOtp
  verifyOtp
  resendOtp
  cleanupExpiredOtps
```

### Step 2: Deploy Firestore Security Rules

```bash
# From project root
firebase deploy --only firestore:rules
```

**Expected Output**:

```
✔  Deploy complete!
i  firestore: Rules updated successfully.
```

### Step 3: Set Up Cloud Scheduler (Optional but Recommended)

For automatic cleanup of expired OTP records:

```bash
# Deploy scheduler function
firebase deploy --only functions:cleanupExpiredOtps
```

Then in Google Cloud Console:

1. Go to Cloud Scheduler
2. Create Job:
   - Name: `cleanup-expired-otps`
   - Frequency: `0 * * * *` (every hour)
   - Timezone: Your timezone
   - HTTP target: Cloud Function URL

### Step 4: Verify Deployment

Check Firebase Console:

1. **Cloud Functions**: All 4 functions should show as deployed
2. **Firestore**: `pendingOtps` and `verifiedPhones` collections exist
3. **Security Rules**: Verify rules were updated

## Local Testing

### Test 1: Verify Flutter App Builds

```bash
flutter pub get
flutter clean
flutter pub get
flutter build apk  # Android
# or
flutter build ios  # iOS
```

### Test 2: Run App in Debug Mode

```bash
flutter run -v
```

Monitor logs for:

```
I/firebase-messaging: FCMToken: [shows your FCM token]
I/flutter: OTP Service initialized
```

### Test 3: Test PhoneRegistrationScreen

1. Navigate to `PhoneRegistrationScreen`
2. Enter valid phone number: `+1234567890`
3. Click "Send OTP"
4. In Firebase Console > Cloud Functions > Logs, verify function executed:
   ```
   OTP requested for phone: +1234567890
   ```

**Expected**: No errors, function completes in <5 seconds

### Test 4: Test OTP Delivery

1. After step 3, watch device notification area
2. OTP notification should arrive within 3-5 seconds
3. Check Firebase Console > Cloud Functions > Logs:
   ```
   FCM message sent successfully
   ```

### Test 5: Test OTP Auto-Fill

1. If notification arrived, check `OtpVerificationScreen`
2. OTP fields should be auto-filled with 6 digits
3. Countdown timer should show ~2:00 remaining

### Test 6: Manual OTP Entry

1. Clear the OTP fields
2. Manually enter: `123456` (or whatever OTP shows in logs)
3. Countdown should decrease
4. Click "Verify"

**Expected**: Verification succeeds if: OTP matches, is not expired, and record exists

### Test 7: OTP Expiration

1. Request new OTP
2. Try to verify after 2+ minutes
3. Should show error: "OTP has expired"

### Test 8: Rate Limiting

1. Request OTP 3 times in quick succession (same phone)
2. On 4th request, should show: "Too many OTP requests"
3. Wait 30 minutes, then can request again

### Test 9: Wrong OTP Verification

1. Request OTP
2. Intentionally enter wrong 6 digits
3. Click "Verify"

**Expected**: Error "OTP not found or invalid"

### Test 10: Resend OTP

1. Request OTP
2. Wait for first OTP
3. Click "Resend Code" before expiration
4. New OTP should arrive

## Production Testing Checklist

### Environment Setup

- [ ] Firebase project is in production (not development/test)
- [ ] Billing enabled (Blaze plan for Cloud Functions)
- [ ] Cloud Functions region set (us-central1 or closest to users)
- [ ] Firestore region set (same as Functions)
- [ ] Firebase API keys restricted (Settings > API Keys)

### Device Testing

- [ ] Test on real Android device (not emulator)
- [ ] Test on real iOS device (not simulator)
- [ ] Device notifications enabled in system settings
- [ ] App has notification permission granted
- [ ] Device has active internet connection
- [ ] Google Play Services installed (Android)

### Notification Testing

- [ ] Foreground notification (app open): Shows toast
- [ ] Background notification (app minimized): Shows system notification
- [ ] Terminated notification (app closed): Shows system notification
- [ ] Tap while foreground: Focuses screen
- [ ] Tap while background: Brings app to foreground
- [ ] Multiple notifications: No loss of older notifications

### OTP Flow Testing

- [ ] Phone number validated (shows error for invalid)
- [ ] FCM token retrieved successfully
- [ ] OTP request sent to backend
- [ ] OTP arrives within 5 seconds
- [ ] OTP auto-fills in verification screen
- [ ] Countdown timer accurate
- [ ] OTP expires after 2 minutes (tested with real wait)
- [ ] Verification succeeds with correct OTP
- [ ] Verification fails with wrong OTP
- [ ] Expired OTP shows error
- [ ] Resend button works
- [ ] Rate limiting prevents 4th request in 30 min

### Backend Testing

- [ ] Cloud Functions execute without errors
- [ ] Firestore documents created properly
- [ ] Firestore security rules allow function access
- [ ] Rate limiting working in backend
- [ ] OTP records cleaned up after 24 hours
- [ ] Logs show all operations

### Performance Testing

- [ ] OTP request < 2 seconds (backend)
- [ ] OTP delivery < 5 seconds (FCM)
- [ ] OTP verification < 1 second
- [ ] UI responsive during OTP operations
- [ ] No memory leaks with repeated OTP requests

### Security Testing

- [ ] OTP not sent in notification body (data message only)
- [ ] OTP expires properly
- [ ] Old OTP cannot be reused
- [ ] Rate limiting prevents brute force
- [ ] Phone numbers not exposed in logs
- [ ] Security rules prevent direct collection access
- [ ] Firebase credentials not leaked in app logs

## Monitoring Production

### Daily Checks

```bash
# Check Cloud Functions logs
firebase functions:log --limit 50

# Check Firestore usage
# Go to Firebase Console > Firestore > Monitoring
```

### Weekly Checks

- [ ] Cloud Functions execution time
- [ ] Firestore storage usage (cleanup working?)
- [ ] Error rate in Cloud Functions logs
- [ ] FCM delivery success rate

### Monthly Checks

- [ ] Cost analysis (Cloud Functions, Firestore)
- [ ] Email alerts setup for errors
- [ ] Clean up old OTP records (verify cleanup function)
- [ ] Review security rules (no changes to permissions)

## Troubleshooting

### Problem: "Field '<field>' requires a Timestamp value" in Firestore

**Solution**:

- Use `admin.firestore.Timestamp.now()` instead of `Date`
- Use `admin.firestore.Timestamp.fromDate(date)`

### Problem: Cloud Function exceeds 60 second timeout

**Solution**:

- Increase timeout in Cloud Functions settings
- Optimize Firestore queries (add indexes)
- Check network connectivity

### Problem: "Permission denied" when accessing pendingOtps

**Solution**:

- Verify Firestore rules are deployed
- Check security rules allow Cloud Function service account
- Ensure `allow read, write: if false;` for client access

### Problem: OTP not arriving

**Cause**: FCM token invalid or revoked

**Solution**:

1. Check FCM token in Firestore (`users/{uid}/devices`)
2. Regenerate token: app restart or `FirebaseMessaging.instance.deleteToken()`
3. Check Notification permissions granted
4. Check Firebase Console > Cloud Messaging API enabled

### Problem: Auto-fill not working

**Cause**: `OtpService.otpStream` not being listened to

**Solution**:

1. Verify `_listenForOtpFromFcm()` called in `OtpVerificationScreen.initState()`
2. Check `OtpService.instance.handleOtpFromFcm()` called in handler
3. Verify OTP data extracted from `message.data`

### Problem: Rate limiting too aggressive

**Solution**:

- Change `MAX_OTP_REQUESTS_PER_PERIOD` in `otp.js`
- Change `RATE_LIMIT_PERIOD_MINUTES` in `otp.js`
- Deploy updated function

### Problem: OTP expiration time wrong

**Cause**: Device time out of sync

**Solution**:

- Use server timestamp: `admin.firestore.Timestamp.now()`
- Compare with Firestore timestamp on client/server
- Never use device `DateTime` for comparison

## Rollback Plan

If production issues occur:

### Immediate Actions

1. Disable OTP registration UI
2. Rollback Cloud Functions to previous version
3. Rollback Firestore rules if needed
4. Monitor Cloud Functions logs

### Rollback Commands

```bash
# Revert function to previous version
firebase functions:delete requestOtp --force
firebase deploy --only functions:requestOtp

# Revert Firestore rules
firebase deploy --only firestore:rules
```

## Sign-Off

- [ ] All tests passed
- [ ] Cloud Functions deployed
- [ ] Firestore rules updated
- [ ] Security review complete
- [ ] Production database selected
- [ ] Team trained on monitoring
- [ ] Runbook created for on-call
- [ ] Ready for production release

---

**Last Updated**: March 2026
**Tested with**: Flutter 3.x, Firebase 13.x+, Node.js 18+
