import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../transactions/transaction_history_screen.dart';
import 'qr_scan_screen.dart';
import '../../base_scaffold.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FormState> _sendFormKey = GlobalKey<FormState>();
  final TextEditingController _sendAmountController = TextEditingController();
  final TextEditingController _recipientAddressController = TextEditingController();

  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00B894);
  final Color _accentColor = const Color(0xFFFD79A8);
  final Color _darkBackground = const Color(0xFF1E1E2D);
  final Color _lightBackground = const Color(0xFF2D2D44);
  final Color _successColor = const Color(0xFF00E676);
  final Color _errorColor = const Color(0xFFFF5252);

  bool _isSending = false;

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Address copied to clipboard"),
        backgroundColor: _primaryColor,
      ),
    );
  }

  Future<void> _launchQRScanner(BuildContext context) async {
    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScanScreen()),
    );
    if (scannedAddress != null && mounted) {
      setState(() {
        _recipientAddressController.text = scannedAddress;
      });
    }
  }

  Future<void> _sendTransaction(BuildContext context) async {
    if (!_sendFormKey.currentState!.validate()) return;

    final amount = double.parse(_sendAmountController.text);
    final recipient = _recipientAddressController.text.trim();
    final user = _auth.currentUser;

    if (user == null || !mounted) return;

    // Prevent sending to self
    if (recipient == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Cannot send to yourself"),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    final uid = user.uid;
    final walletRef = _firestore.collection('wallets').doc(uid);
    final recipientWalletRef = _firestore.collection('wallets').doc(recipient);
    final recipientUserRef = _firestore.collection('users').doc(recipient);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _darkBackground,
        title: const Text("Confirm Transaction", style: TextStyle(color: Colors.white)),
        content: Text(
          "Send $amount NERG to:\n${recipient.substring(0, 6)}...${recipient.substring(recipient.length - 4)}?",
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _successColor),
            child: const Text("Send"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      await _firestore.runTransaction((txn) async {
        // 1. Verify recipient exists
        final recipientSnapshot = await txn.get(recipientUserRef);
        if (!recipientSnapshot.exists) {
          throw Exception("Recipient does not exist.");
        }

        // 2. Get sender balance
        final senderSnapshot = await txn.get(walletRef);
        final senderBalance = (senderSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;

        if (senderBalance < amount) {
          throw Exception("Insufficient balance");
        }

        // Update sender balance
        txn.update(walletRef, {'balance': senderBalance - amount});

        // Update recipient balance
        final recipientWalletSnapshot = await txn.get(recipientWalletRef);
        final recipientBalance = (recipientWalletSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        txn.update(recipientWalletRef, {'balance': recipientBalance + amount});

        // Record transaction for sender
        final senderTxRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc();
        txn.set(senderTxRef, {
          'amount': amount,
          'type': 'sent',
          'recipient': recipient,
          'timestamp': FieldValue.serverTimestamp(),
          'isIncoming': false,
        });

        // Record transaction for recipient
        final recipientTxRef = _firestore
            .collection('users')
            .doc(recipient)
            .collection('transactions')
            .doc();
        txn.set(recipientTxRef, {
          'amount': amount,
          'type': 'received',
          'sender': uid,
          'timestamp': FieldValue.serverTimestamp(),
          'isIncoming': true,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Successfully sent $amount NERG"),
            backgroundColor: _successColor,
          ),
        );

        _sendAmountController.clear();
        _recipientAddressController.clear();
        Navigator.pop(context); // Close dialog
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Firebase Error: ${e.message ?? 'Unknown error'}"),
          backgroundColor: _errorColor,
        ),
      );
    } catch (e, stack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Transaction Failed: ${e.toString()}"),
          backgroundColor: _errorColor,
        ),
      );
      debugPrint("Transaction error details: $e");
      debugPrint("Stack trace: $stack");
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showSendDialog(BuildContext context, double balance) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _sendFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Send NERG",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _recipientAddressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Recipient Address",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.qr_code_scanner, color: _primaryColor),
                      onPressed: () => _launchQRScanner(context),
                    ),
                  ),
                  validator: (value) =>
                  (value == null || value.trim().length < 10) ? 'Invalid address' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _sendAmountController,
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Amount (NERG)",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null || amount <= 0) return 'Invalid amount';
                    if (amount > balance) return 'Insufficient balance';
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: _isSending ? null : () => _sendTransaction(context),
                      style: ElevatedButton.styleFrom(backgroundColor: _successColor),
                      child: _isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Send"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReceiveDialog(BuildContext context, String address) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Your Wallet Address",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 20),
              SelectableText(
                address,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Share.share("My NergNet Wallet Address: $address"),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _copyToClipboard(context, address);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy"),
                    style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("User not signed in"));

    final uid = user.uid;
    final walletRef = _firestore.collection('wallets').doc(uid);
    final transactionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots();

    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 8);
    final shortenedAddress =
        '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}';

    return BaseScaffold(
      context: context,
      currentIndex: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Wallet",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: walletRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red));
                }
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final balance = (snapshot.data!.data() as Map<String, dynamic>)['balance'] ?? 0.0;
                return Card(
                  color: _primaryColor.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text("NERG Balance",
                          style:
                          TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 10),
                      Text(
                        currencyFormat.format(balance),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => _showReceiveDialog(context, uid),
              child: Card(
                color: _lightBackground,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shortenedAddress,
                              style: const TextStyle(color: Colors.white)),
                          Text(
                            "Tap to view full address",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: _primaryColor),
                      onPressed: () => _copyToClipboard(context, uid),
                    )
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Transactions",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionHistoryScreen(),
                    ),
                  ),
                  child: Text("View All", style: TextStyle(color: _primaryColor)),
                ),
              ],
            ),
            StreamBuilder<QuerySnapshot>(
              stream: transactionRef,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error loading transactions: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("No transactions yet",
                      style: TextStyle(color: Colors.white70));
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isIncoming = data['isIncoming'] ??
                        (data['type'] == 'received' || data['type'] == 'mining_reward');
                    final date = (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    final type = data['type']?.toString()?.toLowerCase() ?? '';

                    return Card(
                      color: _lightBackground,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIncoming
                              ? _successColor
                              : _errorColor)
                              .withOpacity(0.2),
                          child: Icon(
                            type.contains('mining')
                                ? Icons.diamond
                                : isIncoming
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIncoming ? _successColor : _errorColor,
                          ),
                        ),
                        title: Text(
                          type.contains('mining') ? 'Mining Reward' : isIncoming ? 'Received' : 'Sent',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                        trailing: Text(
                          '${isIncoming ? '+' : '-'}${currencyFormat.format(data['amount'] ?? 0)}',
                          style: TextStyle(
                            color: isIncoming ? _successColor : _errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showReceiveDialog(context, uid),
                    icon: const Icon(Icons.qr_code),
                    label: const Text("Receive"),
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: walletRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final balance = (snapshot.data?.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;
                      return ElevatedButton.icon(
                        onPressed: () => _showSendDialog(context, balance),
                        icon: const Icon(Icons.send),
                        label: const Text("Send"),
                        style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor),
                      );
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sendAmountController.dispose();
    _recipientAddressController.dispose();
    super.dispose();
  }
}