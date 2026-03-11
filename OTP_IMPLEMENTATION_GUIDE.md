# OTP Push Notification Implementation Guide

Complete guide to implementing secure OTP verification via FCM push notifications in the LINKod Flutter Firebase app.

## Overview

This implementation provides:

- ✅ **6-digit secure OTP** generation
- ✅ **FCM delivery** (data messages, no SMS)
- ✅ **2-minute expiration** for OTP codes
- ✅ **Rate limiting** (max 3 requests per phone per 30 minutes)
- ✅ **Firestore storage** for temporary OTP records
- ✅ **Firebase Cloud Functions** for backend logic
- ✅ **Auto-fill UI** when OTP is received
- ✅ **Countdown timer** showing expiration

## Architecture

```
User Phone Number
      ↓
[PhoneRegistrationScreen] → Gets FCM Token
      ↓
requestOtp() Cloud Function
      ↓
Generates 6-digit OTP + Stores in Firestore
      ↓
Sends OTP via FCM Data Message
      ↓
[OtpVerificationScreen] ← App receives push via PushNotificationHandler
      ↓
User enters OTP (or auto-filled from notification)
      ↓
verifyOtp() Cloud Function
      ↓
Validates OTP + Marks as verified
      ↓
Account marked as verified → Registration continues
```

## Project Setup

### 1. Flutter Dependencies

The project already has the necessary dependencies. Verify in `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^latest
  firebase_messaging: ^latest
  cloud_firestore: ^latest
  flutter_local_notifications: ^latest
  shared_preferences: ^latest
```

### 2. Firebase Project Configuration

Ensure your Firebase project has:

1. **Cloud Messaging enabled** - Check Firebase Console > Project Settings > Cloud Messaging
2. **Firestore Database** - Create if not exists
3. **Cloud Functions** - Enable billing (Cloud Functions require Blaze plan)

### 3. Android Setup (`android/app/build.gradle`)

Ensure Google Services plugin is configured:

```gradle
plugins {
    id 'com.google.gms.google-services'
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging'
    // ... other Firebase deps via FlutterFire CLI
}
```

### 4. iOS Setup (ios/Podfile)

Min iOS 11.0 required for FCM:

```ruby
platform :ios, '11.0'
```

Capabilities needed:

- Background fetch
- Remote notifications (push notifications)

Configure in Xcode:

1. Target > Signing & Capabilities
2. Add "Push Notifications" capability
3. Add "Background Modes" > "Remote notifications"

## File Structure

```
lib/
├── services/
│   ├── otp_service.dart              [NEW] OTP state management
│   ├── push_notification_handler.dart [UPDATED] Handle OTP messages
│   └── fcm_token_service.dart        [No changes needed]
└── screens/
    ├── phone_registration_screen.dart [NEW] Phone number input
    └── otp_verification_screen.dart   [NEW] OTP entry & verification

functions/
└── src/
    ├── otp.js                        [NEW] Cloud Functions for OTP
    └── index.js                      [UPDATE] Export OTP functions
```

## Implementation Details

### Frontend: OTP Service

**File**: `lib/services/otp_service.dart`

Manages OTP state:

- Receives OTP from FCM push
- Stores OTP temporarily (2 minutes valid)
- Verifies OTP against backend
- Manages OTP stream for auto-display

Key methods:

```dart
// Called by PushNotificationHandler when OTP arrives
OtpService.instance.handleOtpFromFcm(otp: '123456', phoneNumber: '+1234567890');

// Called by OtpVerificationScreen to verify
await OtpService.instance.verifyOtp(phoneNumber, otp);

// Request new OTP
await OtpService.instance.requestOtp(phoneNumber, fcmToken);
```

### Frontend: Registration Screens

**PhoneRegistrationScreen** (`lib/screens/phone_registration_screen.dart`):

1. User enters phone number
2. Validates format (10-15 digits)
3. Gets device FCM token
4. Calls `requestOtp()` Cloud Function
5. Navigates to `OtpVerificationScreen`

**OtpVerificationScreen** (`lib/screens/otp_verification_screen.dart`):

1. Displays 6 input fields for OTP digits
2. Listens to `OtpService.otpStream` for auto-fill
3. Shows 2-minute countdown timer
4. Validates & verifies OTP on submission
5. Handles resend with rate limiting

### Frontend: Push Notification Updates

**File**: `lib/services/push_notification_handler.dart` [UPDATED]

