import 'package:flutter/material.dart';

class BulletinCategoryModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const BulletinCategoryModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  // Predefined categories for LINKod
  static const List<BulletinCategoryModel> categories = [
    BulletinCategoryModel(
      id: 'public_services',
      title: 'Public Services',
      description: 'Garbage collection schedule, barangay office hours, health center clinic schedule.',
      icon: Icons.calendar_today,
      backgroundColor: Color(0xFFE8F4FD),
      iconColor: Color(0xFF2196F3),
    ),
    BulletinCategoryModel(
      id: 'emergency_contacts',
      title: 'Emergency Contacts',
      description: 'Barangay tanod hotline, police hotline, fire department.',
      icon: Icons.phone,
      backgroundColor: Color(0xFFFDECEA),
      iconColor: Color(0xFFE53935),
    ),
    BulletinCategoryModel(
      id: 'community_facilities',
      title: 'Community Facilities',
      description: 'Evacuation centers, barangay hall, health center locations.',
      icon: Icons.location_on,
      backgroundColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF4CAF50),
    ),
  ];

  static BulletinCategoryModel? getById(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
