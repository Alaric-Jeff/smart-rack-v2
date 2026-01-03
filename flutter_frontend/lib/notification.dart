import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // --- MOCK DATA (Database Ready) ---
  // You will eventually fetch this list from Firebase
  final List<Map<String, dynamic>> _notifications = [
    {
      "id": 1,
      "title": "Rain Detected",
      "body": "Rod automatically retracted due to rain.",
      "time": "2 mins ago",
      "type": "alert", // alert (yellow), info (blue), success (green)
      "isRead": false,
    },
    // Added a second one just so you can see how the list looks
    {
      "id": 2,
      "title": "Drying Cycle Complete",
      "body": "Your laundry is now dry. Weight sensor indicates 0.5kg moisture remaining.",
      "time": "5 hrs ago",
      "type": "success", 
      "isRead": true,
    },
  ];

  // --- LOGIC: MARK ALL AS READ ---
  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All notifications marked as read"), duration: Duration(seconds: 1)),
    );
  }

  // --- LOGIC: SHOW DETAIL MODAL ---
  void _showNotificationDetail(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon & Title
                Row(
                  children: [
                    _buildIconForType(notification['type']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                          Text(notification['time'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40),
                
                // Content
                Text("Message Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                const SizedBox(height: 8),
                Text(notification['body'], style: const TextStyle(fontSize: 16, color: Color(0xFF5A6175), height: 1.5)),
                
                const Spacer(),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F6FA),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("CLOSE"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double padding = size.width * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Section ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Notifications Logs", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                      SizedBox(height: 4),
                      Text("Recent alerts and updates", style: TextStyle(fontSize: 14, color: Color(0xFF5A6175))),
                    ],
                  ),
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text("Mark all read", style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // --- Notification List ---
              Expanded(
                child: ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    return _buildNotificationCard(item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: Notification Card ---
  Widget _buildNotificationCard(Map<String, dynamic> item) {
    // Determine colors based on Type
    Color bgColor = Colors.white;
    Color iconColor = const Color(0xFF2962FF);
    IconData iconData = Icons.info;

    if (item['type'] == 'alert') {
      bgColor = const Color(0xFFFFF9E6); // Light Yellow
      iconColor = const Color(0xFFFFAB00); // Amber
      iconData = Icons.warning_amber_rounded;
    } else if (item['type'] == 'success') {
      bgColor = const Color(0xFFE8F5E9); // Light Green
      iconColor = const Color(0xFF00C853); // Green
      iconData = Icons.check_circle_outline;
    }

    return GestureDetector(
      onTap: () => _showNotificationDetail(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          // Subtle border if read/unread distinction is needed later
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2339))),
                Text(item['time'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            Text(item['body'], style: const TextStyle(fontSize: 13, color: Color(0xFF5A6175), height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconForType(String type) {
    if (type == 'alert') return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAB00), size: 24));
    if (type == 'success') return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check_circle_outline, color: Color(0xFF00C853), size: 24));
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.info_outline, color: Color(0xFF2962FF), size: 24));
  }
}