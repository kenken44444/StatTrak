import 'package:flutter/material.dart';
// Make sure these imports are correct in your actual project
import 'package:stattrak/SharedLocationPage.dart';
import 'package:stattrak/widgets/friends_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


class NotificationAlertManager {
  final BuildContext context;
  final List<OverlayEntry> _activeAlerts = [];
  final Set<String> _shownAlertIds = {}; // Using Set for efficient lookup

  NotificationAlertManager(this.context);

  void show(String message, String notificationId) async {
    if (_shownAlertIds.contains(notificationId)) return;

    if (_activeAlerts.length >= 2) {
      _removeMostRecent();
    }

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10.0 + (_activeAlerts.length * 70.0), // Adjusted top position
        right: 20,
        child: _buildAlert(message),
      ),
    );

    _activeAlerts.add(entry);
    _shownAlertIds.add(notificationId); // Track shown ID
    overlay.insert(entry);

    await Future.delayed(const Duration(seconds: 3)); // Slightly longer duration
    _remove(entry);
  }

  Widget _buildAlert(String message) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [ // Optional shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                maxLines: 3, // Prevent excessive height
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _remove(OverlayEntry entry) {
    if (_activeAlerts.contains(entry)) { // Check if entry still exists before removing
      entry.remove();
      _activeAlerts.remove(entry);
    }
  }

  void _removeMostRecent() {
    if (_activeAlerts.isNotEmpty) {
      _remove(_activeAlerts.last);
    }
  }

  void clearAllAlerts() {
    // Use toList() to avoid concurrent modification errors
    for (var entry in _activeAlerts.toList()) {
      entry.remove();
    }
    _activeAlerts.clear();
    _shownAlertIds.clear(); // Clear tracked IDs as well
  }
}


class NotificationItem {
  final String id;
  final String type;
  final String? actorId;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? relatedEntityId;
  final String? relatedEntityType;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    this.actorId,
    this.actorUsername,
    this.actorAvatarUrl,
    this.relatedEntityId,
    this.relatedEntityType,
    required this.isRead,
    required this.createdAt,
  });

  String get displayMessage {
    final actorName = actorUsername ?? 'Someone';
    switch (type) {
      case 'friend_request_received':
        return '$actorName sent you a friend request.';
      case 'friend_request_accepted':
        return '$actorName accepted your friend request.';
      case 'location_shared':
        return '$actorName shared a location with you.';
      case 'post_liked':
        return '$actorName liked your post.';
      case 'comment_added':
        return '$actorName commented on your post.';
      default:
        return 'New notification: Type $type from $actorName.'; // More informative default
    }
  }

  String get displayDate {
    final now = DateTime.now();
    // Ensure comparison happens in the same time zone (local)
    final difference = now.difference(createdAt.toLocal());

    if (difference.inDays > 1) {
      // Include year for older dates
      return DateFormat('MMM d, yyyy').format(createdAt.toLocal());
    } else if (difference.inDays == 1 ||
        (difference.inHours >= 24 && now.day != createdAt.toLocal().day)) {
      return 'Yesterday';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final actorData = map['actor'] as Map<String, dynamic>?;
    // Handle potential null values gracefully
    return NotificationItem(
      id: map['id'] as String? ?? 'unknown_id', // Provide default if null
      type: map['type'] as String? ?? 'unknown_type',
      actorId: map['actor_user_id'] as String?,
      actorUsername: actorData?['username'] as String?,
      actorAvatarUrl: actorData?['avatar_url'] as String?,
      relatedEntityId: map['related_entity_id'] as String?,
      relatedEntityType: map['related_entity_type'] as String?,
      isRead: map['is_read'] as bool? ?? false, // Default to false if null
      // Ensure createdAt parsing is robust and store as UTC
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toUtc()
          : DateTime.now().toUtc(), // Fallback to now if null
    );
  }
}


class NotificationSidebar extends StatefulWidget {
  const NotificationSidebar({Key? key}) : super(key: key);

  @override
  State<NotificationSidebar> createState() => _NotificationSidebarState();
}

