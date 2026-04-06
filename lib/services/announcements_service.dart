import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'name_formatter.dart';

class AnnouncementViewer {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? purok;
  final DateTime? viewedAt;

  const AnnouncementViewer({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.purok,
    this.viewedAt,
  });
}

class AnnouncementViewersPage {
  final List<AnnouncementViewer> viewers;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastVisible;
  final bool hasMore;

  const AnnouncementViewersPage({
    required this.viewers,
    required this.lastVisible,
    required this.hasMore,
  });
}

class AnnouncementsService {
  static final CollectionReference _announcementsCollection = FirestoreService
      .instance
      .collection('announcements');
  static final CollectionReference _readsCollection = FirestoreService.instance
      .collection('userAnnouncementReads');

  /// Get all announcements ordered by date
  static Stream<List<Map<String, dynamic>>> getAnnouncementsStream() {
    return _announcementsCollection.snapshots().map((snapshot) {
      final announcements =
          snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Filter by status and isActive (Gatekeeper: Approved; allow 'published' for backward compatibility)
                final status = data['status'] as String? ?? '';
                final isActive = data['isActive'] as bool? ?? true;
                if ((status != 'Approved' && status != 'published') ||
                    !isActive)
                  return null;
                return {
                  'id': doc.id,
                  ...data,
                  'date': FirestoreService.parseTimestamp(
                    data['date'] ?? data['createdAt'],
                  ),
                  'createdAt': FirestoreService.parseTimestamp(
                    data['createdAt'],
                  ),
                  'updatedAt':
                      data['updatedAt'] != null
                          ? FirestoreService.parseTimestamp(data['updatedAt'])
                          : null,
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();
      // Sort by createdAt descending in code
      announcements.sort((a, b) {
        final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
        final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return announcements;
    });
  }

  /// Get announcements filtered by user's categories
  static Stream<List<Map<String, dynamic>>> getAnnouncementsForUserStream(
    List<String> userCategories,
  ) {
    if (userCategories.isEmpty) {
      return getAnnouncementsStream();
    }

    // Normalize user categories to lowercase for comparison
    final normalizedUserCategories =
        userCategories.map((c) => c.trim().toLowerCase()).toSet();

    return _announcementsCollection.snapshots().map((snapshot) {
      final announcements =
          snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Filter by status and isActive (Gatekeeper: Approved; allow 'published' for backward compatibility)
                final status = data['status'] as String? ?? '';
                final isActive = data['isActive'] as bool? ?? true;
                if ((status != 'Approved' && status != 'published') ||
                    !isActive)
                  return null;

                // Filter by audiences in code to avoid index requirement
                final audiences = data['audiences'] as List<dynamic>? ?? [];
                final normalizedAudiences =
                    audiences
                        .map((a) => (a as String?)?.trim().toLowerCase() ?? '')
                        .where((a) => a.isNotEmpty)
                        .toSet();

                // "General Residents" means all residents receive this announcement
                if (normalizedAudiences.contains('general residents')) {
                  // Include for everyone (no category filter)
                } else {
                  // Check if any user category matches any announcement audience
                  final hasMatchingAudience = normalizedUserCategories.any(
                    (userCat) => normalizedAudiences.contains(userCat),
                  );
                  if (!hasMatchingAudience) return null;
                }

                return {
                  'id': doc.id,
                  ...data,
                  'date': FirestoreService.parseTimestamp(
                    data['date'] ?? data['createdAt'],
                  ),
                  'createdAt': FirestoreService.parseTimestamp(
                    data['createdAt'],
                  ),
                  'updatedAt':
                      data['updatedAt'] != null
                          ? FirestoreService.parseTimestamp(data['updatedAt'])
                          : null,
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();
      // Sort by createdAt descending in code
      announcements.sort((a, b) {
        final aTime = a['createdAt'] as DateTime? ?? DateTime.now();
        final bTime = b['createdAt'] as DateTime? ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return announcements;
    });
  }

  /// Mark announcement as read and increment view count
  static Future<void> markAsRead(String announcementId, String userId) async {
    // Check if already read
    final existingRead =
        await _readsCollection
            .where('userId', isEqualTo: userId)
            .where('announcementId', isEqualTo: announcementId)
            .get();

    if (existingRead.docs.isEmpty) {
      await _readsCollection.add({
        'userId': userId,
        'announcementId': announcementId,
        'readAt': FieldValue.serverTimestamp(),
      });

      // Increment view count for this announcement
      await _announcementsCollection.doc(announcementId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Also write to views subcollection for Admin "View Readers" (one doc per user per announcement)
      final viewsRef = _announcementsCollection
          .doc(announcementId)
          .collection('views');
      await viewsRef.doc(userId).set({
        'userId': userId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Increment view count (called when announcement is viewed)
  static Future<void> incrementViewCount(String announcementId) async {
    await _announcementsCollection.doc(announcementId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Check if announcement is read by user
  static Future<bool> isReadByUser(String announcementId, String userId) async {
    final read =
        await _readsCollection
            .where('userId', isEqualTo: userId)
            .where('announcementId', isEqualTo: announcementId)
            .get();
    return read.docs.isNotEmpty;
  }

  /// Get a single announcement by ID (e.g. for notification deep link).
  static Future<Map<String, dynamic>?> getAnnouncementById(
    String announcementId,
  ) async {
    final doc = await _announcementsCollection.doc(announcementId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final status = data['status'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? true;
    if ((status != 'Approved' && status != 'published') || !isActive)
      return null;
    return {
      'id': doc.id,
      ...data,
      'date': FirestoreService.parseTimestamp(
        data['date'] ?? data['createdAt'],
      ),
      'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
      'updatedAt':
          data['updatedAt'] != null
              ? FirestoreService.parseTimestamp(data['updatedAt'])
              : null,
    };
  }

  /// Get read status for multiple announcements
  static Future<Set<String>> getReadAnnouncementIds(String userId) async {
    final reads =
        await _readsCollection.where('userId', isEqualTo: userId).get();
    return reads.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['announcementId'] as String;
    }).toSet();
  }

  /// Get a page of viewers for an announcement (newest first).
  static Future<AnnouncementViewersPage> getAnnouncementViewersPage({
    required String announcementId,
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .collection('views')
        .orderBy('viewedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final viewers = await Future.wait(
      docs.map((doc) async {
        final data = doc.data();
        final userId = (data['userId'] as String?) ?? doc.id;
        final viewedAtRaw = data['viewedAt'];

        String displayName = 'Resident';
        String? avatarUrl;
        String? purok;

        try {
          final userDoc =
              await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            final resolvedName = NameFormatter.fromUserDataDisplay(
              userData,
              fallback: '',
            );

            if (resolvedName.isNotEmpty) {
              displayName = resolvedName;
            } else {
              final fallbackName = NameFormatter.fromAnyDisplay(
                fullName: userData?['displayName'] as String?,
                firstName: userData?['firstName'] as String?,
                middleName: userData?['middleName'] as String?,
                lastName: userData?['lastName'] as String?,
                hasMiddleName: userData?['hasMiddleName'] as bool?,
                fallback: '',
              );
              if (fallbackName.isNotEmpty) {
                displayName = fallbackName;
              }
            }

            final purokValue = userData?['purok'];
            if (purokValue != null) {
              purok = purokValue.toString();
            }

            final avatarValue =
                (userData?['avatarUrl'] as String?)?.trim() ??
                (userData?['profileImageUrl'] as String?)?.trim();
            if (avatarValue != null && avatarValue.isNotEmpty) {
              avatarUrl = avatarValue;
            }
          }
        } catch (_) {
          // Keep graceful fallback if user profile cannot be read.
        }

        return AnnouncementViewer(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          purok: purok,
          viewedAt:
              viewedAtRaw is Timestamp
                  ? viewedAtRaw.toDate()
                  : (viewedAtRaw is DateTime ? viewedAtRaw : null),
        );
      }),
    );

    final hasMore = docs.length == limit;
    final lastVisible = docs.isNotEmpty ? docs.last : null;

    return AnnouncementViewersPage(
      viewers: viewers,
      lastVisible: lastVisible,
      hasMore: hasMore,
    );
  }
}
