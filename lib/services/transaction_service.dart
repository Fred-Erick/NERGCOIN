import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNERG(String recipientAddress, double amount) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    DocumentReference senderRef = _firestore.collection('wallets').doc(user.uid);
    DocumentSnapshot senderDoc = await senderRef.get();

    double currentBalance = senderDoc['balance'];
    if (currentBalance < amount) {
      throw Exception('Insufficient balance');
    }

    QuerySnapshot recipientQuery = await _firestore
        .collection('wallets')
        .where('address', isEqualTo: recipientAddress)
        .limit(1)
        .get();

    if (recipientQuery.docs.isEmpty) {
      throw Exception('Recipient wallet not found');
    }

    await _firestore.runTransaction((transaction) async {
      transaction.update(senderRef, {
        'balance': FieldValue.increment(-amount),
      });

      transaction.update(recipientQuery.docs.first.reference, {
        'balance': FieldValue.increment(amount),
      });

      transaction.set(_firestore.collection('transactions').doc(), {
        'senderId': user.uid,
        'recipientId': recipientQuery.docs.first.id,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'currency': 'NERG',
      });
    });
  }

  Stream<QuerySnapshot> getTransactionHistory() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    return _firestore
        .collection('transactions')
        .where('senderId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add these new methods:
  Stream<QuerySnapshot> transactionStream() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('transactions')
        .where(Filter.or(
      Filter('senderId', isEqualTo: user.uid),
      Filter('recipientId', isEqualTo: user.uid),
    ))
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> refreshTransactions() async {
    // This forces the stream to update by reading the data again
    await _firestore.collection('transactions').limit(1).get();
  }
}