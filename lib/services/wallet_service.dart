import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId;

  WalletService(this._userId);

  Future<Map<String, dynamic>> getWallet() async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    DocumentSnapshot walletDoc = await _firestore
        .collection('wallets')
        .doc(user.uid)
        .get();

    if (!walletDoc.exists) {
      return await createWallet(user.uid);
    }

    return walletDoc.data() as Map<String, dynamic>;
  }

  Stream<DocumentSnapshot> walletStream() {
    User? user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('wallets')
        .doc(user.uid)
        .snapshots();
  }

  Future<Map<String, dynamic>> createWallet(String userId) async {
    String address = 'NERG-${userId.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}';

    Map<String, dynamic> newWallet = {
      'address': address,
      'balance': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': userId,
    };

    await _firestore
        .collection('wallets')
        .doc(userId)
        .set(newWallet);

    return newWallet;
  }

  Future<void> updateBalance(double amount) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _firestore
        .collection('wallets')
        .doc(user.uid)
        .update({
      'balance': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> transferBonusToMainBalance() async {
    try {
      await _firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(_firestore.collection('wallets').doc(_userId));
        final bonusBalance = walletDoc['bonusBalance'] ?? 0.0;

        if (bonusBalance > 0) {
          transaction.update(walletDoc.reference, {
            'bonusBalance': 0.0,
            'balance': FieldValue.increment(bonusBalance),
          });

          // Record the transfer transaction
          await _firestore.collection('users').doc(_userId).collection('transactions').add({
            'type': 'bonus_transfer',
            'amount': bonusBalance,
            'status': 'completed',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print("Error transferring bonus: $e");
      throw e;
    }
  }
  Future<void> applyReferralBonus(String referredByUserId) async {
    const double referralBonus = 10.0;

    final referrerWalletRef = _firestore.collection('wallets').doc(referredByUserId);
    final referrerTransactionsRef = _firestore
        .collection('users')
        .doc(referredByUserId)
        .collection('transactions');

    await _firestore.runTransaction((transaction) async {
      final referrerWalletSnap = await transaction.get(referrerWalletRef);

      if (!referrerWalletSnap.exists) {
        throw Exception('Referrer wallet not found');
      }

      final currentBonus = referrerWalletSnap.data()?['bonusBalance'] ?? 0.0;
      final currentReferralCount = referrerWalletSnap.data()?['referralCount'] ?? 0;

      transaction.update(referrerWalletRef, {
        'bonusBalance': currentBonus + referralBonus,
        'referralCount': currentReferralCount + 1,
      });

      transaction.set(referrerTransactionsRef.doc(), {
        'type': 'referral_bonus',
        'amount': referralBonus,
        'fromUser': _userId,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }


  // Add this new method:
  Future<void> refreshWallet() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('wallets').doc(user.uid).get();
  }
}