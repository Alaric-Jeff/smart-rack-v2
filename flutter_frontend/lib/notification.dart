import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = "All"; // Options: "All", "Unread", "Read"

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).collection('notifications').doc(docId).delete();
    }
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

  @override
  Widget build(BuildContext context) {
    final double padding = MediaQuery.of(context).size.width * 0.05;
    final user = _auth.currentUser;

    if (user == null) return const Center(child: Text("Please log in"));

    // --- 1. DEFINE THE STREAM ---
    final Stream<QuerySnapshot> notificationStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('time', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER (ALWAYS VISIBLE) ---
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
                  // Placeholder icons (Functionality requires data to be loaded)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {}, 
                        icon: const Icon(Icons.done_all, color: Colors.grey),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      ),
                    ],
                  )
                ],
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
                stream: notificationStream,
                builder: (context, snapshot) {
                  
                  // 1. ERROR STATE (Hides the Red Screen)
                  if (snapshot.hasError) {
                    debugPrint("NOTIFICATION ERROR: ${snapshot.error}"); 
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_clock, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            "Waiting for Backend Access...", 
                            style: TextStyle(
                              color: Colors.grey[500], 
                              fontWeight: FontWeight.bold
                            )
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "(Permission Denied)", 
                            style: TextStyle(fontSize: 12, color: Colors.grey[400])
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
    
    String time = "Just now";
    if (item['time'] != null && item['time'] is Timestamp) {
        time = _formatTimestamp(item['time'] as Timestamp);
    }

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
          border: isRead ? Border.all(color: Colors.transparent) : Border.all(color: const Color(0xFF2962FF).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.notifications, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(fontSize: 12, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
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