Added OTP detection:

1. In `_showForegroundNotification()` - Detects OTP data message
2. In `_navigateFromMessage()` - Handles OTP tap in background
3. In `handleInitialMessage()` - Handles OTP from terminated state

When OTP message detected:

- Extracts `otp` and `phoneNumber` from `message.data`
- Calls `OtpService.instance.handleOtpFromFcm()`
- Shows subtle notification to user

### Backend: Cloud Functions

**File**: `functions/src/otp.js`

Three main functions:

#### `requestOtp(phoneNumber, fcmToken)`

**Request**:

```json
{
  "phoneNumber": "+1234567890",
  "fcmToken": "device-fcm-token-here"
}
```

**Process**:

1. ✓ Validates phone number (10-15 digits)
2. ✓ Checks rate limit (max 3 per 30 min)
3. ✓ Generates random 6-digit OTP
4. ✓ Stores in `pendingOtps` collection
5. ✓ Sends via FCM data message

**Response**:

```json
{
  "success": true,
  "message": "OTP sent successfully",
  "expiresIn": 120
}
```

**Firestore Structure** (`pendingOtps/{docId}`):

```json
{
  "phoneNumber": "+1234567890",
  "otp": "123456",
  "fcmToken": "device-token",
  "status": "pending",
  "requestedAt": Timestamp,
  "expiresAt": Timestamp,
  "createdAt": Timestamp
}
```

#### `verifyOtp(phoneNumber, otp)`

**Request**:

```json
{
  "phoneNumber": "+1234567890",
  "otp": "123456"
}
```

**Process**:

1. ✓ Validates OTP format (6 digits)
2. ✓ Finds matching pending OTP record
3. ✓ Checks expiration (2 minutes)
4. ✓ Marks as verified in Firestore
5. ✓ Creates verified phone record

**Response**:

```json
{
  "success": true,
  "message": "Phone number verified successfully",
  "phoneNumber": "+1234567890"
}
```

#### `resendOtp(phoneNumber, fcmToken)`

Resends OTP to a new device token (e.g., for device switching).

**Process**:

1. ✓ Finds most recent pending OTP
2. ✓ Updates FCM token
3. ✓ Resends OTP to new token

### Firestore Security Rules

**Location**: `firestore.rules`

Add these rules to protect OTP collection:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...

    // OTP Collection - Only accessible via Cloud Functions
    match /pendingOtps/{docId} {
      allow read, write: if false;  // Disabled for direct access
      // Functions have special permissions via service account
    }

    // Verified phones - Can be read by authenticated users
    match /verifiedPhones/{phoneNumber} {
      allow read: if request.auth != null;
      allow write: if false;  // Only writable via Cloud Functions
    }
  }
}
```

## Deployment Steps

### 1. Deploy Cloud Functions

```bash
cd functions
npm install  # If not already done
firebase deploy --only functions:requestOtp,functions:verifyOtp,functions:resendOtp,functions:cleanupExpiredOtps
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

### 2. Update Firestore Rules

Deploy the updated `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

### 3. Set Up Cloud Scheduler (Optional)

For automatic cleanup of expired OTP records:

1. Go to Cloud Console > Cloud Scheduler
2. Create job with schedule: `every 1 hours`
3. Set HTTP target to your cleanup function

The `cleanupExpiredOtps` function runs hourly by default.

## Usage in Registration Flow

### Step 1: Navigate to Phone Registration

From your login/registration flow:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const PhoneRegistrationScreen(),
  ),
);
```

### Step 2: User Enters Phone Number

- `PhoneRegistrationScreen` handles phone input
- Validates format & retrieves FCM token
- Calls `requestOtp()` backend function
- Navigates to OTP verification screen

### Step 3: User Verifies OTP

- OTP arrives via FCM push notification
- Auto-fills in `OtpVerificationScreen`
- User can manually edit if needed
- Clicks "Verify" button
- Calls `verifyOtp()` backend function
- Returns to previous screen with verified status

### Example Integration

```dart
// In your login/registration screen
ElevatedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PhoneRegistrationScreen(),
      ),
    );
  },
  child: const Text('Verify Phone Number'),
),

// Handle result from OTP verification
// In PhoneRegistrationScreen, listen to pop result:
// result = await Navigator.of(context).push(...)
// if (result?['verified'] == true) { ... }
```

## Testing

### Local Testing

