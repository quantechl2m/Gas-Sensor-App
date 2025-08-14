import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esp32sensor/authentication/change_password.dart';
import 'package:esp32sensor/intro_slider.dart';
import 'package:esp32sensor/screens/about_us.dart';
import 'package:esp32sensor/services/auth.dart';
import 'package:esp32sensor/services/edit_profile.dart';
import 'package:esp32sensor/utils/constants/constants.dart';
import 'package:esp32sensor/video/videoStream.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

import 'gas_analyzer.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final currentUser = FirebaseAuth.instance.currentUser;
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

  late String resistance = "";
  int concentration = 0;
  String butane = '0';
  String carbonDioxide = '0';
  String humidity = '0';
  String temperature = '0';
  late Timer _timer;
  int time = 11;

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
          carbonDioxide = jsonResponse["feeds"][length - 1]["field3"];
        });
      }
      else {
        setState(() {
          carbonDioxide = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field3');
        }
      }

      if (jsonResponse["feeds"][length - 1]["field4"] != null) {
        setState(() {
          temperature = jsonResponse["feeds"][length - 1]["field4"];
        });
      }
      else {
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
      }
      else {
        setState(() {
          humidity = '0';
        });
        if (kDebugMode) {
          print('Error: No data found for field5');
        }
      }
    }
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

  @override
  void initState() {
    super.initState();
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Text(
            //   "message_gas".tr,
            //   style: TextStyle(
            //       fontFamily: 'JosefinSans',
            //       color: const Color.fromARGB(255, 78, 181, 131),
            //       fontSize: MediaQuery.of(context).size.height * 0.05),
            // ),

            Padding(
              padding: const EdgeInsets.all(5),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.56,
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: const Color.fromARGB(255, 8, 86, 50),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.10,
                          width: MediaQuery.of(context).size.width * 0.70,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              image: DecorationImage(
                                  image: AssetImage(
                                      "assets/images/gasindustry.png"),
                                  fit: BoxFit.contain)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 10.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(10.0),
                                      width:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      height:
                                      MediaQuery.of(context).size.width *
                                          0.2,
                                      decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 233, 231, 231),
                                          borderRadius:
                                          BorderRadius.circular(100)),
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            '$temperature °C',
                                            style: TextStyle(
                                                color: const Color.fromARGB(
                                                    255, 40, 132, 90),
                                                fontFamily: 'JosefinSans',
                                                fontSize:
                                                MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                    0.018),
                                          ),
                                          Text(
                                            '$humidity RH%',
                                            style: TextStyle(
                                                color: const Color.fromARGB(
                                                    255, 40, 132, 90),
                                                fontFamily: 'JosefinSans',
                                                fontSize:
                                                MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                    0.018),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'Temp. and RH%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'JosefinSans',
                                          fontSize: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.018),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(10.0),
                                      width:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      height:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(100)),
                                      child: Text(
                                        '$concentration PPM',
                                        style: TextStyle(
                                            color: const Color.fromARGB(
                                                255, 40, 132, 90),
                                            fontFamily: 'JosefinSans',
                                            fontSize: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.023),
                                      ),
                                    ),
                                  ),
                                  RichText(
                                      text: TextSpan(
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'JosefinSans',
                                              fontSize: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                                  0.02),
                                          children: [
                                            const TextSpan(text: 'NO'),
                                            WidgetSpan(
                                              child: Transform.translate(
                                                offset: const Offset(0.0, 3.0),
                                                child: Text(
                                                  '2',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: 'JosefinSans',
                                                      fontSize:
                                                      MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                          0.015),
                                                ),
                                              ),
                                            ),
                                          ]))
                                  // Text(
                                  //   'No2',
                                  //   style: TextStyle(
                                  //       color: Colors.white,
                                  //       fontFamily: 'JosefinSans',
                                  //       fontSize: MediaQuery.of(context)
                                  //               .size
                                  //               .height *
                                  //           0.02),
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 10.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(10.0),
                                      width:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      height:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 40, 132, 90),
                                          borderRadius:
                                          BorderRadius.circular(100)),
                                      child: Text(
                                        '$butane PPM',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'JosefinSans',
                                            fontSize: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.021),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Butane',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'JosefinSans',
                                        fontSize: MediaQuery.of(context)
                                            .size
                                            .height *
                                            0.02),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(10.0),
                                      width:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      height:
                                      MediaQuery.of(context).size.width *
                                          0.23,
                                      decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 68, 158, 115),
                                          borderRadius:
                                          BorderRadius.circular(100)),
                                      child: Text(
                                        '$carbonDioxide PPM',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'JosefinSans',
                                            fontSize: MediaQuery.of(context)
                                                .size
                                                .height *
                                                0.021),
                                      ),
                                    ),
                                  ),
                                  RichText(
                                      text: TextSpan(
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'JosefinSans',
                                              fontSize: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                                  0.02),
                                          children: [
                                            const TextSpan(text: 'CO'),
                                            WidgetSpan(
                                              child: Transform.translate(
                                                offset: const Offset(0.0, 3.0),
                                                child: Text(
                                                  '2',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: 'JosefinSans',
                                                      fontSize:
                                                      MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                          0.015),
                                                ),
                                              ),
                                            ),
                                          ]))
                                  // Text(
                                  //   'Co2',
                                  //   style: TextStyle(
                                  //       color: Colors.white,
                                  //       fontFamily: 'JosefinSans',
                                  //       fontSize: MediaQuery.of(context)
                                  //               .size
                                  //               .height *
                                  //           0.02),
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ]),
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
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            GasAnalyzer(title: 'NO2'.tr, dataParameter2: "field1")));
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
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => GasAnalyzer(
                          title: 'CO2'.tr,
                          dataParameter2: "field3",
                        )));
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
                      "CO2".tr,
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
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const GasAnalyzer(
                          title: 'Butane',
                          dataParameter2: "field2",
                        )));
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
                      'Butane',
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
          ],
        ),
      ),
    );
  }
}
