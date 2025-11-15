import 'package:flutter/material.dart';

const kFacebookBlue = Color(0xFF1877F2);

const double kPaddingSmall = 8;
const double kPaddingMedium = 12;
const double kPaddingLarge = 16;

const double kCardRadius = 12;
const double kAvatarSize = 40;

const TextStyle kHeadlineMedium = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: Colors.black87,
);

const TextStyle kHeadlineSmall = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.black87,
);

const TextStyle kBodyText = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: Colors.black87,
);

const BorderRadius kCardBorderRadius = BorderRadius.all(Radius.circular(kCardRadius));

ShapeBorder kCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(kCardRadius),
);
