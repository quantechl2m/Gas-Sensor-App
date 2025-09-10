import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);
  }

  static Future<void> showNotification(int id,String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gas_alert_channel',
      'Gas Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, platformDetails);
  }
}
