import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../base_scaffold.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  void _navigateToGroup(BuildContext context, String groupName, String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(groupName: groupName, groupId: groupId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      context: context,
      currentIndex: 3, // Community tab index
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Community",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Connect with other NergNet users",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildGroupTile(
                    context,
                    icon: Icons.campaign,
                    title: "Announcements",
                    subtitle: "Official updates & alerts from the team",
                    memberCount: "1.2k members",
                    color: const Color(0xFF6C5CE7), // Purple
                    onTap: () => _navigateToGroup(context, "Announcements", "announcements"),
                  ),
                  const SizedBox(height: 15),
                  _buildGroupTile(
                    context,
                    icon: Icons.lightbulb,
                    title: "Suggestions",
                    subtitle: "Share your ideas to improve NergNet",
                    memberCount: "",
                    color: const Color(0xFF00B894), // Teal
                    onTap: () => _navigateToGroup(context, "Suggestions", "suggestions"),
                  ),
                  const SizedBox(height: 15),
                  _buildGroupTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: "General Chat",
                    subtitle: "Connect with other NergCoin users",
                    memberCount: "",
                    color: const Color(0xFFFD79A8), // Pink
                    onTap: () => _navigateToGroup(context, "General Chat", "general_chat"),
                  ),
                  const SizedBox(height: 15),
                  _buildGroupTile(
                    context,
                    icon: Icons.trending_up,
                    title: "Market Talk",
                    subtitle: "Discuss NERG price and market trends",
                    memberCount: "",
                    color: const Color(0xFFFFA726), // Orange
                    onTap: () => _navigateToGroup(context, "Market Talk", "market_talk"),
                  ),
                  const SizedBox(height: 15),
                  _buildGroupTile(
                    context,
                    icon: Icons.help_outline,
                    title: "Help Center",
                    subtitle: "Get support from the community",
                    memberCount: "",
                    color: const Color(0xFF00E676), // Green
                    onTap: () => _navigateToGroup(context, "Help Center", "help_center"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required String memberCount,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 0,
      color: const Color(0xFF2D2D44), // Matching your color scheme
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberCount,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  final String groupName;
  final String groupId;

  const GroupChatScreen({
    Key? key,
    required this.groupName,
    required this.groupId,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isEmojiVisible = false;
  bool _isAdmin = false;
  String? currentUserId;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _checkIfAdmin();
  }

  void _checkIfAdmin() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    if (mounted) {
      setState(() {
        _isAdmin = userDoc.data()?['role'] == 'admin';
      });
    }
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  Widget _buildEmojiPicker() {
    return Offstage(
      offstage: !_isEmojiVisible,
      child: SizedBox(
        height: 250,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() {
              _messageController.text += emoji.emoji;
            });
          },
          config: Config(
            bgColor: const Color(0xFFDEDEE8),  // Background color
            indicatorColor: Colors.purple,     // Category indicator
            iconColorSelected: Colors.purple,  // Selected category
            columns: 7,                       // Number of emojis per row
            emojiSizeMax: 32.0,               // Emoji size
            // Native emoji rendering is automatic in this version             // Emoji size
          ),
        ),
      ),
    );
  }

  Widget _buildMessageTile(Message message) {
    bool isCurrentUser = message.senderId == currentUserId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(message.senderId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            title: const Text("Unknown", style: TextStyle(color: Colors.white)),
            subtitle: Text(message.text, style: const TextStyle(color: Colors.white70)),
            trailing: Text(
              DateTime.fromMillisecondsSinceEpoch(
                message.timestamp.millisecondsSinceEpoch,
              ).toLocal().toString().substring(0, 16),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final displayName = userData['username'] ?? userData['displayName'] ?? "Unknown"; // Try multiple fields
        final isAdmin = userData['role'] == 'admin';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isAdmin ? Colors.deepPurple : Colors.grey,
            child: Text(
              displayName.substring(0, 2).toUpperCase(),
              style: const TextStyle(color: Colors.black),
            ),
          ),
          title: Row(
            children: [
              Text(
                displayName,
                style: const TextStyle(color: Colors.white),
              ),
              if (isAdmin)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Admin",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            message.text,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Text(
            DateTime.fromMillisecondsSinceEpoch(
              message.timestamp.millisecondsSinceEpoch,
            ).toLocal().toString().substring(0, 16),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = widget.groupId == 'announcements';
    final canSend = !isAnnouncement || _isAdmin;

    return BaseScaffold(
      context: context,
      currentIndex: -1,
      showBottomNavBar: false,
      child: Column(
        children: [
          AppBar(
            leading: BackButton(color: Colors.white),
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(widget.groupName, style: const TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet", style: TextStyle(color: Colors.white)));
                }

                final messages = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Message(
                    senderId: data['senderId'],
                    text: data['text'],
                    timestamp: data['timestamp'] ?? Timestamp.now(),
                  );
                }).toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (_, index) => _buildMessageTile(messages[index]),
                );
              },
            ),
          ),
          if (canSend) ...[
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isEmojiVisible = !_isEmojiVisible;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    onTap: () => setState(() => _isEmojiVisible = false),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF19192E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6C5CE7)),
                  onPressed: () => sendMessage(_messageController.text),
                ),
              ],
            ),
            _buildEmojiPicker(),
          ] else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Only admins can post here.",
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}


class Message {
  final String senderId;
  final String text;
  final Timestamp timestamp;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });
}