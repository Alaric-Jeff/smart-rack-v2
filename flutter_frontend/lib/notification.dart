import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = "All"; // Options: "All", "Unread", "Read"

  // --- EXPANDED MOCK DATA ---
  final List<Map<String, dynamic>> _notifications = [
    {
      "id": 1,
      "title": "Rain Detected",
      "body": "Sensors detected sudden rain intensity. The rod has been automatically retracted.",
      "time": "Just now",
      "type": "alert",
      "isRead": false,
    },
    {
      "id": 2,
      "title": "Drying Cycle Complete",
      "body": "Your laundry is ready! Final weight: 0.0kg. System is now in Standby.",
      "time": "45 min ago",
      "type": "success",
      "isRead": false,
    },
    {
      "id": 3,
      "title": "High Humidity Warning",
      "body": "Humidity spiked to 92%. The drying fan has automatically switched to 'High' mode.",
      "time": "2 hrs ago",
      "type": "alert",
      "isRead": false,
    },
    {
      "id": 4,
      "title": "Maintenance Reminder",
      "body": "It's been 30 days since the last check. Please clean the moisture sensors for best accuracy.",
      "time": "1 day ago",
      "type": "info",
      "isRead": true,
    },
    {
      "id": 5,
      "title": "WiFi Disconnected",
      "body": "Smart Rack lost connection to 'Home_WiFi'. Reconnected automatically after 30s.",
      "time": "2 days ago",
      "type": "info",
      "isRead": true,
    },
    {
      "id": 6,
      "title": "Power Saving Mode",
      "body": "System inactive for 4 hours. Entering deep sleep to conserve energy.",
      "time": "3 days ago",
      "type": "info",
      "isRead": true,
    },
    {
      "id": 7,
      "title": "Firmware Update",
      "body": "Successfully updated to v2.4. Patch notes: Improved rod motor calibration.",
      "time": "1 week ago",
      "type": "success",
      "isRead": true,
    },
    {
      "id": 8,
      "title": "Load Imbalance",
      "body": "Weight distribution uneven. Please adjust clothes to prevent motor strain.",
      "time": "1 week ago",
      "type": "alert",
      "isRead": true,
    },
  ];

  // --- LOGIC: FILTERING ---
  List<Map<String, dynamic>> get _filteredList {
    if (_selectedFilter == "Unread") {
      return _notifications.where((n) => n['isRead'] == false).toList();
    } else if (_selectedFilter == "Read") {
      return _notifications.where((n) => n['isRead'] == true).toList();
    }
    return _notifications;
  }

  // --- LOGIC: ACTIONS ---
  
  // Existing function kept intact
  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All marked as read"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // --- NEW FUNCTION: CONFIRMATION MODAL FOR MARK ALL READ ---
  void _confirmMarkAllRead() {
    // If everything is already read, don't show the modal
    if (_notifications.every((n) => n['isRead'] == true)) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark all as read?"),
        content: const Text("This will mark all notifications as read."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              _markAllRead(); // Call original function
            }, 
            child: const Text("Confirm", style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _markAsRead(int id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) _notifications[index]['isRead'] = true;
    });
  }

  // --- UX: DELETE WITH UNDO ---
  void _deleteNotification(int id) {
    final index = _notifications.indexWhere((n) => n['id'] == id);
    final deletedItem = _notifications[index];

    setState(() {
      _notifications.removeAt(index);
    });

    // Show Undo Snackbar
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Deleted '${deletedItem['title']}'"),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: "UNDO",
          textColor: Colors.blueAccent,
          onPressed: () {
            setState(() {
              _notifications.insert(index, deletedItem);
            });
          },
        ),
      ),
    );
  }

  void _clearAllNotifications() {
    if (_notifications.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("This will permanently delete all notification logs."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() => _notifications.clear());
              Navigator.pop(ctx);
            }, 
            child: const Text("Clear", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double padding = MediaQuery.of(context).size.width * 0.05;

    // Counts for tabs
    int unreadCount = _notifications.where((n) => !n['isRead']).length;
    int readCount = _notifications.where((n) => n['isRead']).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Row(
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
                        // UPDATED: Now points to the confirmation modal
                        onPressed: _confirmMarkAllRead,
                        tooltip: "Mark all read",
                        icon: const Icon(Icons.done_all, color: Color(0xFF2962FF)),
                      ),
                      IconButton(
                        onPressed: _clearAllNotifications,
                        tooltip: "Clear all",
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- SMART TABS (With Counts) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  _buildFilterTab("All", _notifications.length),
                  const SizedBox(width: 10),
                  _buildFilterTab("Unread", unreadCount),
                  const SizedBox(width: 10),
                  _buildFilterTab("Read", readCount),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- LIST CONTENT ---
            Expanded(
              child: _filteredList.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
                      itemCount: _filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _filteredList[index];
                        return _buildNotificationItem(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterTab(String title, int count) {
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
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    bool isRead = item['isRead'];

    // SWIPE TO DELETE WIDGET
    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(16)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (direction) => _deleteNotification(item['id']),
      child: GestureDetector(
        onTap: () => _showNotificationDetail(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Unread items get a very subtle blue tint
            color: isRead ? Colors.white : const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: isRead ? Border.all(color: Colors.transparent) : Border.all(color: const Color(0xFF2962FF).withOpacity(0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconBadge(item['type']),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: const Color(0xFF1E2339),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['body'],
                      style: TextStyle(fontSize: 13, color: isRead ? Colors.grey[600] : Colors.black87, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['time'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
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

  Widget _buildIconBadge(String type) {
    Color bg, iconColor;
    IconData icon;

    switch (type) {
      case 'alert':
        bg = const Color(0xFFFFF3E0); // Orange-ish
        iconColor = const Color(0xFFFF9800);
        icon = Icons.warning_amber_rounded;
        break;
      case 'success':
        bg = const Color(0xFFE8F5E9); // Green
        iconColor = const Color(0xFF4CAF50);
        icon = Icons.check_circle_outline;
        break;
      default: // info
        bg = const Color(0xFFE3F2FD); // Blue
        iconColor = const Color(0xFF2196F3);
        icon = Icons.info_outline;
    }

    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(Icons.notifications_off_outlined, size: 40, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          Text(
            "No ${_selectedFilter.toLowerCase()} notifications",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> item) {
    _markAsRead(item['id']); 

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item['type'] == 'alert' ? const Color(0xFFFFF3E0) : (item['type'] == 'success' ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD)),
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    item['type'] == 'alert' ? Icons.warning_amber_rounded : (item['type'] == 'success' ? Icons.check_circle_outline : Icons.info_outline),
                    color: item['type'] == 'alert' ? Colors.orange : (item['type'] == 'success' ? Colors.green : Colors.blue),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      Text(item['time'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                )
              ],
            ),
            const Divider(height: 40),
            Text(item['body'], style: const TextStyle(fontSize: 16, color: Color(0xFF5A6175), height: 1.5)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteNotification(item['id']);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade100),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("DELETE"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}