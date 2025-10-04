import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Import for PlatformException

// This is the top-level function that Workmanager will call.
// It must be a static or top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Native called background task: $task");
    try {
      final userId = inputData?['userId'];
      if (userId == null) {
        debugPrint('Error: userId is null in background task inputData.');
        return Future.value(false);
      }

      final HttpsCallable processMiningActivity = FirebaseFunctions.instance.httpsCallable('processMiningActivityCallable');
      final result = await processMiningActivity.call();
      debugPrint('processMiningActivity result: ${result.data}');

      final sessionDoc = await FirebaseFirestore.instance.collection('miningSessions').doc(userId).get();
      if (sessionDoc.exists) {
        final status = sessionDoc.data()?['status'];
        if (status == 'completed' || status == 'failed' || status == 'stopped') {
          debugPrint('Mining session $status for user $userId. Cancelling Workmanager task.');
          try {
            await Workmanager().cancelByUniqueName('mining_task_$userId');
          } on PlatformException catch (e) {
            debugPrint('PlatformException during Workmanager cancel in background: $e');
          } catch (e) {
            debugPrint('Error during Workmanager cancel in background: $e');
          }
        }
      }

      return Future.value(true);
    } catch (e, stack) {
      debugPrint('Error executing background task: $e\n$stack');
      return Future.value(false);
    }
  });
}

class MiningService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, bool> _isMining = HashMap();
  final Map<String, double> _currentMinedAmount = HashMap();
  final Map<String, DateTime?> _lastMinedTime = HashMap();
  final Map<String, String?> _lastError = HashMap();

  Stream<DocumentSnapshot> miningSessionStream(String userId) {
    return _firestore.collection('miningSessions').doc(userId).snapshots();
  }

  void updateMiningStateFromFirestore(String userId, Map<String, dynamic> data) {
    debugPrint('Updating mining state for $userId: $data');
    try {
      final bool wasMining = _isMining[userId] ?? false;
      final bool nowMining = data['status'] == 'in_progress';

      final oldAmount = _currentMinedAmount[userId] ?? 0.0;
      final newAmount = (data['currentMinedAmount'] ?? 0.0).toDouble();
      debugPrint('Amount changed from $oldAmount to $newAmount');

      _isMining[userId] = nowMining;
      _currentMinedAmount[userId] = (data['currentMinedAmount'] ?? 0.0).toDouble();
      _lastMinedTime[userId] = (data['lastProcessedAt'] as Timestamp?)?.toDate();
      _lastError[userId] = (data['errorMessage'] as String?);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating mining state: $e');
      _lastError[userId] = 'Failed to update mining state: ${e.toString()}';
      notifyListeners();
    }
  }

  bool isMining(String userId) => _isMining[userId] ?? false;
  double currentMinedAmount(String userId) => _currentMinedAmount[userId] ?? 0.0;
  DateTime? lastMinedTime(String userId) => _lastMinedTime[userId];
  String? lastError(String userId) => _lastError[userId];

  Future<void> startDailyMining() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _lastError['global'] = "User not logged in.";
      notifyListeners();
      return;
    }

    try {
      _lastError.remove(userId);
      notifyListeners();

      final HttpsCallable startMining = _functions.httpsCallable('startMiningSession');
      final result = await startMining.call();
      debugPrint('startMiningSession result: ${result.data}');

      if (result.data['status'] != 'success') {
        _lastError[userId] = result.data['message'] ?? "Failed to start mining session.";
        notifyListeners();
      }
    } on FirebaseFunctionsException catch (e) {
      _lastError[userId] = e.message ?? "An unknown error occurred.";
      debugPrint('FirebaseFunctionsException: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      _lastError[userId] = e.message ?? "Platform error occurred.";
      debugPrint('PlatformException: ${e.code} - ${e.message}');
    } catch (e) {
      _lastError[userId] = e.toString();
      debugPrint('Error starting mining: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopMining(String userId) async {
    if (!isMining(userId)) return;

    try {
      if (!kIsWeb) {
        try {
          await Workmanager().cancelByUniqueName('mining_task_$userId');
          debugPrint('Workmanager task cancelled for user: $userId');
        } on PlatformException catch (e) {
          debugPrint('PlatformException during Workmanager cancel: $e');
        } catch (e) {
          debugPrint('Error during Workmanager cancel: $e');
        }
      } else {
        debugPrint('Web mining timer stopped for user: $userId');
      }

      final HttpsCallable finalizeMining = _functions.httpsCallable('finalizeMiningSession');
      await finalizeMining.call({'userId': userId});
      debugPrint('finalizeMiningSession called for user: $userId');

    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException during stopMining: ${e.code} - ${e.message}');
      _lastError[userId] = e.message ?? "Error finalizing mining session.";
    } on PlatformException catch (e) {
      debugPrint('PlatformException during stopMining: ${e.code} - ${e.message}');
      _lastError[userId] = e.message ?? "Platform error occurred.";
    } catch (e) {
      debugPrint('Error stopping mining: $e');
      _lastError[userId] = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshMiningState(String userId) async {
    try {
      final doc = await _firestore.collection('miningSessions').doc(userId).get();
      if (doc.exists) {
        updateMiningStateFromFirestore(userId, doc.data()!);
      }
    } catch (e) {
      debugPrint('Error refreshing mining state: $e');
      _lastError[userId] = 'Failed to refresh mining state';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}