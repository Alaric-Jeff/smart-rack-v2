import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './notifications/get_notification_stream.dart';
import './notifications/get_unread_count.dart';
import './notifications/delete_notification.dart';
import './notifications/mark_all_read.dart';
import './notifications/mark_notification_read.dart';
import './notifications/clear_all_notification.dart';
import './notifications/format_notification_time.dart';

class NotificationsScreen extends StatefulWidget {
  final String deviceId;

  const NotificationsScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = "All"; // "All", "Unread", "Read"

  // getNotificationStream is now synchronous — no Future wrapper needed
  late final Stream<QuerySnapshot> _notificationStream;

  @override
  void initState() {
    super.initState();
    _notificationStream = getNotificationStream(deviceId: widget.deviceId);
  }

  // --- ACTIONS (all use helper functions) ---

  void _confirmMarkAllRead() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark all as read?"),
        content: const Text("This will mark all notifications as read."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2962FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Uses mark_all_read.dart helper
              markAllRead(deviceId: widget.deviceId).catchError((e) {
                _showError("Failed to mark all read: $e");
              });
            },
            child:
                const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("This will permanently delete all notifications."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Uses clear_all_notification.dart helper
              clearAllNotifications(deviceId: widget.deviceId).catchError((e) {
                _showError("Failed to clear notifications: $e");
              });
            },
            child: const Text("Clear All",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onDismissed(String docId) {
    // Uses delete_notification.dart helper
    deleteNotification(id: docId).catchError((e) {
      _showError("Failed to delete: $e");
    });
  }

  void _onTapNotification(String docId, bool isRead) {
    if (isRead) return;
    // Uses mark_notification_read.dart helper
    markNotificationRead(notifId: docId).catchError((e) {
      debugPrint("Failed to mark read: $e");
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- ICON / COLOR HELPERS ---

  IconData _getIcon(String? type) {
    switch (type) {
      case 'alert':   return Icons.warning_amber_rounded;
      case 'warning': return Icons.error_outline_rounded;
      case 'success': return Icons.check_circle_outline_rounded;
      case 'info':
      default:        return Icons.info_outline_rounded;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'alert':   return Colors.orange;
      case 'warning': return Colors.red;
      case 'success': return Colors.green;
      case 'info':
      default:        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double padding = MediaQuery.of(context).size.width * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: StreamBuilder<int>(
                // Uses get_unread_count.dart helper for the badge
                stream: getUnreadCountStream(deviceId: widget.deviceId),
                builder: (context, unreadSnapshot) {
                  final unreadCount = unreadSnapshot.data ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("Alerts",
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E2339))),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2962FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Text("System Notifications",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: "Mark all as read",
                            onPressed:
                                unreadCount == 0 ? null : _confirmMarkAllRead,
                            icon: Icon(Icons.done_all,
                                color: unreadCount == 0
                                    ? Colors.grey.shade300
                                    : Colors.grey),
                          ),
                          IconButton(
                            tooltip: "Clear all",
                            onPressed: _confirmClearAll,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // --- FILTER TABS ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: ["All", "Unread", "Read"]
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _buildFilterTab(f),
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 16),

            // --- NOTIFICATION LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF2962FF)));
                  }

                  final allDocs = snapshot.data!.docs;

                  // Filter
                  List<DocumentSnapshot> filtered;
                  if (_selectedFilter == "Unread") {
                    filtered = allDocs
                        .where((d) => (d['isRead'] as bool?) == false)
                        .toList();
                  } else if (_selectedFilter == "Read") {
                    filtered = allDocs
                        .where((d) => (d['isRead'] as bool?) == true)
                        .toList();
                  } else {
                    filtered = allDocs;
                  }

                  if (filtered.isEmpty) return _buildEmptyState();

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                        horizontal: padding, vertical: 10),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildNotificationItem(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterTab(String title) {
    final bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2962FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF2962FF)
                  : Colors.grey.shade300),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      String docId, Map<String, dynamic> data) {
    final bool isRead = data['isRead'] as bool? ?? false;
    final String title = data['title'] as String? ?? "Notification";
    final String body = data['body'] as String? ?? "";
    final String type = data['type'] as String? ?? 'info';
    final String priority = data['priority'] as String? ?? 'medium';
    final bool isHighPriority =
        priority == 'high' || priority == 'critical';

    // Uses format_notification_time.dart helper
    final String time =
        formatNotificationTime(data['createdAt'] ?? data['time']);

    final IconData icon = _getIcon(type);
    final Color iconColor = _getColor(type);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red[400],
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _onDismissed(docId),
      child: GestureDetector(
        onTap: () => _onTapNotification(docId, isRead),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
            border: isRead
                ? Border.all(color: Colors.transparent)
                : Border.all(
                    color: isHighPriority
                        ? Colors.red.withOpacity(0.3)
                        : const Color(0xFF2962FF).withOpacity(0.1),
                    width: isHighPriority ? 2 : 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // Unread dot
                              if (!isRead) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2962FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: const Color(0xFF1E2339),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isHighPriority) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.red.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == "All"
                ? "No notifications yet"
                : "No ${_selectedFilter.toLowerCase()} notifications",
            style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("Error Loading Notifications",
                style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}