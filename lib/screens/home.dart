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
import 'package:firebase_database/firebase_database.dart';
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

import '../services/firebase_service.dart';
import '../services/gas_calculator.dart';
import '../widgets/gas_history_dialog.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final firebaseService = FirebaseService();
  final gasCalculator = GasCalculator();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();


  Map<String, double>? concentrations;

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

  Map<String, double> gasValues = {
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

  void _fetchGasData() async {
    try {
      final snapshot = await _databaseRef.child("ENoze/current").get();

      if (snapshot.exists) {
        print("Firebase data: ${snapshot.value}");

        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final fetchedConcentrations = {
          "res1": data["res1"] ?? 0.0,
          "res2": data["res2"] ?? 0.0,
          "res3": data["res3"] ?? 0.0,
          "res4": data["res4"] ?? 0.0,
        };

// Fire-and-forget
        gasCalculator.calculateAndNotify(fetchedConcentrations, (computedGasValues) {
          setState(() {
            concentrations = computedGasValues;
            gasValues = computedGasValues;
            concentration = gasValues[selectedGas]!.toInt();
            debugPrint("firebase: $gasValues");
          });
        });
      } else {
        print("No data found at path: ENoze/current");
        setState(() {
          concentrations = {
            "NO2": 0.0,
            "CO": 0.0,
            "NH3": 0.0,
            "Methanol": 0.0,
          };
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }



  @override
  void initState() {
    super.initState();
    gettingUserData();
    updateLanguage(getCurrentLocale());
    // _fetchGasData();
    firebaseService.listenToSensorData().listen((fetchedConcentrations) {
      gasCalculator.calculateAndNotify(fetchedConcentrations, (computedGasValues) {
        if (mounted) {
          setState(() {
            concentrations = computedGasValues;
            gasValues = computedGasValues;
            concentration = gasValues[selectedGas]!.toInt();
          });
        }
      });
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
        concentration = gasValues[selectedGas]!.toInt();

        if (gas == "NO2") {
          selectedValue = "$concentration PPM";
        } else if (gas == "CO") {
          selectedValue = "$concentration PPM";
        } else if (gas == "NH3") {
          selectedValue = "$concentration PPM";
        } else {
          selectedValue = "$concentration PPM";
        }
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
      body: concentrations==null
          ?const Center(child: CircularProgressIndicator())
      :Container(
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
                    onPressed: () => showHistoryDialog(context,selectedGas),
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
