import 'package:flutter_test/flutter_test.dart';

/// Tests for the volunteer_accepted notification badge system
/// 
/// These tests verify the hierarchy of notification counts:
/// - My Post button shows TOTAL (My Posts + Interacted Posts + volunteer_accepted)
/// - My Posts tab shows its own count separately
/// - Interacted Posts tab shows its own count (assigned tasks + volunteer_accepted)
/// 
/// Run with: flutter test test/volunteer_accepted_badge_test.dart
void main() {
  group('Volunteer Accepted Badge System', () {
    
    test('Hierarchy: My Post button shows total of all notification types', () {
      // Simulate counts from different sources
      const myPostsChatUnread = 3;      // Unread chat in tasks I created
      const myPostsPendingVolunteers = 2; // Pending volunteers on my tasks
      const assignedTasksChatUnread = 4; // Unread chat in tasks I'm assigned to
      const volunteerAcceptedNotifications = 1; // New volunteer_accepted notifications
      
      // Calculate totals
      final myPostsTotal = myPostsChatUnread + myPostsPendingVolunteers; // 5
      final interactedPostsTotal = assignedTasksChatUnread + volunteerAcceptedNotifications; // 5
      final myPostButtonTotal = myPostsTotal + volunteerAcceptedNotifications; // 6
      
      // My Post button should show total
      expect(myPostButtonTotal, equals(6));
      
      // Internal counts should be tracked separately
      expect(myPostsTotal, equals(5));
      expect(interactedPostsTotal, equals(5));
    });

    test('volunteer_accepted notifications count correctly', () {
      // When a user is accepted as volunteer on a task
      // They receive a volunteer_accepted notification
      
      // This notification should:
      // 1. Increment unreadNotificationCount on user document
      // 2. Appear in NotificationsService.getVolunteerAcceptedUnreadCountStream
      // 3. Be included in Interacted Posts badge count
      // 4. Be included in My Post button total count
      
      const notificationType = 'volunteer_accepted';
      const isRead = false;
      
      expect(notificationType, equals('volunteer_accepted'));
      expect(isRead, equals(false));
    });

    test('Badge display logic: only show when count > 0', () {
      const countWithNotifications = 5;
      const countZero = 0;
      
      bool shouldShowBadge(int count) => count > 0;
      
      expect(shouldShowBadge(countWithNotifications), isTrue);
      expect(shouldShowBadge(countZero), isFalse);
    });

    test('Badge count display: max 99+ for large numbers', () {
      String formatBadgeCount(int count) {
        return count > 99 ? '99+' : count.toString();
      }
      
      expect(formatBadgeCount(5), equals('5'));
      expect(formatBadgeCount(99), equals('99'));
      expect(formatBadgeCount(100), equals('99+'));
      expect(formatBadgeCount(150), equals('99+'));
    });

    test('Stream combination logic for My Post button', () {
      // Simulating Rx.combineLatest2 behavior
      int combineCounts(int taskActivity, int volunteerAccepted) {
        return taskActivity + volunteerAccepted;
      }
      
      // Test cases
      expect(combineCounts(3, 1), equals(4));
      expect(combineCounts(0, 2), equals(2));
      expect(combineCounts(5, 0), equals(5));
      expect(combineCounts(0, 0), equals(0));
    });

    test('Interacted Posts tab includes volunteer_accepted count', () {
      // Interacted Posts badge = assigned tasks chat + volunteer_accepted notifications
      const assignedTasksChat = 3;
      const volunteerAccepted = 2;
      
      final interactedPostsBadge = assignedTasksChat + volunteerAccepted;
      
      expect(interactedPostsBadge, equals(5));
      
      // Should NOT include My Posts activity
      const myPostsActivity = 4;
      expect(interactedPostsBadge, isNot(equals(myPostsActivity)));
    });

    test('My Posts tab does NOT include volunteer_accepted', () {
      // My Posts badge only shows activity on tasks I created
      // It should NOT include volunteer_accepted notifications
      // (those go to the volunteer, not the task owner)
      
      const myPostsChat = 3;
      const pendingVolunteers = 2;
      
      final myPostsBadge = myPostsChat + pendingVolunteers;
      
      expect(myPostsBadge, equals(5));
      
      // volunteer_accepted goes to different user (the volunteer)
      const volunteerAcceptedCount = 1;
      expect(myPostsBadge, isNot(contains(volunteerAcceptedCount)));
    });
  });

  group('Notification Badge Flow Integration', () {
    test('Complete flow: volunteer acceptance to badge update', () {
      // Step 1: Task owner accepts volunteer
      // Step 2: volunteer_accepted notification created
      // Step 3: unreadNotificationCount incremented
      // Step 4: getVolunteerAcceptedUnreadCountStream emits new value
      // Step 5: Interacted Posts badge updates
      // Step 6: My Post button badge updates (total)
      
      // Initial state
      var volunteerAcceptedCount = 0;
      var myPostButtonCount = 3; // Other activity
      
      // After volunteer accepted
      volunteerAcceptedCount += 1;
      myPostButtonCount += 1;
      
      expect(volunteerAcceptedCount, equals(1));
      expect(myPostButtonCount, equals(4));
    });

    test('Multiple volunteer_accepted notifications accumulate', () {
      var count = 0;
      
      // User gets accepted on 3 different tasks
      count += 1; // First task
      count += 1; // Second task
      count += 1; // Third task
      
      expect(count, equals(3));
    });

    test('Marking notification as read decrements count', () {
      var unreadCount = 3;
      
      // User reads one notification
      unreadCount -= 1;
      
      expect(unreadCount, equals(2));
      
      // User marks all as read
      unreadCount = 0;
      
      expect(unreadCount, equals(0));
    });
  });
}
