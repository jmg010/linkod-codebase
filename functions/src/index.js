/**
 * Firebase Cloud Functions - Main Index
 * Exports all Cloud Functions for the LINKod application
 */

const otp = require('./otp');
const notifications = require('./notifications');

// Export OTP functions
exports.requestOtp = otp.requestOtp;
exports.verifyOtp = otp.verifyOtp;
exports.resendOtp = otp.resendOtp;
exports.cleanupExpiredOtps = otp.cleanupExpiredOtps;
exports.sendPushForNotification = notifications.sendPushForNotification;

// Import and export other function modules as needed
// const users = require('./users');
// exports.createUserAccount = users.createUserAccount;
// exports.updateUserProfile = users.updateUserProfile;

// ... other function exports ...
