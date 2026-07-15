import 'package:uuid/uuid.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool clicked;
  String? route; // <-- Adicionado campo route
  final bool isGlobal; // true = aviso da coleção global "avisos_gerais"

  NotificationModel({
    String? id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.clicked = false,
    this.route,
    this.isGlobal = false,
  }) : id = id ?? const Uuid().v4();

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      timestamp: DateTime.parse(map['timestamp']),
      clicked: map['clicked'] == 'true',
      route: map['route'], // recupera o route se existir
      isGlobal: map['isGlobal'] == 'true' || map['isGlobal'] == true,
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
      'isGlobal': isGlobal.toString(),
    };
  }
}
