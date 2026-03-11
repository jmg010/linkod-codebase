# OTP Push Notification - Quick Start Guide

Fast reference for implementing OTP verification via FCM push notifications.

## What Was Created

| File                                         | Purpose                            |
| -------------------------------------------- | ---------------------------------- |
| `lib/services/otp_service.dart`              | Manages OTP state and verification |
| `lib/screens/phone_registration_screen.dart` | User phone number input            |
| `lib/screens/otp_verification_screen.dart`   | OTP entry & verification UI        |
| `functions/src/otp.js`                       | Backend Cloud Functions            |
| `functions/src/index.js`                     | Function exports                   |

## 3-Step Implementation

### ✅ Step 1: Deploy Backend (COMPLETED)

```bash
cd functions
npm install
firebase deploy --only functions
firebase deploy --only firestore:rules
```

**Status**: ✅ **DEPLOYED SUCCESSFULLY**

- 4 Cloud Functions deployed: `requestOtp`, `verifyOtp`, `resendOtp`, `cleanupExpiredOtps`
- Firestore security rules updated with OTP permissions
- Node.js 20 runtime configured

### Step 2: Add Navigation to Registration

```dart
// In your login/registration flow
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const PhoneRegistrationScreen(),
  ),
);
```

### Step 3: Test on Device

1. Run app: `flutter run`
2. Navigate to `PhoneRegistrationScreen`
3. Enter phone number: `+1234567890`
4. Click "Send OTP"
5. OTP should arrive in notification within 5 seconds
6. Enter code and verify

## Key Features

✅ **6-digit OTP** sent via FCM  
✅ **2-minute expiration**  
✅ **Rate limiting** - Max 3 requests per 30 min  
✅ **Auto-fill** - OTP auto-fills when received  
✅ **Countdown timer** - Shows time remaining  
✅ **Firestore storage** - Temporary OTP records  
✅ **Secure** - No SMS, FCM data messages only

## File Locations

```
lib/
├── services/
│   ├── otp_service.dart ★ NEW
│   └── push_notification_handler.dart (updated)
└── screens/
    ├── phone_registration_screen.dart ★ NEW
    └── otp_verification_screen.dart ★ NEW

functions/src/
├── otp.js ★ NEW
└── index.js (updated)
```

## Cloud Functions Created

| Function               | Purpose                     |
| ---------------------- | --------------------------- |
| `requestOtp()`         | Generate & send OTP via FCM |
| `verifyOtp()`          | Validate OTP code           |
| `resendOtp()`          | Resend to different device  |
| `cleanupExpiredOtps()` | Auto-cleanup (hourly)       |

## Configuration

### Firestore Rules to Add

```
match /pendingOtps/{docId} {
  allow read, write: if false;  // Cloud Functions only
}

match /verifiedPhones/{phoneNumber} {
  allow read: if request.auth != null;
  allow write: if false;  // Cloud Functions only
}
```

### Android (`android/app/build.gradle`)

```gradle
plugins {
    id 'com.google.gms.google-services'
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging'
}
```

### iOS (`ios/Podfile`)

```ruby
platform :ios, '11.0'

# Capabilities in Xcode:
# - Push Notifications
# - Background Modes > Remote notifications
```

## Common Operations

### Request OTP

```dart
await OtpService.instance.requestOtp(
  phoneNumber: '+1234567890',
  fcmToken: fcmToken,
);
```

### Verify OTP

```dart
await OtpService.instance.verifyOtp(
  phoneNumber: '+1234567890',
  otp: '123456',
);
```

### Listen for OTP

```dart
OtpService.instance.otpStream.listen((otp) {
  print('OTP received: $otp');
});
```

## Testing Checklist

- [ ] Notifications enabled on device
- [ ] App gets FCM token successfully
- [ ] Request OTP button works
- [ ] OTP arrives in notification
- [ ] OTP auto-fills fields
- [ ] Countdown timer works
- [ ] Verification succeeds with correct OTP
- [ ] Verification fails with wrong OTP
- [ ] Resend button works
- [ ] Expired OTP shows error
- [ ] Rate limiting works (4th request blocked)

## Troubleshooting

| Issue                 | Solution                                   |
| --------------------- | ------------------------------------------ |
| OTP not arriving      | Check notifications enabled, firebase logs |
| Auto-fill not working | Verify `otpStream` listener in screen      |
| Rate limit error      | Wait 30 min or change limit in `otp.js`    |
| Verification fails    | Check OTP matches, not expired             |
| Cloud Functions error | Check function logs in Firebase Console    |

## Next Steps

1. **Deploy**: `firebase deploy --only functions`
2. **Test**: Navigate to `PhoneRegistrationScreen`
3. **Monitor**: Watch Cloud Functions logs
4. **Document**: Update registration flow in your app
5. **User Comms**: Inform users about new phone verification

## Documentation Files

- `OTP_IMPLEMENTATION_GUIDE.md` - Complete technical guide
- `OTP_INTEGRATION_EXAMPLES.md` - Code examples & patterns
- `OTP_DEPLOYMENT_CHECKLIST.md` - Full testing & deployment steps
- `firestore_otp_rules.txt` - Security rules template

## Key Parameters

| Parameter  | Value           | Location                                 |
| ---------- | --------------- | ---------------------------------------- |
| OTP Length | 6 digits        | `otp.js` - `generateOtp()`               |
| Expiration | 120 seconds     | `otp.js` - `OTP_EXPIRATION_SECONDS`      |
| Rate Limit | 3 per 30 min    | `otp.js` - Constants                     |
| Cleanup    | Every 1 hour    | `otp.js` - `cleanupExpiredOtps` schedule |
| OTP TTL    | Auto-delete 24h | `otp.js` - Cleanup function              |

## Security Highlights

🔒 **Server-side generation** - Secure random in Cloud Function  
🔒 **No SMS** - FCM data message only  
🔒 **Expiration** - 2-minute TTL  
🔒 **Rate limited** - Max 3 requests per 30 min  
🔒 **One-use** - Mark as verified after use  
🔒 **Firestore rules** - No direct client access  
🔒 **Cleanup** - Auto-delete after 24 hours

## Support & Help

### Check Logs

```bash
# Cloud Functions logs
firebase functions:log --limit 100

# Firestore operations
# Firebase Console > Firestore > Operations
```

### Debug Mode

Monitor Flutter logs:

```
flutter run -v 2>&1 | grep -i "otp|fcm|firebase"
```

### Firebase Console Checks

1. Cloud Functions > Logs (errors?)
2. Firestore > pendingOtps (records created?)
3. Cloud Messaging > Metrics (messages sent?)

---

**Version**: 1.0  
**Last Updated**: March 2026  
**Status**: ✅ **READY FOR TESTING** - Backend deployed, client code ready
