import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../data/store.dart';

/// Serviço de notificações.
///
/// Fonte de verdade: Firestore em `militares/{matricula}/notificacoes`.
/// Mantém também um cache local (SharedPreferences) usado como fallback
/// quando não há matrícula/conexão (ex.: background handler).
class NotificationService {
  static const String _storageKey = 'notifications';

  CollectionReference<Map<String, dynamic>> _col(String matricula) =>
      FirebaseFirestore.instance
          .collection('militares')
          .doc(matricula)
          .collection('notificacoes');

  /// Coleção global de avisos (mensagens para todos).
  CollectionReference<Map<String, dynamic>> _avisosCol() =>
      FirebaseFirestore.instance.collection('avisos_gerais');

  /// Estado por usuário dos avisos globais (lido/removido).
  /// militares/{matricula}/avisos_status/{avisoId}
  CollectionReference<Map<String, dynamic>> _statusCol(String matricula) =>
      FirebaseFirestore.instance
          .collection('militares')
          .doc(matricula)
          .collection('avisos_status');

  // ───────────────────────── Firestore (fonte de verdade) ─────────────────────

  /// Stream em tempo real das notificações do militar (mais antigas primeiro,
  /// para compatibilidade com a ordenação da UI existente).
  Stream<List<NotificationModel>> watchNotifications(String matricula) {
    return _col(matricula)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  /// Leitura única (usada em refresh manual / contagens).
  Future<List<NotificationModel>> fetchNotifications(String matricula) async {
    final snap =
        await _col(matricula).orderBy('timestamp', descending: false).get();
    return snap.docs.map((d) => _fromDoc(d.id, d.data())).toList();
  }

  Future<void> markAsClicked(String matricula, String id) async {
    await _col(matricula).doc(id).update({'read': true});
  }

  Future<void> markAllAsClicked(String matricula) async {
    final snap = await _col(matricula).where('read', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> removeNotification(String matricula, String id) async {
    await _col(matricula).doc(id).delete();
  }

  /// Remove TODAS as notificações do militar (usado no "Limpar tudo").
  Future<void> clearAll(String matricula) async {
    final snap = await _col(matricula).get();
    if (snap.docs.isEmpty) return;
    // Firestore limita cada batch a 500 operações.
    for (var i = 0; i < snap.docs.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final fim = (i + 450) > snap.docs.length ? snap.docs.length : (i + 450);
      for (var j = i; j < fim; j++) {
        batch.delete(snap.docs[j].reference);
      }
      await batch.commit();
    }
  }

  // ───────────────────────── Avisos globais (todos) ───────────────────────────

  /// Stream dos avisos globais (mais antigos primeiro). O estado de lido/removido
  /// é aplicado pelo provider a partir de [watchAvisosStatus].
  Stream<List<NotificationModel>> watchAvisosGerais() {
    return _avisosCol().orderBy('timestamp', descending: false).snapshots().map(
        (snap) => snap.docs
            .map((d) => _fromDoc(d.id, d.data(), isGlobal: true))
            .toList(growable: false));
  }

  /// Estado por usuário dos avisos globais: { avisoId: {read, deleted} }.
  Stream<Map<String, Map<String, bool>>> watchAvisosStatus(String matricula) {
    return _statusCol(matricula).snapshots().map((snap) {
      final m = <String, Map<String, bool>>{};
      for (final d in snap.docs) {
        final data = d.data();
        m[d.id] = {
          'read': data['read'] == true,
          'deleted': data['deleted'] == true,
        };
      }
      return m;
    });
  }

  Future<List<NotificationModel>> fetchAvisosGerais() async {
    final snap =
        await _avisosCol().orderBy('timestamp', descending: false).get();
    return snap.docs
        .map((d) => _fromDoc(d.id, d.data(), isGlobal: true))
        .toList();
  }

  Future<Map<String, Map<String, bool>>> fetchAvisosStatus(
      String matricula) async {
    final snap = await _statusCol(matricula).get();
    final m = <String, Map<String, bool>>{};
    for (final d in snap.docs) {
      final data = d.data();
      m[d.id] = {
        'read': data['read'] == true,
        'deleted': data['deleted'] == true,
      };
    }
    return m;
  }

  /// Marca um aviso global como lido para este militar.
  Future<void> markAvisoGeralAsRead(String matricula, String avisoId) async {
    await _statusCol(matricula)
        .doc(avisoId)
        .set({'read': true}, SetOptions(merge: true));
  }

  /// Oculta (remove da lista deste militar) um aviso global.
  Future<void> hideAvisoGeral(String matricula, String avisoId) async {
    await _statusCol(matricula)
        .doc(avisoId)
        .set({'deleted': true, 'read': true}, SetOptions(merge: true));
  }

  /// Marca vários avisos globais como lidos (em lote).
  Future<void> markAvisosGeraisAsRead(
      String matricula, List<String> avisoIds) async {
    if (avisoIds.isEmpty) return;
    for (var i = 0; i < avisoIds.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final fim = (i + 450) > avisoIds.length ? avisoIds.length : (i + 450);
      for (var j = i; j < fim; j++) {
        batch.set(_statusCol(matricula).doc(avisoIds[j]), {'read': true},
            SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Oculta vários avisos globais (em lote) — usado no "Limpar tudo".
  Future<void> hideAvisosGerais(String matricula, List<String> avisoIds) async {
    if (avisoIds.isEmpty) return;
    for (var i = 0; i < avisoIds.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      final fim = (i + 450) > avisoIds.length ? avisoIds.length : (i + 450);
      for (var j = i; j < fim; j++) {
        batch.set(_statusCol(matricula).doc(avisoIds[j]),
            {'deleted': true, 'read': true}, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  NotificationModel _fromDoc(String docId, Map<String, dynamic> data,
      {bool isGlobal = false}) {
    final ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else if (ts is String) {
      timestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }
    return NotificationModel(
      id: docId,
      title: (data['title'] ?? data['titulo'] ?? '').toString(),
      body: (data['body'] ?? data['mensagem'] ?? '').toString(),
      timestamp: timestamp,
      clicked: data['read'] == true,
      route: (data['route'] ?? '').toString().isEmpty
          ? null
          : data['route'].toString(),
      isGlobal: isGlobal,
    );
  }

  // ───────────────────────── Cache local (fallback) ───────────────────────────

  Future<List<NotificationModel>> getLocalNotifications() async {
    final data = await Store.getString(_storageKey);
    if (data.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      final result = list.map((e) => NotificationModel.fromMap(e)).toList();
      result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> addLocalNotification(NotificationModel notification) async {
    final notifications = await getLocalNotifications();
    notifications.add(notification);
    await Store.saveString(
      _storageKey,
      jsonEncode(notifications.map((e) => e.toMap()).toList()),
    );
  }
}
