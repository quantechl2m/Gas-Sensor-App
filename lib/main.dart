import 'package:esp32sensor/intro_slider.dart';
import 'package:esp32sensor/screens/home.dart';
import 'package:esp32sensor/services/auth.dart';
import 'package:esp32sensor/services/notification_service.dart';
import 'package:esp32sensor/utils/constants/LocalString.dart';
import 'package:esp32sensor/utils/pojo/app_user.dart';
import 'package:esp32sensor/wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'background/background_task.dart';

void main() async {
  const String taskName = "gasMonitoringTask";

  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
      apiKey: "AIzaSyAvi6WaShC_CVE7tBJiCfmV5JvXuU0-jsU",
      appId: "1:860409416045:web:e3a6df2904faa584f1b264",
      messagingSenderId: "860409416045",
      projectId: "gassensor-83678",
      storageBucket: "gassensor-83678.appspot.com",
    ));
  } else {
    await Firebase.initializeApp();

  }
  await NotificationService.initialize();
  print("Firebase initialized successfully!");


  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Schedule background task every 15 minutes
  Workmanager().registerPeriodicTask(
    "1",                 // unique ID
    taskName,            // task name
    frequency: const Duration(minutes: 15),

  );
  runApp(GetMaterialApp(
    translations: LocalString(),
    locale: const Locale('en', 'US'),
    debugShowCheckedModeBanner: false,
    routes: {
      '/intro': (context) => const IntroSliderPage(),
      '/home': (context) => const Homepage(),
    },
    home: StreamProvider<AppUser>.value(
        initialData: AppUser(uid: ""),
        value: AuthService().user,
        child: const Wrapper()),
    // initialRoute: RouteClass.getHomeRoute(),
    // getPages: RouteClass.routes,
    // routes: {
    //   "/":(context)=> Homepage(),
    //   "/gasSection":(context)=> GasPage(),
    //   "/waterSection":(context)=> waterPage(),
    //   "/soilSection":(context)=> soilPage(),
    // },
  ));
}
