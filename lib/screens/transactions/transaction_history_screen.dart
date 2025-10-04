import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../base_scaffold.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _currentFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      _isLoading = false;
    }
  }

  Stream<QuerySnapshot> get _transactionStream {
    if (_currentUser == null) {
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true);

    if (_currentFilter != 'all') {
      query = query.where('type', isEqualTo: _currentFilter);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _applySearchFilter(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final tx = doc.data() as Map<String, dynamic>;
      final amount = tx['amount'].toString();
      final counterparty = tx['counterparty']?.toString() ?? '';
      final txHash = tx['txHash']?.toString() ?? '';
      return amount.contains(_searchQuery) ||
          counterparty.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          txHash.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      context: context,
      currentIndex: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Transaction History",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt, color: Color(0xFF6C5CE7)),
                  onPressed: () => _showFilterDialog(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "All your NERG transactions in one place",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSearchField(),
          const SizedBox(height: 8),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
          filled: true,
          fillColor: const Color(0xFF3A3A4A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_currentUser == null) {
      return _buildAuthRequiredView();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _transactionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          _isLoading = false;
          debugPrint('Transaction error: ${snapshot.error}');
          return _errorView("Failed to load transactions. Please try again.");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          _isLoading = false;
          return _errorView("No transactions found");
        }

        _isLoading = false;
        final filteredDocs = _applySearchFilter(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return _errorView("No matching transactions");
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = filteredDocs[index].data() as Map<String, dynamic>;
            return _TransactionCard(
              key: ValueKey(tx['txHash'] ?? tx['timestamp']),
              transaction: tx,
              onTap: () => _showTransactionDetails(context, tx),
            );
          },
        );
      },
    );
  }

  Widget _buildAuthRequiredView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Authentication Required",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Please sign in to view your transaction history",
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to your auth screen
              // Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text("Sign In"),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
            },
            child: const Text(
              "Retry",
              style: TextStyle(color: Color(0xFF6C5CE7)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Filter Transactions",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFilterOption("All Transactions", 'all', setModalState),
                  _buildFilterOption("Received Only", 'received', setModalState),
                  _buildFilterOption("Sent Only", 'sent', setModalState),
                  _buildFilterOption("Mining Rewards", 'mining_reward', setModalState),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                        ),
                        child: const Text("Apply"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterOption(
      String label, String value, void Function(void Function()) setModalState) {
    final isSelected = _currentFilter == value;
    return InkWell(
      onTap: () => setModalState(() => _currentFilter = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C5CE7)
                      : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D44),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Transaction Details",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow("Type", tx['type'].toString().toUpperCase()),
            _buildDetailRow("Amount", "${tx['amount']} NERG"),
            if (tx['counterparty'] != null)
              _buildDetailRow(
                tx['type'] == "received" ? "From" : "To",
                tx['counterparty'].toString(),
              ),
            _buildDetailRow(
              "Date",
              _formatTimestamp(tx['timestamp']),
            ),
            _buildDetailRow(
              "Status",
              tx['status'].toString(),
              isStatus: true,
            ),
            _buildDetailRow("Network Fee", "${tx['fee'] ?? 0} NERG"),
            if (tx['blockHeight'] != null)
              _buildDetailRow("Block Height", tx['blockHeight'].toString()),
            if (tx['txHash'] != null) ...[
              const Divider(color: Colors.white24, height: 30),
              Text(
                "Transaction Hash",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: tx['txHash'].toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Copied to clipboard"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx['txHash'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.copy, color: Colors.white70, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text("View on Explorer"),
                  onPressed: () => _openBlockExplorer(tx['txHash'].toString()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Today • ${_formatTime(date)}';
      } else if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Yesterday • ${_formatTime(date)}';
      } else {
        return '${date.day}/${date.month}/${date.year} • ${_formatTime(date)}';
      }
    }
    return timestamp.toString();
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: value == "pending"
                    ? Colors.amber.withOpacity(0.2)
                    : const Color(0xFF00B894).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: value == "pending"
                      ? Colors.amber
                      : const Color(0xFF00B894),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openBlockExplorer(String txHash) async {
    final url = 'https://explorer.nergblock.io/tx/$txHash';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not launch block explorer"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;

  const _TransactionCard({
    Key? key,
    required this.transaction,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] ?? 'unknown';
    final amount = transaction['amount']?.toString() ?? '0';
    final counterparty = transaction['counterparty']?.toString() ?? '';
    final timestamp = transaction['timestamp'];
    final status = transaction['status']?.toString() ?? 'pending';

    final isSent = type == 'sent';
    final isMining = type == 'mining_reward';
    final amountColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00B894);

    final typeLabel = isMining
        ? "Mining Reward"
        : isSent
        ? "Sent NERG"
        : "Received NERG";

    final icon = isMining
        ? Icons.diamond
        : isSent
        ? Icons.arrow_upward
        : Icons.arrow_downward;

    return Card(
      elevation: 0,
      color: const Color(0xFF2D2D44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amountColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: amountColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${isSent ? '-' : '+'}$amount",
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isMining
                              ? _formatTimestamp(timestamp)
                              : "${isSent ? "To" : "From"}: $counterparty • ${_formatTimestamp(timestamp)}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        if (status == "pending")
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "Pending",
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown";
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Today • ${_formatTime(date)}';
      } else if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
    return timestamp.toString();
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}