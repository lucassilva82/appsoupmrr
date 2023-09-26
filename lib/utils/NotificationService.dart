import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class CustomNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  CustomNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class NotificationService {
  late FlutterLocalNotificationsPlugin localNotificationsPlugin;
  late AndroidNotificationDetails androidDetails;

  NotificationService() {
    localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _setupNotifications();
  }

  _setupNotifications() async {
    await _setupTimezone();
    await _initializeNotifications();
  }

  Future<void> _setupTimezone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Fazer: macOs, iOS, Linux...
    await localNotificationsPlugin.initialize(
      const InitializationSettings(
        android: android,
      ),
      // onSelectNotification: _onSelectNotification,
    );
  }

  // _onSelectNotification(String? payload) {
  //   if (payload != null && payload.isNotEmpty) {
  //     Navigator.of(Route.navigatorKey!.currentContext!).pushNamed(payload);
  //   }
  // }

  showNotification(CustomNotification notification) {
    androidDetails = const AndroidNotificationDetails(
      'lembretes_notifications_x',
      'Lembretes',
      channelDescription: 'Este canal é para lembretes',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
    );

    localNotificationsPlugin.show(notification.id, notification.title,
        notification.body, NotificationDetails(android: androidDetails),
        payload: notification.payload);
  }

  // showNotificationSchedule(CustomNotification notification) {
  //   final date = DateTime.now().add(const Duration(seconds: 5));
  //   androidDetails = const AndroidNotificationDetails(
  //     'lembretes_notifications_x',
  //     'Lembretes',
  //     channelDescription: 'Este canal é para lembretes',
  //     importance: Importance.max,
  //     priority: Priority.max,
  //     enableVibration: true,
  //   );

  //   localNotificationsPlugin.zonedSchedule(
  //     notification.id,
  //     notification.title,
  //     notification.body,
  //     tz.TZDateTime.from(date, tz.local),
  //     NotificationDetails(android: androidDetails),
  //     payload: notification.payload,
  //     androidAllowWhileIdle: true,
  //     uiLocalNotificationDateInterpretation:
  //         UILocalNotificationDateInterpretation.absoluteTime,
  //   );
  // }

  // checkForNotifications() async {
  //   final details =
  //       await localNotificationsPlugin.getNotificationAppLaunchDetails();
  //   if (details != null && details.didNotificationLaunchApp) {
  //     _onSelectNotification(details.payload);
  //   }
  // }
}