class _NotificationSidebarState extends State<NotificationSidebar> {
  final _supabase = Supabase.instance.client;
  late Future<List<NotificationItem>> _notificationsFuture;
  late NotificationAlertManager _alertManager;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    // Initialize _alertManager immediately in initState
    _alertManager = NotificationAlertManager(context);
    // Fetch initial notifications
    _notificationsFuture = _fetchNotifications(showAlerts: true);
  }


  @override
  void dispose() {
    // Clear any lingering alerts when the sidebar is disposed
    _alertManager.clearAllAlerts();
    super.dispose();
  }

  Future<List<NotificationItem>> _fetchNotifications({bool showAlerts = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      // Return empty list or throw specific error if user is not logged in
      // throw Exception('User not logged in.');
      return []; // Returning empty list might be safer for UI
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select('*, actor:profiles!notifications_actor_user_id_fkey(username, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50); // Consider pagination for large datasets

      // No need to check response type, Supabase client handles errors/types
      final notifications = response
          .map((item) => NotificationItem.fromMap(item as Map<String, dynamic>))
          .toList();

      // Show alerts only if requested and widget is still mounted
      if (showAlerts && mounted) {
        _alertManager._shownAlertIds.clear(); // Reset shown alerts for this fetch
        // Limit alert popups to avoid overwhelming the user
        int alertCount = 0;
        for (var notif in notifications) {
          if (!notif.isRead && alertCount < 2) { // Show max 2 alerts per fetch
            _alertManager.show(notif.displayMessage, notif.id);
            alertCount++;
          }
        }
      }
      return notifications;

    } catch (error) {
      // Log detailed error for debugging
      print("Error fetching notifications: $error");
      // Rethrow a more user-friendly error or handle it appropriately
      throw Exception('Failed to load notifications. Please try again.');
    }
  }

  Future<void> _markAsRead(NotificationItem notif) async {
    // Avoid unnecessary updates
    if (notif.isRead) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notif.id);

      // Refresh the list after marking as read
      if (mounted) {
        setState(() {
          _notificationsFuture = _fetchNotifications(showAlerts: false); // Re-fetch without showing alerts
        });
      }
    } catch (e) {
      print("Error marking notification as read: $e");
      // Show error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to mark notification as read."), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearAllNotifications(List<NotificationItem> currentNotifications) async {
    if (_isClearing) return; // Prevent multiple simultaneous calls
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Get IDs of only the currently unread notifications
    final unreadIds = currentNotifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    // Don't proceed if there's nothing to clear
    if (unreadIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No unread notifications to clear.")),
      );
      return;
    }

    if (mounted) {
      setState(() { _isClearing = true; }); // Show loading indicator
    }

    try {
      // Update only the unread notifications for the user
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .inFilter('id', unreadIds); // Use 'in_' for efficiency

      // Refresh the list upon success
      if (mounted) {
        setState(() {
          _notificationsFuture = _fetchNotifications(showAlerts: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications marked as read.")),
        );
      }
    } catch (e) {
      print("Error clearing all notifications: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to clear notifications."), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Ensure loading indicator is hidden regardless of outcome
      if (mounted) {
        setState(() { _isClearing = false; });
      }
    }
  }

  void _handleNotificationTap(NotificationItem notif) {
    // Mark as read first
    _markAsRead(notif);

    // Navigation logic (ensure FriendsModal & SharedRoutePage are available)
    switch (notif.type) {
      case 'friend_request_received':
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId != null) {
          // This assumes FriendsModal is imported and available
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendsModal(currentUserId: currentUserId),
            ),
          );
        }
        break;

      case 'friend_request_accepted':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your friend request was accepted!")),
        );
        // Maybe navigate to the friend's profile?
        break;

      case 'location_shared':
        if (notif.relatedEntityId != null) {
          // This assumes SharedRoutePage is imported and available
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SharedRoutePage(routeId: notif.relatedEntityId!),
            ),
          );
        } else {
          print("Missing relatedEntityId for location_shared notification: ${notif.id}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open shared location."), backgroundColor: Colors.orange),
          );
        }
        break;

      case 'post_liked':
      // TODO: Implement navigation to the liked post
        print("Navigate to Post/Entity Detail Page with ID: ${notif.relatedEntityId} (Type: ${notif.relatedEntityType})");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Liked notification tapped (ID: ${notif.relatedEntityId})")),
        );
        break;

      case 'comment_added':
      // TODO: Implement navigation to the post/comment
        print("Navigate to Post/Entity Detail Page (and potentially scroll to comment) with ID: ${notif.relatedEntityId} (Type: ${notif.relatedEntityType})");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Comment notification tapped (ID: ${notif.relatedEntityId})")),
        );
        break;

      default:
        print("Tapped notification of unhandled type: ${notif.type}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Notification type '${notif.type}' tapped.")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarColor = Theme.of(context).primaryColorDark;
    final textColor = Colors.white;

    return Container(
      width: 300,
      color: sidebarColor,
      // Use FutureBuilder to handle loading/error states
      child: FutureBuilder<List<NotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          // Decouple header/body building from state logic
          Widget headerContent;
          Widget bodyContent;
          bool hasUnread = false;
          List<NotificationItem> currentNotifications = [];

          // Determine state based on snapshot
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            // Initial loading state
            headerContent = _buildHeader(textColor, false, []); // No clear button while loading
            bodyContent = Center(child: CircularProgressIndicator(color: textColor));
          } else if (snapshot.hasError) {
            // Error state
            headerContent = _buildHeader(textColor, false, []); // No clear button on error
            bodyContent = _buildErrorState(textColor, sidebarColor, snapshot.error);
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Empty state
            headerContent = _buildHeader(textColor, false, []); // No clear button when empty
            bodyContent = _buildEmptyState(textColor);
          } else {
            // Data loaded successfully
            currentNotifications = snapshot.data!;
            hasUnread = currentNotifications.any((n) => !n.isRead);
            headerContent = _buildHeader(textColor, hasUnread, currentNotifications);
            bodyContent = _buildNotificationList(textColor, sidebarColor, currentNotifications);
          }

          // Assemble the final column structure
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerContent,
              Expanded(child: bodyContent),
            ],
          );
        },
      ),
    );
  }

  // Helper to build the header row
  Widget _buildHeader(Color textColor, bool hasUnread, List<NotificationItem> notifications) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 8, 16), // Adjust right padding for button
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Notifications",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          // Show button only if there are unread notifications
          if (hasUnread)
            _isClearing
                ? Padding( // Show progress indicator while clearing
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: textColor)),
            )
                : IconButton(
              icon: Icon(Icons.done_all, color: textColor), // Clear all icon
              tooltip: 'Mark all as read',
              // Pass the current list to the clear function
              onPressed: () => _clearAllNotifications(notifications),
              splashRadius: 20, // Smaller splash for icon button
            ),
        ],
      ),
    );
  }

  // Helper for the empty list state
  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Text(
        'No notifications',
        style: TextStyle(color: textColor.withOpacity(0.8)),
      ),
    );
  }

  // Helper for the error state
  Widget _buildErrorState(Color textColor, Color sidebarColor, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
            const SizedBox(height: 10),
            Text(
              'Error loading notifications.',
              style: TextStyle(color: textColor.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
            // Optionally display specific error details for debugging
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$error',
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              // Retry fetching notifications on button press
              onPressed: () => setState(() {
                _notificationsFuture = _fetchNotifications(showAlerts: true);
              }),
              style: ElevatedButton.styleFrom(
                  foregroundColor: sidebarColor, backgroundColor: textColor.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build the actual list view
  Widget _buildNotificationList(Color textColor, Color sidebarColor, List<NotificationItem> notifications) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger re-fetch on pull-to-refresh
        setState(() {
          _notificationsFuture = _fetchNotifications(showAlerts: false);
        });
        // Need to return a Future for RefreshIndicator
        await _notificationsFuture;
      },
      color: textColor,
      backgroundColor: sidebarColor,
      child: ListView.separated(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return InkWell(
            onTap: () => _handleNotificationTap(notif),
            child: _buildNotificationTile(notif),
          );
        },
        // Add dividers between items
        separatorBuilder: (context, index) => Divider(
            height: 1, thickness: 1, color: Colors.white.withOpacity(0.1)),
      ),
    );
  }


  // Builds a single notification list tile
  Widget _buildNotificationTile(NotificationItem notif) {
    // Use slightly different colors for read/unread background
    final tileColor = notif.isRead
        ? Colors.transparent
        : Theme.of(context).primaryColor.withOpacity(0.2); // More noticeable unread color
    final titleColor = Colors.white;
    final subtitleColor = Colors.white70;
    // Use a theme color for the unread indicator dot
    final indicatorColor = Theme.of(context).indicatorColor;


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: tileColor, // Apply background color here for full width effect
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3), // Placeholder background
            backgroundImage: (notif.actorAvatarUrl != null && notif.actorAvatarUrl!.isNotEmpty)
                ? NetworkImage(notif.actorAvatarUrl!) // Load network image if URL exists
                : null,
            // Show person icon if no avatar URL
            child: (notif.actorAvatarUrl == null || notif.actorAvatarUrl!.isEmpty)
                ? Icon(Icons.person, color: Colors.white.withOpacity(0.7), size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.displayMessage,
                  style: TextStyle(
                    color: titleColor,
                    // Make unread text slightly bolder
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600,
                    fontSize: 14, // Consistent font size
                  ),
                  maxLines: 3, // Limit lines
                  overflow: TextOverflow.ellipsis, // Handle overflow
                ),
                const SizedBox(height: 5),
                Text(
                  notif.displayDate,
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
          // Unread Indicator Dot
          if (!notif.isRead)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4), // Adjust padding
              child: CircleAvatar(radius: 5, backgroundColor: indicatorColor), // Use theme color
            ),
        ],
      ),
    );
  }
}