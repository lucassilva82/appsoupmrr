import 'package:uuid/uuid.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool clicked;
  String? route; // <-- Adicionado campo route

  NotificationModel({
    String? id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.clicked = false,
    this.route,
  }) : id = id ?? const Uuid().v4();

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      timestamp: DateTime.parse(map['timestamp']),
      clicked: map['clicked'] == 'true',
      route: map['route'], // recupera o route se existir
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'clicked': clicked.toString(),
      'route': route, // salva o route
    };
  }
}
