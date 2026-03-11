/**
 * Firebase Cloud Functions - Main Index
 * Exports all Cloud Functions for the LINKod application
 */

const otp = require('./otp');

// Export OTP functions
exports.requestOtp = otp.requestOtp;
exports.verifyOtp = otp.verifyOtp;
exports.resendOtp = otp.resendOtp;
exports.cleanupExpiredOtps = otp.cleanupExpiredOtps;

// Import and export other function modules as needed
// const users = require('./users');
// exports.createUserAccount = users.createUserAccount;
// exports.updateUserProfile = users.updateUserProfile;

// ... other function exports ...
