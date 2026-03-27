import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

class NotificationService {
  // Use a getter for FirebaseMessaging.instance to avoid initialization on Web
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Detect platform using kIsWeb
    if (kIsWeb) {
      print("Firebase Messaging disabled on web.");
      return; 
    }

    try {
      tz.initializeTimeZones();
      
      // Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        String? token = await _fcm.getToken();
        print("FCM Token: $token");

        // Configure local notifications
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initializationSettings =
            InitializationSettings(android: initializationSettingsAndroid);
        await _localNotifications.initialize(initializationSettings);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showLocalNotification(message);
        });
      }
    } catch (e) {
      print("Notification Init Error: $e");
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'expense_alerts',
      'Expense Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      0,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleReminder() async {
    if (kIsWeb) return;

    // Cancel any existing reminder
    await _localNotifications.cancel(10);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'expense_reminders',
      'Expense Reminders',
      channelDescription: 'Reminder to add expenses if forgotten',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.zonedSchedule(
      10,
      'Forget something?',
      'It has been 10 hours since your last expense. Don\'t forget to record your spending!',
      tz.TZDateTime.now(tz.local).add(const Duration(hours: 10)),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
