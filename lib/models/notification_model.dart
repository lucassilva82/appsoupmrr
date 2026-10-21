import 'package:uuid/uuid.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool clicked;
  String? route; // <-- Adicionado campo route
  final bool isGlobal; // true = aviso da coleção global "avisos_gerais"
  // Campos dos avisos do SIGE, gravados pela Cloud Function (notificarEscala).
  final String? tipoEvento;
  final String? referenciaId;
  final String? notificacaoId;

  NotificationModel({
    String? id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.clicked = false,
    this.route,
    this.isGlobal = false,
    this.tipoEvento,
    this.referenciaId,
    this.notificacaoId,
  }) : id = id ?? const Uuid().v4();

  /// Dados para abrir a tela do aviso do SIGE, no mesmo formato do `data` do
  /// push. Nulo quando não é aviso do SIGE.
  Map<String, dynamic>? get dadosAviso {
    if ((tipoEvento ?? '').isEmpty && (notificacaoId ?? '').isEmpty) {
      return null;
    }
    return {
      'titulo': title,
      'mensagem': body,
      'recebido_em': timestamp.toIso8601String(),
      if (tipoEvento != null) 'tipo_evento': tipoEvento,
      if (referenciaId != null) 'referencia_id': referenciaId,
      if (notificacaoId != null) 'notificacao_id': notificacaoId,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      timestamp: DateTime.parse(map['timestamp']),
      clicked: map['clicked'] == 'true',
      route: map['route'], // recupera o route se existir
      isGlobal: map['isGlobal'] == 'true' || map['isGlobal'] == true,
      tipoEvento: map['tipo_evento']?.toString(),
      referenciaId: map['referencia_id']?.toString(),
      notificacaoId: map['notificacao_id']?.toString(),
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
      if (tipoEvento != null) 'tipo_evento': tipoEvento,
      if (referenciaId != null) 'referencia_id': referenciaId,
      if (notificacaoId != null) 'notificacao_id': notificacaoId,
    };
  }
}
