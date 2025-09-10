import 'dart:math';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// This function displays the gas history dialog.
/// [context] - BuildContext of the screen where the dialog is shown
/// [selectedGas] - The gas name selected by the user
/// [gasData] - List of past values for that gas
void showHistoryDialog(BuildContext context,String selectedGas) {
  // --- generate spots (ppm 10–200) ---
  final random = Random();
  final spots = <FlSpot>[];
  for (int i = 0; i < 30; i++) {
    final ppm = (random.nextInt(191) + 10).toDouble(); // 10..200
    spots.add(FlSpot(i.toDouble(), ppm));
  }

  // --- date labels (today back 30 days, oldest first) ---
  List<String> generateDateLabels() {
    final now = DateTime.now();
    final fmt = DateFormat('dd-MM-yyyy');
    return List.generate(30, (i) {
      final d = now.subtract(Duration(days: 29 - i));
      return fmt.format(d);
    });
  }

  final labels = generateDateLabels();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: FractionallySizedBox(
          widthFactor: 1, // ✅ 85% of phone width
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title (reduced bottom padding)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "History - $selectedGas",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Chart area (horizontal scroll if needed)
                SizedBox(
                  height: MediaQuery.of(context).size.height*0.45, // a bit taller for labels
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // make it wide enough to comfortably see 30 points
                      final double contentWidth =
                      max(constraints.maxWidth, 900);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: contentWidth,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: 29,
                              // 30 days: 0..29
                              minY: 0,
                              maxY: 250,
                              // ✅ up to 210 ppm
                              lineTouchData:
                              const LineTouchData(enabled: false),
                              borderData: FlBorderData(show: true),

                              // ✅ grid only on each 5th day (x = 0,5,10,15,20,25)
                              gridData: FlGridData(
                                show: true,
                                drawHorizontalLine: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.withOpacity(0.3),
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.grey.withOpacity(0.3),
                                  strokeWidth: 1,
                                ),
                                checkToShowVerticalLine: (value) =>
                                value % 5 == 0,
                              ),

                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    maxIncluded: false,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 5,
                                    // every 5th date
                                    getTitlesWidget: (value, _) {
                                      // 👈 paste it here
                                      final labels = generateDateLabels();
                                      if (value.toInt() < labels.length &&
                                          value % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              top: 10, left: 5),
                                          child: Transform.rotate(
                                            angle: 0, // tilt 45 degrees
                                            child: Text(
                                              labels[value.toInt()],
                                              style: const TextStyle(
                                                  fontSize: 9),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),

                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Colors.blue,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blue.withOpacity(0.18),
                                  ),
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}