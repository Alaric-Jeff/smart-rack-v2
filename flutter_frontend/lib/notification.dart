import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './notifications/get_notification_stream.dart';

class NotificationsScreen extends StatefulWidget {
  final String deviceId; // REQUIRED: Pass the current device ID
  
  const NotificationsScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = "All"; // Options: "All", "Unread", "Read"

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _loadNotificationStream();
  }

  Future<void> _loadNotificationStream() async {
    try {
      final stream = await getNotificationStream(deviceId: widget.deviceId);
      setState(() {
        _notificationStream = stream;
      });
    } catch (e) {
      debugPrint("Error loading notification stream: $e");
    }
  }

  // --- ACTIONS ---
  
  void _markAllRead(List<DocumentSnapshot> docs) {
    WriteBatch batch = _firestore.batch();
    for (var doc in docs) {
      if (doc['isRead'] == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    batch.commit();
  }

  void _confirmMarkAllRead(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark all as read?"),
        content: const Text("This will mark all notifications as read."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _markAllRead(docs); }, 
            child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _deleteNotification(String docId) {
    // Delete from global notifications collection
    _firestore.collection('notifications').doc(docId).delete();
  }

  void _clearAllNotifications(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("This will delete all logs."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              WriteBatch batch = _firestore.batch();
              for (var doc in docs) {
                batch.delete(doc.reference);
              }
              batch.commit();
              Navigator.pop(ctx);
            }, 
            child: const Text("Clear", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${date.day}/${date.month}";
  }

  // Get icon and color based on notification type
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.error_outline_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'alert':
        return Colors.orange;
      case 'warning':
        return Colors.red;
      case 'success':
        return Colors.green;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double padding = MediaQuery.of(context).size.width * 0.05;

    // If stream not loaded yet, show loading
    if (_notificationStream == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER (ALWAYS VISIBLE) ---
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: StreamBuilder<QuerySnapshot>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  List<DocumentSnapshot> allDocs = [];
                  if (snapshot.hasData) {
                    allDocs = snapshot.data!.docs;
                  }
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Alerts", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                          Text("System Notification", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: allDocs.isEmpty ? null : () => _confirmMarkAllRead(allDocs), 
                            icon: Icon(Icons.done_all, color: allDocs.isEmpty ? Colors.grey.shade300 : Colors.grey),
                          ),
                          IconButton(
                            onPressed: allDocs.isEmpty ? null : () => _clearAllNotifications(allDocs),
                            icon: Icon(Icons.delete_outline, color: allDocs.isEmpty ? Colors.grey.shade300 : Colors.grey),
                          ),
                        ],
                      )
                    ],
                  );
                }
              ),
            ),

            const SizedBox(height: 16),

            // --- FILTER TABS (ALWAYS VISIBLE) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  _buildFilterTab("All"),
                  const SizedBox(width: 10),
                  _buildFilterTab("Unread"),
                  const SizedBox(width: 10),
                  _buildFilterTab("Read"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- LIST CONTENT (HANDLES ERRORS GRACEFULLY) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  
                  // 1. ERROR STATE
                  if (snapshot.hasError) {
                    debugPrint("NOTIFICATION ERROR: ${snapshot.error}"); 
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            "Error Loading Notifications", 
                            style: TextStyle(
                              color: Colors.grey[500], 
                              fontWeight: FontWeight.bold
                            )
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(), 
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // 2. LOADING STATE
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;
                  
                  // Filter Logic
                  List<DocumentSnapshot> filteredDocs = [];
                  if (_selectedFilter == "Unread") {
                    filteredDocs = allDocs.where((doc) => doc['isRead'] == false).toList();
                  } else if (_selectedFilter == "Read") {
                    filteredDocs = allDocs.where((doc) => doc['isRead'] == true).toList();
                  } else {
                    filteredDocs = allDocs;
                  }

                  if (filteredDocs.isEmpty) return _buildEmptyState();

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildNotificationItem(doc.id, data);
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterTab(String title) {
    bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2962FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade300),
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

  Widget _buildNotificationItem(String docId, Map<String, dynamic> item) {
    bool isRead = item['isRead'] ?? false;
    String title = item['title'] ?? "Notification";
    String body = item['body'] ?? "";
    String type = item['type'] ?? 'info';
    String priority = item['priority'] ?? 'medium';
    
    String time = "Just now";
    if (item['time'] != null && item['time'] is Timestamp) {
        time = _formatTimestamp(item['time'] as Timestamp);
    }

    // Get icon and color based on type
    IconData icon = _getNotificationIcon(type);
    Color iconColor = _getNotificationColor(type);

    // Priority indicator
    bool isHighPriority = priority == 'high' || priority == 'critical';

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(docId),
      child: Container(
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
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1), 
                shape: BoxShape.circle
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title, 
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isHighPriority) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
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
                            ]
                          ],
                        ),
                      ),
                      Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body, 
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]), 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis
                  ),
                ],
              ),
            )
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
          Icon(Icons.notifications_off_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No notifications", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}