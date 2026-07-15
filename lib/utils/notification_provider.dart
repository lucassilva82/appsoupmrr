import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/store.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];

  // Fontes separadas: individual (por militar) + global (avisos para todos).
  List<NotificationModel> _individuais = [];
  List<NotificationModel> _avisosRaw = [];
  Map<String, Map<String, bool>> _avisosStatus = {};

  StreamSubscription<List<NotificationModel>>? _subIndividual;
  StreamSubscription<List<NotificationModel>>? _subAvisos;
  StreamSubscription<Map<String, Map<String, bool>>>? _subStatus;
  String? _matricula;

  /// Chamado quando uma notificação NOVA chega via stream do Firestore com o
  /// app aberto. Usado para exibir o banner local em foreground (funciona
  /// inclusive no simulador iOS, onde o push remoto do FCM não é entregue).
  void Function(NotificationModel notif)? onNewNotificationForeground;

  // Controle para diferenciar a carga inicial das notificações novas.
  bool _baselineReady = false;
  bool _loadedIndividual = false;
  bool _loadedAvisos = false;
  bool _loadedStatus = false;
  final Set<String> _idsConhecidos = {};

  bool get _allLoaded => _loadedIndividual && _loadedAvisos && _loadedStatus;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.clicked).length;

  NotificationProvider() {
    // Tenta conectar imediatamente caso o usuário já esteja logado.
    bindUser();
  }

  /// Chave única por item (evita colisão entre individual e global).
  static String keyDe(NotificationModel n) =>
      '${n.isGlobal ? 'g' : 'i'}:${n.id}';

  /// Conecta o provider às duas fontes de notificações no Firestore.
  /// Se [matricula] for nula, lê de `userData` no Store.
  Future<void> bindUser([String? matricula]) async {
    matricula ??= (await Store.getMap('userData'))['matricula']?.toString();
    if (matricula == null || matricula.isEmpty) return;
    if (matricula == _matricula && _subIndividual != null)
      return; // já conectado

    _matricula = matricula;
    await _subIndividual?.cancel();
    await _subAvisos?.cancel();
    await _subStatus?.cancel();
    _baselineReady = false;
    _loadedIndividual = false;
    _loadedAvisos = false;
    _loadedStatus = false;
    _idsConhecidos.clear();
    _individuais = [];
    _avisosRaw = [];
    _avisosStatus = {};

    _subIndividual = _service.watchNotifications(matricula).listen(
      (list) {
        _individuais = list;
        _loadedIndividual = true;
        _recompute();
      },
      onError: (e) => debugPrint('[NOTIF] Erro no stream individual: $e'),
    );

    _subAvisos = _service.watchAvisosGerais().listen(
      (list) {
        _avisosRaw = list;
        _loadedAvisos = true;
        _recompute();
      },
      onError: (e) =>
          debugPrint('[NOTIF] Erro no stream de avisos globais: $e'),
    );

    _subStatus = _service.watchAvisosStatus(matricula).listen(
      (map) {
        _avisosStatus = map;
        _loadedStatus = true;
        _recompute();
      },
      onError: (e) => debugPrint('[NOTIF] Erro no stream de status: $e'),
    );
  }

  /// Mescla individual + global (aplicando lido/removido por usuário), ordena
  /// e dispara o banner de foreground para itens realmente novos.
  void _recompute() {
    final merged = <NotificationModel>[];
    merged.addAll(_individuais);

    for (final aviso in _avisosRaw) {
      final st = _avisosStatus[aviso.id];
      if (st != null && st['deleted'] == true)
        continue; // removido por este user
      merged.add(NotificationModel(
        id: aviso.id,
        title: aviso.title,
        body: aviso.body,
        timestamp: aviso.timestamp,
        route: aviso.route,
        clicked: st != null && st['read'] == true,
        isGlobal: true,
      ));
    }

    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Só detecta novidades (banner) depois que as três fontes carregaram uma
    // vez — evita banners falsos no arranque quando cada stream emite.
    if (_baselineReady) {
      for (final n in merged) {
        final k = keyDe(n);
        if (!_idsConhecidos.contains(k) && !n.clicked) {
          onNewNotificationForeground?.call(n);
        }
      }
    }
    _idsConhecidos
      ..clear()
      ..addAll(merged.map(keyDe));
    if (_allLoaded) _baselineReady = true;

    _notifications = merged;
    notifyListeners();
  }

  /// Desconecta (ex.: logout).
  Future<void> unbind() async {
    await _subIndividual?.cancel();
    await _subAvisos?.cancel();
    await _subStatus?.cancel();
    _subIndividual = null;
    _subAvisos = null;
    _subStatus = null;
    _matricula = null;
    _notifications = [];
    _individuais = [];
    _avisosRaw = [];
    _avisosStatus = {};
    _baselineReady = false;
    _loadedIndividual = false;
    _loadedAvisos = false;
    _loadedStatus = false;
    _idsConhecidos.clear();
    notifyListeners();
  }

  /// Recarrega manualmente (pull-to-refresh). Garante conexão aos streams e
  /// faz uma releitura única das duas fontes.
  Future<void> loadNotifications() async {
    await bindUser();
    if (_matricula == null) return;
    try {
      final results = await Future.wait([
        _service.fetchNotifications(_matricula!),
        _service.fetchAvisosGerais(),
        _service.fetchAvisosStatus(_matricula!),
      ]);
      _individuais = results[0] as List<NotificationModel>;
      _avisosRaw = results[1] as List<NotificationModel>;
      _avisosStatus = results[2] as Map<String, Map<String, bool>>;
      _recompute();
    } catch (e) {
      debugPrint('[NOTIF] Erro ao recarregar: $e');
    }
  }

  /// Remove um item da lista deste militar. Individual = apaga o documento;
  /// global = apenas oculta para este usuário (não afeta os demais).
  Future<void> removeNotification(NotificationModel n) async {
    if (_matricula == null) return;
    if (n.isGlobal) {
      await _service.hideAvisoGeral(_matricula!, n.id);
    } else {
      await _service.removeNotification(_matricula!, n.id);
    }
  }

  /// "Limpar tudo": apaga as individuais e oculta todos os avisos globais
  /// atualmente visíveis para este militar.
  Future<void> clearAll() async {
    if (_matricula == null) return;
    final idsGlobais = _notifications
        .where((n) => n.isGlobal)
        .map((n) => n.id)
        .toList(growable: false);
    await _service.clearAll(_matricula!);
    await _service.hideAvisosGerais(_matricula!, idsGlobais);
  }

  Future<void> markAsClicked(NotificationModel n) async {
    if (_matricula == null) return;
    if (n.isGlobal) {
      await _service.markAvisoGeralAsRead(_matricula!, n.id);
    } else {
      await _service.markAsClicked(_matricula!, n.id);
    }
  }

  Future<int> countUnclicked() async {
    return _notifications.where((n) => !n.clicked).length;
  }

  Future<void> markAllAsRead() async {
    if (_matricula == null) return;
    final idsGlobais = _notifications
        .where((n) => n.isGlobal && !n.clicked)
        .map((n) => n.id)
        .toList(growable: false);
    await _service.markAllAsClicked(_matricula!);
    await _service.markAvisosGeraisAsRead(_matricula!, idsGlobais);
  }

  @override
  void dispose() {
    _subIndividual?.cancel();
    _subAvisos?.cancel();
    _subStatus?.cancel();
    super.dispose();
  }
}
