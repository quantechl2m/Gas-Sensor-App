import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esp32sensor/authentication/change_password.dart';
import 'package:esp32sensor/intro_slider.dart';
import 'package:esp32sensor/screens/about_us.dart';
import 'package:esp32sensor/services/auth.dart';
import 'package:esp32sensor/services/edit_profile.dart';
import 'package:esp32sensor/utils/constants/constants.dart';
import 'package:esp32sensor/video/videoStream.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final box = GetStorage();
  String name = '';
  String email = '';
  String channel = '';
  String mobile = '';
  String uid = '';

  String avgConcentration = '';
  String date = '';

  late String greeting;
  late int len;
  late Map<String, dynamic> jsonResponse;
  late String url;

  Map<String, int> gasValues = {
    "NO2": 0,
    "CO": 0,
    "NH3": 0,
    "Methanol": 0,
  };

  late String resistance = "";
  int concentration = 10;
  String butane = '0';
  String carbonMonoxide = '0';
  String humidity = '92';
  String temperature = '23';
  late Timer _timer;
  int time = 11;

  String selectedGas = "NO2";

  List<FlSpot> generateHistoryData() {
    final random = Random();
    List<FlSpot> spots = [];

    for (int i = 0; i < 30; i++) {
      double ppm = (random.nextInt(191) + 10).toDouble(); // random ppm 0-200
      spots.add(FlSpot(i.toDouble(), ppm));
    }
    return spots;
  }

  void showHistoryDialog(BuildContext context) {
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

  Future<void> _loadData() async {
    url = "https://api.thingspeak.com/channels/2009308/feeds.json?results";

    http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode == 200 && _timer.isActive) {
      jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      int length = jsonResponse["feeds"].length;

      if (jsonResponse["feeds"][length - 1]["field1"] != null) {
        setState(() {
          resistance = jsonResponse["feeds"][length - 1]["field1"];
          concentration = int.parse(resistance);
        });
      } else {
        setState(() {
          concentration = 0;
        });
        if (kDebugMode) {
          print('Error: No data found for field1');
        }
      }

      if (jsonResponse["feeds"][length - 1]["field2"] != null) {
        setState(() {
          butane = jsonResponse["feeds"][length - 1]["field2"];
        });
      } else {
        setState(() {
          butane = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field2');
        }
      }

      if (jsonResponse["feeds"][length - 1]["field3"] != null) {
        setState(() {
          carbonMonoxide = jsonResponse["feeds"][length - 1]["field3"];
        });
      } else {
        setState(() {
          carbonMonoxide = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field3');
        }
      }

      if (jsonResponse["feeds"][length - 1]["field4"] != null) {
        setState(() {
          temperature = jsonResponse["feeds"][length - 1]["field4"];
        });
      } else {
        setState(() {
          temperature = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field4');
        }
      }

      if (jsonResponse["feeds"][length - 1]["field5"] != null) {
        setState(() {
          humidity = jsonResponse["feeds"][length - 1]["field5"];
        });
      } else {
        setState(() {
          humidity = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field5');
        }
      }
    }
  }

  Future<void> initNotifications() async {
    if (await Permission.notification.request().isGranted) {
      // Permission granted
    }
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> showGasNotification(
      String gas, double value, String level, int notificationId) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('gas_channel', 'Gas Alerts',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      "⚠️ Gas Alert",
      "$gas level is $level: $value ppm",
      platformDetails,
    );
  }

  Future<dynamic> gettingUserData() async {
    DocumentSnapshot snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    setState(() {
      name = (snap.data() as Map<String, dynamic>)["Name"];
      if (kDebugMode) {
        print(name);
      }
      channel = (snap.data() as Map<String, dynamic>)["channel"];
      if (kDebugMode) {
        print(channel);
      }
      mobile = (snap.data() as Map<String, dynamic>)["mobile"];
      if (kDebugMode) {
        print(mobile);
      }
      email = currentUser!.email!;
      uid = currentUser!.uid;
    });
  }

  String getGasLevel(String gas, int value) {
    switch (gas) {
      case "NO2":
        if (value <= 40) return "Good";
        if (value <= 80) return "Moderate";
        if (value <= 120) return "Unhealthy";
        return "Hazardous";
      case "CO":
        if (value <= 50) return "Good";
        if (value <= 100) return "Moderate";
        if (value <= 150) return "Unhealthy";
        return "Hazardous";
      case "NH3":
        if (value <= 30) return "Good";
        if (value <= 60) return "Moderate";
        if (value <= 120) return "Unhealthy";
        return "Hazardous";
      case "Methanol":
        if (value <= 50) return "Good";
        if (value <= 100) return "Moderate";
        if (value <= 150) return "Unhealthy";
        return "Hazardous";
      default:
        return "Good";
    }
  }

  void generateRandomGasValues() {
    final random = Random();

    // Generate random ppm for each gas (0 to 200)
    gasValues["NO2"] = random.nextInt(201);
    gasValues["CO"] = random.nextInt(201);
    gasValues["NH3"] = random.nextInt(201);
    gasValues["Methanol"] = random.nextInt(201);

    // Map gas values

    int notificationId = 0;
    gasValues.forEach((gas, value) {
      String level = getGasLevel(gas, value);
      if (level == "Unhealthy" || level == "Hazardous") {
        showGasNotification(gas, value.toDouble(), level, notificationId);
        notificationId++;
      }
    });

    // Set default displayed gas
    setState(() {
      selectedGas = "NO2";
      concentration = gasValues[selectedGas]!;
    });
  }

  @override
  void initState() {
    super.initState();
    initNotifications();
    generateRandomGasValues(); // initialize first

    gettingUserData();
    updateLanguage(getCurrentLocale());
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  final AuthService _auth = AuthService();

  final List languages = const [
    {'name': "ENGLISH", "locale": Locale('en', 'US')},
    {'name': "हिन्दी", "locale": Locale('hi', 'IN')},
    {'name': "ಕನ್ನಡ", "locale": Locale('kan', 'KAR')},
    {'name': "தமிழ்", "locale": Locale('tam', 'TN')},
  ];

  Future updateLanguage(Locale locale) async {
    Get.back();
    box.write('locale', locale.toString());
    Future.delayed(Duration.zero, () {
      Get.updateLocale(locale);
    });
  }

  Locale getCurrentLocale() {
    final box = GetStorage();
    String? localeStr = box.read('locale');

    if (localeStr == null) {
      return const Locale('en', 'US');
    } else {
      return Locale(localeStr.split('_')[0], localeStr.split('_')[1]);
    }
  }

  buildDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (builder) {
          return AlertDialog(
            title: Text(
              "Choose language".tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: "JosefinSans"),
            ),
            content: SizedBox(
              // alignment: Alignment.center,
              width: double.maxFinite,
              child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                            onTap: () {
                              updateLanguage(languages[index]['locale']);
                            },
                            child: Text(languages[index]['name'])),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return const Divider(color: Colors.blue);
                  },
                  itemCount: languages.length),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    String selectedValue = "$concentration PPM";

// Determine gas category based on OSHA-like thresholds

    void updateSelectedGas(String gas) {
      setState(() {
        selectedGas = gas;
        concentration = gasValues[selectedGas]!;

        if (gas == "NO2") {
          selectedValue = "$concentration PPM";
        } else if (gas == "CO") {
          selectedValue = "$concentration PPM";
        } else if (gas == "NH3") {
          selectedValue = "$concentration PPM";
        } else {
          selectedValue = "$concentration PPM";
        }
        // if(concentration>120){
        //   showGasNotification(selectedGas, concentration.toDouble());
        // }
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      drawer: Drawer(
        child: SingleChildScrollView(
            child: Column(
          children: [
            Container(
              color: const Color.fromARGB(255, 78, 181, 131),
              width: double.infinity,
              height: 250,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10.0, top: 40.0),
                    height: 100,
                    decoration: BoxDecoration(
                        border: Border.all(width: 2.0, color: Colors.white),
                        shape: BoxShape.circle,
                        image: const DecorationImage(
                            image: AssetImage('assets/images/soil.png'))),
                  ),
                  Text(name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      )),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
                    ),
                  )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 15.0),
              child: Column(
                children: [
                  {
                    'title': 'edit_profile'.tr,
                    'icon': Icons.edit_note_sharp,
                    'route': EditProfile(
                      name: name,
                      mobile: mobile,
                      channel: channel,
                      email: email,
                      uid: uid,
                    )
                  },
                  {
                    'title': 'change_password'.tr,
                    'icon': Icons.lock_open_sharp,
                    'route': const ChangePassword()
                  },
                  {
                    'title': 'change_language'.tr,
                    'icon': Icons.text_format_outlined,
                    'route': null
                  },
                  {
                    'title': 'how_to_use'.tr,
                    'icon': Icons.question_answer_outlined,
                    'route': const IntroSliderPage()
                  },
                  {
                    'title': 'demo_video'.tr,
                    'icon': Icons.video_camera_front_outlined,
                    'route': const MyWidget()
                  },
                  {
                    'title': 'about_us'.tr,
                    'icon': Icons.info,
                    'route': const AboutUs()
                  },
                  {'title': 'Logout'.tr, 'icon': Icons.logout, 'route': null},
                ]
                    .map((e) => InkWell(
                          onTap: () {
                            if (e['title'] == 'Logout'.tr) {
                              _auth.signOut();
                            } else if (e['title'] == 'Change Language'.tr) {
                              buildDialog(context);
                            } else {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          e['route'] as Widget));
                            }
                          },
                          child: Row(children: [
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(30.0, 20, 20, 20),
                                child: Icon(
                                  e['icon'] as IconData?,
                                  size: 25.0,
                                  color: Colors.black54,
                                )),
                            Expanded(
                                child: Text(
                              e['title'] as String,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                              ),
                            ))
                          ]),
                        ))
                    .toList(),
              ),
            )
          ],
        )),
      ),
      appBar: AppBar(
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu,
              color: Colors.black,
              size: 25,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        foregroundColor: Colors.black,
        centerTitle: true,
        toolbarHeight: 80,
        title: Text(
          'title'.tr,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          IconButton(
              iconSize: 40,
              icon: Image(
                image: AssetImage(customIcons['translationIcon']!),
              ),
              onPressed: () async {
                buildDialog(context);
              }),
        ],
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.white,
      body: Container(
        alignment: Alignment.center,
        color: const Color.fromARGB(255, 232, 241, 236),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 15),

              // ✅ Selected Gas Heading
            Stack(
              children: [
                // Title centered in screen
                Center(
                  child: Text(
                    '$selectedGas Gas',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                // History button aligned to right
                Positioned(
                  right: 12,bottom: -10,
                  child: IconButton(
                    icon: const Icon(Icons.history, color: Colors.grey, size: 35),
                    onPressed: () => showHistoryDialog(context),
                  ),
                ),
              ],
            ),
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                width: MediaQuery.of(context).size.height * 0.35,
                child: SfRadialGauge(
                  enableLoadingAnimation: true,
                  axes: <RadialAxis>[
                    RadialAxis(
                      tickOffset: 5.0,
                      majorTickStyle: const MajorTickStyle(
                          color: Color.fromARGB(255, 116, 116, 116)),
                      minimum: 0.0,
                      maximum: 200.00,
                      interval: 20.0,
                      axisLabelStyle:
                          const GaugeTextStyle(fontWeight: FontWeight.w900),
                      ranges: <GaugeRange>[
                        GaugeRange(
                          startValue: 0.00,
                          endValue: 40,
                          rangeOffset: -5.0,
                          startWidth: 20,
                          endWidth: 20,
                          label: "Pure".tr,
                          labelStyle: const GaugeTextStyle(color: Colors.white),
                          gradient: const SweepGradient(colors: [
                            Colors.greenAccent,
                            Color.fromARGB(255, 70, 164, 119),
                          ]),
                        ),
                        GaugeRange(
                          startValue: 40,
                          endValue: 80,
                          startWidth: 20,
                          endWidth: 20,
                          rangeOffset: -5.0,
                          label: "Good".tr,
                          labelStyle: const GaugeTextStyle(color: Colors.white),
                          gradient: const SweepGradient(colors: [
                            Color.fromARGB(255, 70, 164, 119),
                            Color.fromARGB(255, 133, 207, 83),
                          ]),
                        ),
                        GaugeRange(
                          label: 'Moderate'.tr,
                          labelStyle: const GaugeTextStyle(color: Colors.white),
                          startValue: 80,
                          endValue: 120,
                          startWidth: 20,
                          endWidth: 20,
                          rangeOffset: -5.0,
                          gradient: const SweepGradient(colors: [
                            Color.fromARGB(255, 133, 207, 83),
                            Color.fromARGB(255, 193, 206, 98),
                          ]),
                        ),
                        GaugeRange(
                          label: 'Unhealthy'.tr,
                          labelStyle: const GaugeTextStyle(color: Colors.white),
                          startValue: 120,
                          endValue: 160,
                          startWidth: 20,
                          endWidth: 20,
                          rangeOffset: -5.0,
                          gradient: const SweepGradient(colors: [
                            Color.fromARGB(255, 193, 206, 98),
                            Color.fromARGB(255, 225, 175, 48),
                          ]),
                        ),
                        GaugeRange(
                          label: 'Hazardous'.tr,
                          labelStyle: const GaugeTextStyle(color: Colors.white),
                          startValue: 160,
                          endValue: 200,
                          startWidth: 20,
                          endWidth: 20,
                          rangeOffset: -5.0,
                          gradient: const SweepGradient(colors: [
                            Color.fromARGB(255, 225, 175, 48),
                            Color.fromARGB(255, 240, 72, 72),
                          ]),
                        ),
                      ],
                      pointers: <GaugePointer>[
                        NeedlePointer(
                          value: concentration * 1.00,
                          enableAnimation: true,
                        )
                      ],
                      annotations: <GaugeAnnotation>[
                        GaugeAnnotation(
                          widget: Text(
                            '$concentration PPM',
                            style: TextStyle(
                                color: Color.fromARGB(255, 52, 106, 80),
                                fontFamily: 'JosefinSans',
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.025),
                          ),
                          positionFactor: 0.5,
                          angle: 90,
                        )
                      ],
                    )
                  ],
                ),
              ),

              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(10.0),
                            width: MediaQuery.of(context).size.width * 0.27,
                            height: MediaQuery.of(context).size.width * 0.27,
                            decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 8, 86, 50),
                                borderRadius: BorderRadius.circular(100)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  '$temperature°C',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'JosefinSans',
                                      fontSize:
                                          MediaQuery.of(context).size.height *
                                              0.025),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'Temperature',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: const Color.fromARGB(255, 8, 86, 50),
                                fontFamily: 'JosefinSans',
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.025),
                          ),
                        ),
                      ],
                    ),
                    Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(10.0),
                              width: MediaQuery.of(context).size.width * 0.27,
                              height: MediaQuery.of(context).size.width * 0.27,
                              decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 8, 86, 50),
                                  borderRadius: BorderRadius.circular(100)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$humidity°RH%',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'JosefinSans',
                                        fontSize:
                                            MediaQuery.of(context).size.height *
                                                0.025),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              'Humidity'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: const Color.fromARGB(255, 8, 86, 50),
                                  fontFamily: 'JosefinSans',
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.025),
                            ),
                          ),
                        ]),
                  ]),

              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: (() {
                      selectedGas = "NO2";
                      updateSelectedGas(selectedGas);
                    }),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.075,
                      width: MediaQuery.of(context).size.width * 0.9,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white),
                      child: Text(
                        "NO2".tr,
                        style: TextStyle(
                            fontFamily: 'JosefinSans',
                            color: const Color.fromARGB(255, 8, 86, 50),
                            fontSize:
                                MediaQuery.of(context).size.height * 0.021,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: (() {
                      selectedGas = "CO";
                      updateSelectedGas(selectedGas);
                    }),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.075,
                      width: MediaQuery.of(context).size.width * 0.9,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white),
                      child: Text(
                        "CO".tr,
                        style: TextStyle(
                            fontFamily: 'JosefinSans',
                            color: const Color.fromARGB(255, 8, 86, 50),
                            fontSize:
                                MediaQuery.of(context).size.height * 0.021,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: (() {
                      selectedGas = "NH3";
                      updateSelectedGas(selectedGas);
                    }),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.075,
                      width: MediaQuery.of(context).size.width * 0.9,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white),
                      child: Text(
                        'NH3'.tr,
                        style: TextStyle(
                            fontFamily: 'JosefinSans',
                            color: const Color.fromARGB(255, 8, 86, 50),
                            fontSize:
                                MediaQuery.of(context).size.height * 0.021,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: (() {
                      selectedGas = "Methanol";
                      updateSelectedGas(selectedGas);
                    }),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.075,
                      width: MediaQuery.of(context).size.width * 0.9,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white),
                      child: Text(
                        'Methanol'.tr,
                        style: TextStyle(
                            fontFamily: 'JosefinSans',
                            color: const Color.fromARGB(255, 8, 86, 50),
                            fontSize:
                                MediaQuery.of(context).size.height * 0.021,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
