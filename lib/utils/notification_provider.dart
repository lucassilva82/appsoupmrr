import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];

  List<NotificationModel> get notifications => _notifications;

  NotificationProvider() {
    // Carrega as notificações salvas assim que o Provider for instanciado
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    print('[DEBUG] NotificationProvider.loadNotifications INICIADO');
    await _service.removeExpiredNotifications();
    _notifications = (await _service.getNotifications()).reversed.toList();
    print(
        '[DEBUG] NotificationProvider.loadNotifications: notificações = ${_notifications.map((n) => n.toMap()).toList()}');
    notifyListeners();
  }

  Future<void> removeNotification(String notificationId) async {
    await _service.removeNotification(notificationId);
    await loadNotifications();
  }

  Future<void> addNotification(NotificationModel notification) async {
    print('[DEBUG] NotificationProvider.addNotification iniciando');

    try {
      await NotificationService().addNotification(notification);
      await loadNotifications(); // Recarrega a lista

      // NOTIFICA OS LISTENERS IMEDIATAMENTE
      notifyListeners();

      print('[DEBUG] NotificationProvider.addNotification FINALIZADO');
    } catch (e) {
      print('[DEBUG] NotificationProvider.addNotification ERRO: $e');
    }
  }

  Future<void> markAsClicked(String notificationId) async {
    print('[DEBUG] NotificationProvider.markAsClicked: id = $notificationId');
    await _service.markAsClicked(notificationId);
    await loadNotifications();
    print(
        '[DEBUG] NotificationProvider.markAsClicked: notificações atualizadas');
  }

  Future<int> countUnclicked() async {
    await loadNotifications();
    return _notifications.where((n) => !n.clicked).length;
  }
}
