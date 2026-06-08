import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/notification_model.dart';
import '../data/store.dart';

class NotificationService {
  final String _storageKey = 'notifications';

  Future<List<NotificationModel>> getNotifications() async {
    List<NotificationModel> notifications = [];

    // 1. Carregar do Store (Flutter)
    final data = await Store.getString(_storageKey);
    if (data != null && data.isNotEmpty) {
      List<dynamic> list = jsonDecode(data);
      notifications.addAll(list.map((e) => NotificationModel.fromMap(e)));
    }

    // 3. Remover duplicatas e ordenar
    final uniqueNotifications = <String, NotificationModel>{};
    for (final notification in notifications) {
      final key =
          '${notification.title}_${notification.timestamp.millisecondsSinceEpoch}';
      uniqueNotifications[key] = notification;
    }

    final result = uniqueNotifications.values.toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return result;
  }

  Future<void> saveNotifications(List<NotificationModel> notifications) async {
    String data = jsonEncode(notifications.map((e) => e.toMap()).toList());
    await Store.saveString(_storageKey, data);
  }

  Future<void> addNotification(NotificationModel notification) async {
    List<NotificationModel> notifications = await getNotifications();
    notifications.add(notification);
    await saveNotifications(notifications);
  }

  Future<void> markAsClicked(String notificationId) async {
    List<NotificationModel> notifications = await getNotifications();
    for (var notification in notifications) {
      if (notification.id == notificationId) {
        notification.clicked = true;
        break;
      }
    }
    await saveNotifications(notifications);
  }

  Future<void> removeNotification(String notificationId) async {
    List<NotificationModel> notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == notificationId);
    await saveNotifications(notifications);
  }

  Future<void> removeExpiredNotifications() async {
    // Implemente a lógica para remover notificações expiradas, se necessário
  }
}