1. **Start Firebase Emulators** (optional):

   ```bash
   firebase emulators:start
   ```

2. **Run Flutter app in debug mode**:

   ```bash
   flutter run
   ```

3. **Test phone registration**:
   - Navigate to `PhoneRegistrationScreen`
   - Enter valid phone number
   - Check logs for OTP generation

4. **Test OTP delivery**:
   - Check Firebase Console > Cloud Functions > Logs
   - Verify FCM messages were sent

### Testing with Firebase Cloud Functions Emulator

For local testing without deploying:

1. Start emulators:

   ```bash
   firebase emulators:start --only functions,firestore
   ```

2. Update app to use emulator URLs
3. Test OTP flow locally

### Production Testing Checklist

- [ ] Notifications enabled on test device
- [ ] FCM token successfully retrieved
- [ ] OTP received within 5 seconds
- [ ] OTP auto-fills in verification screen
- [ ] Countdown timer works correctly
- [ ] OTP expires after 2 minutes
- [ ] Resend button works
- [ ] Rate limiting works (test 4th request)
- [ ] Verification succeeds with correct OTP
- [ ] Verification fails with wrong OTP
- [ ] Cloud Functions logs show no errors

## Security Considerations

✓ **OTP Storage**: Temporary Firestore docs, auto-deleted after 24 hours
✓ **Expiration**: 2-minute TTL on all OTP codes
✓ **Rate Limiting**: Max 3 requests per 30 minutes per phone
✓ **No SMS**: FCM push only (more secure, user controls notifications)
✓ **Data Messages**: OTP sent as data payload, not display notification
✓ **Server-Side Verification**: All validation done on backend
✓ **Phone Validation**: Format verified before generating OTP
✓ **Token-Based**: FCM tokens used for device identification

## Troubleshooting

### Issue: OTP not received

**Causes**:

- Notifications disabled on device
- FCM token not valid/updated
- Cloud Function execution error

**Solution**:

1. Check device notification settings
2. Verify FCM token in Firestore (`users/{uid}/devices`)
3. Check Cloud Functions logs in Firebase Console

### Issue: OTP arrives but doesn't auto-fill

**Cause**: `otpStream` not being listened to

**Solution**:

1. Verify `OtpVerificationScreen` initialized
2. Check `_listenForOtpFromFcm()` is called in `initState`
3. Verify `OtpService.instance.handleOtpFromFcm()` is called from handler

### Issue: Expiration time incorrect

**Cause**: Device time out of sync with server

**Solution**:

- Use server timestamp in Cloud Function: `admin.firestore.Timestamp.now()`
- Compare with Firestore timestamp (not device time)

### Issue: Rate limiting not working

**Cause**: `requestedAt` field missing or wrong timestamp type

**Solution**:

1. Verify `requestedAt` is `Timestamp` type in Firestore
2. Check Cloud Function Firestore query filters

### Issue: Firebase credentials not found

**Cause**: `google-services.json` missing or not configured

**Solution**:

1. Download from Firebase Console
2. Place in `android/app/google-services.json`
3. Ensure `google-services` plugin applied in `build.gradle`

## Next Steps

After implementing OTP verification:

1. **Extend Registration Flow**: Add user profile creation after OTP verification
2. **Device Verification**: Use same flow for secondary device verification
3. **Password Reset**: Implement OTP-based password recovery
4. **Login Security**: Add optional 2FA via OTP
5. **Account Recovery**: Use phone verification for account recovery

## Database Migrations

### Firestore Collections Created

```
pendingOtps/
├── {docId}
│   ├── phoneNumber (string)
│   ├── otp (string, 6 digits)
│   ├── fcmToken (string)
│   ├── status (string: pending, verified, expired)
│   ├── requestedAt (Timestamp)
│   ├── expiresAt (Timestamp)
│   └── verifiedAt (Timestamp, optional)

verifiedPhones/
├── {phoneNumber}
│   ├── phoneNumber (string)
│   ├── verifiedAt (Timestamp)
│   └── lastVerified (Timestamp)
```

## Support

For issues or questions:

1. Check Cloud Functions logs: Firebase Console > Cloud Functions > Logs
2. Verify Firestore rules in Security Rules tab
3. Test Cloud Functions directly using Firebase Console > Functions
4. Check device FCM token in Firestore

---

**Implementation Date**: March 2026
**Firebase SDK Version**: Latest
**Dart Version**: 3.x
**Flutter Version**: 3.x
