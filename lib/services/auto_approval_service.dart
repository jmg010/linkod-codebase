import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore-only auto-approval sweeper.
/// This runs on app startup to mirror admin auto-approval behavior
/// without relying on the admin Approvals screen being opened.
class AutoApprovalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _hasRunThisSession = false;

  /// Run auto-approval once per app session.
  /// Only runs when the current user is a super_admin.
  static Future<void> runOnceOnStartup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        // No authenticated user; nothing to auto-approve.
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final role =
          (userDoc.data()?['role'] as String? ?? '').toLowerCase();

      if (role != 'super_admin') {
        // Only super admins are allowed to run the sweeper.
        return;
      }

      if (_hasRunThisSession) return;
      _hasRunThisSession = true;

      final settingsSnap = await _firestore
          .collection('adminSettings')
          .doc('approvals')
          .get();

      if (!settingsSnap.exists) return;

      final data = settingsSnap.data() ?? <String, dynamic>{};
      final autoApproveProducts =
          data['autoApproveProducts'] as bool? ?? false;
      final autoApproveTasks = data['autoApproveTasks'] as bool? ?? false;

      final futures = <Future<void>>[];

      if (autoApproveProducts) {
        futures.add(_autoApprovePendingProducts());
      }
      if (autoApproveTasks) {
        futures.add(_autoApprovePendingTasks());
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('AutoApprovalService.runOnceOnStartup error: $e');
    }
  }

  static Future<void> _autoApprovePendingProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'Pending')
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'Approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('AutoApprovalService _autoApprovePendingProducts error: $e');
    }
  }

  static Future<void> _autoApprovePendingTasks() async {
    try {
      final snapshot = await _firestore
          .collection('tasks')
          .where('approvalStatus', isEqualTo: 'Pending')
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'approvalStatus': 'Approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('AutoApprovalService _autoApprovePendingTasks error: $e');
    }
  }
}

