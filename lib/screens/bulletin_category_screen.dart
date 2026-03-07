import 'package:flutter/material.dart';
import '../models/bulletin_category_model.dart';
import '../models/bulletin_model.dart';
import '../widgets/bulletin_card.dart';

class BulletinCategoryScreen extends StatelessWidget {
  final BulletinCategoryModel category;

  const BulletinCategoryScreen({
    super.key,
    required this.category,
  });

  // Dummy data for bulletins
  List<BulletinModel> get _categoryBulletins {
    final allBulletins = [
      // Public Services
      BulletinModel(
        id: '1',
        title: 'Garbage Collection Schedule',
        description: 'Zone A: Monday & Thursday\nZone B: Tuesday & Friday\nZone C: Wednesday\n\nPlease place trash before 7:00 AM. Ensure proper segregation of waste.',
        categoryId: 'public_services',
        date: DateTime(2026, 3, 15),
        location: 'All Zones',
        createdAt: DateTime(2026, 3, 1, 10, 0),
      ),
      BulletinModel(
        id: '2',
        title: 'Barangay Office Hours',
        description: 'Monday - Friday: 8:00 AM - 5:00 PM\nSaturday: 8:00 AM - 12:00 PM\nSunday: Closed\n\nFor urgent matters, contact the barangay hotline.',
        categoryId: 'public_services',
        date: DateTime(2026, 3, 1),
        location: 'Barangay Hall',
        createdAt: DateTime(2026, 2, 25, 9, 0),
      ),
      BulletinModel(
        id: '3',
        title: 'Health Center Clinic Hours',
        description: 'General Consultation: Mon-Fri 8AM-4PM\nImmunization: Every Wednesday\nPrenatal Checkup: Every Tuesday & Thursday\nDental Services: Monday & Friday',
        categoryId: 'public_services',
        date: DateTime(2026, 3, 1),
        location: 'Barangay Health Center',
        createdAt: DateTime(2026, 2, 20, 10, 0),
      ),
      // Emergency Contacts
      BulletinModel(
        id: '4',
        title: 'Barangay Tanod Hotline',
        description: 'Barangay Peacekeeping & Security\n\nDuty Officer: 0917-123-4567\nTanod Commander: 0918-987-6543\n\nFor local security concerns and barangay assistance.',
        categoryId: 'emergency_contacts',
        date: DateTime(2026, 3, 10),
        location: 'Barangay Hall',
        createdAt: DateTime(2026, 3, 10, 9, 0),
        isPinned: true,
      ),
      BulletinModel(
        id: '5',
        title: 'Police Hotline',
        description: 'Philippine National Police (PNP)\n\nEmergency: 117\nSan Isidro Police Station: (02) 8888-1234\n\nAvailable 24/7 for emergencies and incident reports.',
        categoryId: 'emergency_contacts',
        date: DateTime(2026, 3, 10),
        location: 'Barangay San Isidro',
        createdAt: DateTime(2026, 3, 10, 8, 0),
        isPinned: true,
      ),
      BulletinModel(
        id: '6',
        title: 'Fire Department',
        description: 'Bureau of Fire Protection (BFP)\n\nEmergency: 117 or (02) 8888-5678\nFire Station 7: #123 Main Street\n\nFor fire emergencies and rescue services.',
        categoryId: 'emergency_contacts',
        date: DateTime(2026, 3, 10),
        location: 'Fire Station 7',
        createdAt: DateTime(2026, 3, 10, 8, 30),
        isPinned: true,
      ),
      // Community Facilities
      BulletinModel(
        id: '7',
        title: 'Evacuation Centers',
        description: 'Primary: San Isidro Elementary School\nSecondary: Barangay Covered Court\nTertiary: Church of San Isidro\n\nIn case of emergency, proceed to the nearest evacuation center.',
        categoryId: 'community_facilities',
        date: DateTime(2026, 3, 5),
        location: 'Multiple Locations',
        createdAt: DateTime(2026, 3, 5, 14, 0),
      ),
      BulletinModel(
        id: '8',
        title: 'Barangay Hall',
        description: '123 Rizal Street, Barangay San Isidro\n\nLandmark: Beside San Isidro Church\n\nServices: Clearance, Permits, ID Applications, Complaints',
        categoryId: 'community_facilities',
        date: DateTime(2026, 3, 1),
        location: 'Rizal Street',
        createdAt: DateTime(2026, 2, 28, 10, 0),
      ),
      BulletinModel(
        id: '9',
        title: 'Health Center',
        description: 'Barangay Health Center\n456 Mabini Street\n\nServices: Consultation, Immunization, Family Planning, Laboratory, Dental\n\nFree services for residents.',
        categoryId: 'community_facilities',
        date: DateTime(2026, 3, 1),
        location: 'Mabini Street',
        createdAt: DateTime(2026, 2, 28, 11, 0),
      ),
    ];

    return allBulletins.where((b) => b.categoryId == category.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bulletins = _categoryBulletins;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Bulletins list
            Expanded(
              child: bulletins.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Category description
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: category.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  color: category.iconColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bulletin cards
                          for (final bulletin in bulletins)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BulletinCard(bulletin: bulletin),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            category.icon,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No bulletins yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Bulletins in this category will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
