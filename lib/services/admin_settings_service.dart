import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

/// Service for reading admin settings from Firestore
class AdminSettingsService {
  /// Reads auto-approve flags from publicSettings/approvals
  /// Returns: Map with 'products' and 'tasks' boolean flags
  /// Defaults to false (require manual approval) if settings doc doesn't exist or read fails
  static Future<Map<String, bool>> getAutoApproveSettings() async {
    try {
      final settingsDoc = await FirestoreService.instance
          .collection('publicSettings')
          .doc('approvals')
          .get();
      
      if (!settingsDoc.exists) {
        // Default: no auto-approve if settings doc doesn't exist
        return {'products': false, 'tasks': false};
      }
      
      final data = settingsDoc.data() ?? {};
      return {
        'products': data['autoApproveProducts'] as bool? ?? false,
        'tasks': data['autoApproveTasks'] as bool? ?? false,
      };
    } catch (e) {
      // On error, default to false (require manual approval)
      debugPrint('Failed to read auto-approve settings: $e');
      return {'products': false, 'tasks': false};
    }
  }

  /// Helper function to get initial status/approvalStatus based on auto-approve settings
  /// Returns: Map with 'productStatus' and 'taskApprovalStatus'
  static Future<Map<String, String>> getInitialStatuses() async {
    try {
      final settingsDoc = await FirestoreService.instance
          .collection('publicSettings')
          .doc('approvals')
          .get();
      
      if (!settingsDoc.exists) {
        return {
          'productStatus': 'Pending',
          'taskApprovalStatus': 'Pending',
        };
      }
      
      final data = settingsDoc.data() ?? {};
      final autoProducts = data['autoApproveProducts'] as bool? ?? false;
      final autoTasks = data['autoApproveTasks'] as bool? ?? false;
      
      return {
        'productStatus': autoProducts ? 'Approved' : 'Pending',
        'taskApprovalStatus': autoTasks ? 'Approved' : 'Pending',
      };
    } catch (e) {
      debugPrint('Error reading auto-approve settings: $e');
      return {
        'productStatus': 'Pending',
        'taskApprovalStatus': 'Pending',
      };
    }
  }
}
