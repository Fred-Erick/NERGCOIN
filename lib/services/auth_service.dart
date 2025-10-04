import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Sign Up with Email & Password - UPDATED with username and referral
  Future<User?> signUpWithEmail(
      String email,
      String password,
      {required String username,
        String? referredBy}
      ) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document with username and referral info
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'username': username.trim(),
        'displayName': username.trim(),
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'referredBy': referredBy?.trim() ?? '',
        'role': 'user',
        'uid': userCredential.user?.uid,
      });

      // Create wallet with bonus tracking
      await _firestore.collection('wallets').doc(userCredential.user?.uid).set({
        'address': 'ner_${_generateRandomString(16)}',
        'balance': 0.0,
        'bonusBalance': 0.0,
        'referralCount': 0,
        'lastMined': null,
        'userId': userCredential.user?.uid,
      });

      // Process referral if exists
      if (referredBy != null && referredBy.isNotEmpty) {
        await _processReferral(referredBy, userCredential.user!.uid);
      }

      // Update auth user display name
      await userCredential.user?.updateDisplayName(username.trim());
      await userCredential.user?.reload();

      return userCredential.user;
    } catch (e) {
      print("❌ Error during Sign-Up: $e");
      return null;
    }
  }

  /// Process referral bonus (updated with better error handling)
  Future<void> _processReferral(String referrerId, String newUserId) async {
    try {
      // Verify referrer exists
      final referrerDoc = await _firestore.collection('users').doc(referrerId).get();
      if (!referrerDoc.exists) {
        print("⚠️ Referrer does not exist: $referrerId");
        return;
      }

      // Update referrer's stats
      await _firestore.runTransaction((transaction) async {
        // Get referrer's wallet
        final walletDoc = await transaction.get(
            _firestore.collection('wallets').doc(referrerId)
        );

        if (walletDoc.exists) {
          // Update referrer's wallet
          transaction.update(
              _firestore.collection('wallets').doc(referrerId), {
            'referralCount': FieldValue.increment(1),
            'bonusBalance': FieldValue.increment(0.05), // 0.05 NERG bonus
          }
          );

          // Create referral transaction
          transaction.set(
              _firestore.collection('users')
                  .doc(referrerId)
                  .collection('transactions')
                  .doc(), // Auto-generated ID
              {
                'type': 'referral_bonus',
                'amount': 0.05,
                'status': 'completed',
                'timestamp': FieldValue.serverTimestamp(),
                'referredUserId': newUserId,
              }
          );
        }
      });

      // Give new user a signup bonus
      await _firestore.collection('wallets').doc(newUserId).update({
        'bonusBalance': FieldValue.increment(0.025), // 0.025 NERG signup bonus
      });

      await _firestore.collection('users').doc(newUserId).collection('transactions').add({
        'type': 'signup_bonus',
        'amount': 0.025,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("❌ Error processing referral: $e");
    }
  }

  /// ✅ Sign In with Email & Password (updated with username check)
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verify username exists in Firestore
      final userDoc = await _firestore.collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (!userDoc.exists || userDoc.data()?['username'] == null) {
        print("⚠️ User document or username missing - creating default");
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'username': email.split('@').first,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        }, SetOptions(merge: true));
      }

      return userCredential.user;
    } catch (e) {
      print("❌ Error during Sign-In: $e");
      return null;
    }
  }

  /// ✅ Sign In with Google (updated with username handling)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      // Create/update user document with username
      await _firestore.collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'email': googleUser.email,
        'username': googleUser.displayName ??
            googleUser.email?.split('@').first,
        'displayName': googleUser.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
        'uid': userCredential.user?.uid
      }, SetOptions(merge: true));

      // Create wallet if doesn't exist
      await _firestore.collection('wallets')
          .doc(userCredential.user?.uid)
          .set({
        'address': 'ner_${_generateRandomString(16)}',
        'balance': 0.0,
        'bonusBalance': 0.0,
        'referralCount': 0,
        'lastMined': null,
        'userId': userCredential.user?.uid,
      }, SetOptions(merge: true));

      return userCredential.user;
    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  /// ✅ Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      print("✅ Signed Out Successfully");
    } catch (e) {
      print("❌ Error during sign out: $e");
    }
  }

  /// Generate random string for wallet address
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    }

  /// Migration helper for existing users
  static Future<void> migrateExistingUsers() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in users.docs) {
      final data = doc.data();
      if (data['username'] == null) {
        batch.update(doc.reference, {
          'username': data['email']?.split('@').first ?? 'user${doc.id.substring(0, 6)}'
        });
      }
    }

    await batch.commit();
    print("✅ User migration completed");
  }
}