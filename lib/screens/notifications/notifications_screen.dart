import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../base_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _notificationsStream() {
    return _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _markAllAsRead() async {
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('notifications').get();

    for (var doc in snapshot.docs) {
      if (doc['read'] == false) {
        batch.update(doc.reference, {'read': true});
      }
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteNotification(DocumentReference ref) async {
    await ref.delete();
  }

  Future<void> _markAsRead(DocumentReference ref) async {
    await ref.update({'read': true});
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case "reward":
        return const Color(0xFF00B894);
      case "tip":
        return const Color(0xFF6C5CE7);
      case "system":
        return const Color(0xFFFD79A8);
      case "market":
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case "reward":
        return Icons.monetization_on;
      case "tip":
        return Icons.lightbulb;
      case "system":
        return Icons.system_update;
      case "market":
        return Icons.trending_up;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      context: context,
      showBottomNavBar: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Notifications",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    "Mark all as read",
                    style: TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _notificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No notifications yet",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xFF2D2D44),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Dismissible(
                      key: Key(doc.id),
                      background: Container(
                        color: Colors.red.withOpacity(0.3),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E2D),
                            title: const Text(
                              'Delete Notification',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to delete this notification?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) => _deleteNotification(doc.reference),
                      child: Container(
                        decoration: BoxDecoration(
                          color: data['read'] == true
                              ? Colors.transparent
                              : const Color(0xFF2D2D44).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(data['type']).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotificationIcon(data['type']),
                              color: _getNotificationColor(data['type']),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: data['read'] == true
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                data['subtitle'] ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(data['timestamp']),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: data['read'] != true
                              ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                            ),
                          )
                              : null,
                          onTap: () {
                            _markAsRead(doc.reference);
                            // Add optional navigation based on data['type']
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour(s) ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
