import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final String uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseService({required this.uid});

  // User Balance
  Future<double> getUserBalance() async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['balance'] ?? 0.0).toDouble();
  }

  Future<void> updateUserBalance({required double newBalance}) async {
    await _firestore.collection('users').doc(uid).update({
      'balance': newBalance,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Transactions
  Future<List<Map<String, dynamic>>> getUserTransactions({required int limit}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'],
        'amount': data['amount'],
        'counterparty': data['counterparty'],
        'time': data['timestamp']?.toDate().toString() ?? '',
      };
    }).toList();
  }

  Future<void> addUserTransaction({
    required String type,
    required double amount,
    DateTime? timestamp,
    String? counterparty,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
      'type': type,
      'amount': amount,
      'counterparty': counterparty,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    });
  }

  // Referrals
  Future<int?> getUserReferralCount() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('referrals')
        .count()
        .get();
    return snapshot.count;
  }

  // Bonus
  Future<double> getUserBonusBalance() async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['bonus'] ?? 0.0).toDouble();
  }
}