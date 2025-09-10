import 'notification_service.dart';
import 'package:flutter/material.dart';

class GasCalculator {
  // Thresholds
  static const double NH3_THRESHOLD = 125.0;
  static const double CO_THRESHOLD = 150.0;
  static const double METHANOL_THRESHOLD = 100.0;
  static const double NO2_THRESHOLD = 110.0;

  // Formulas
  double calculateNH3(double resistance) => 0.25 * (resistance / 1000.0) + 2.5;
  double calculateCO(double resistance) => 0.3 * (resistance / 1000.0) + 5.0;
  double calculateMethanol(double resistance) => 0.15 * (resistance / 1000.0) + 1.0;
  double calculateNO2(double resistance) => 0.1 * (resistance / 1000.0) + 0.5;

  /// Fire-and-forget calculation: use callback to update state
  void calculateAndNotify(
      Map<String, dynamic> resistances,
      void Function(Map<String, double>) onResult
      ) {
    try {
      final concentrations = {
        'NH3': calculateNH3((resistances['res1'] ?? 0.0).toDouble()),
        'CO': calculateCO((resistances['res2'] ?? 0.0).toDouble()),
        'Methanol': calculateMethanol((resistances['res3'] ?? 0.0).toDouble()),
        'NO2': calculateNO2((resistances['res4'] ?? 0.0).toDouble()),
      };

      // Update the UI through callback
      onResult(concentrations);

      // Trigger notifications asynchronously (fire-and-forget)
      _checkThresholdsAndNotify(concentrations);
    } catch (e) {
      debugPrint("Error in GasCalculator: $e");
    }
  }

  /// Async notifications
  Future<void> _checkThresholdsAndNotify(Map<String, double> concentrations) async {
    if (concentrations['NH3']! > NH3_THRESHOLD) {
      await NotificationService.showNotification(
        0,
        "Warning: High NH3 Level",
        "NH3 level exceeded safe limits: ${concentrations['NH3']!.toStringAsFixed(2)} ppm",
      );
    }

    if (concentrations['CO']! > CO_THRESHOLD) {
      await NotificationService.showNotification(
        1,
        "Warning: High CO Level",
        "CO level exceeded safe limits: ${concentrations['CO']!.toStringAsFixed(2)} ppm",
      );
    }

    if (concentrations['Methanol']! > METHANOL_THRESHOLD) {
      await NotificationService.showNotification(
        2,
        "Warning: High Methanol Level",
        "Methanol level exceeded safe limits: ${concentrations['Methanol']!.toStringAsFixed(2)} ppm",
      );
    }

    if (concentrations['NO2']! > NO2_THRESHOLD) {
      await NotificationService.showNotification(
        3,
        "Warning: High NO2 Level",
        "NO2 level exceeded safe limits: ${concentrations['NO2']!.toStringAsFixed(2)} ppm",
      );
    }
  }
}
