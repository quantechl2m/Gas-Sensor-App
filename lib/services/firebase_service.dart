import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Stream for real-time updates (used in app UI)
  Stream<Map<String, dynamic>> listenToSensorData() {
    return _dbRef.child("ENoze/current").onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return {
        "res1": data["res1"],
        "res2": data["res2"],
        "res3": data["res3"],
        "res4": data["res4"],
      };
    });
  }

  /// One-time fetch for background task
  Future<Map<String, dynamic>> getLatestReadings() async {
    final snapshot = await _dbRef.child("ENoze/current").get();
    if (!snapshot.exists) {
      throw Exception("No data found in Firebase");
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    return {
      "res1": data["res1"],
      "res2": data["res2"],
      "res3": data["res3"],
      "res4": data["res4"],
    };
  }
}
