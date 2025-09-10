import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:workmanager/workmanager.dart';

import '../services/firebase_service.dart';
import '../services/gas_calculator.dart';
import '../services/notification_service.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(); // Important for Firebase in background

    final firebaseService = FirebaseService();
    final gasCalculator = GasCalculator();

    try {
      final readings = await firebaseService.getLatestReadings();

      // Use fire-and-forget version to avoid await issues
      gasCalculator.calculateAndNotify(readings, (concentrations) {
        // Optional: Log the concentrations
        print("Background concentrations: $concentrations");
      });

    } catch (e) {
      print("Error in background task: $e");
    }

    return Future.value(true);
  });
}
