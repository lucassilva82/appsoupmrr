import '../../core/ambiente_app.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/iniciar_log.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/notification_model.dart';

/// A aba Avisos pelo Postgres (`sigrh/notificacoes.php`, docs/SOUPM_2_2.md
/// §13), no lugar das coleções do Firestore. Toda falha sai como `FalhaApp`
/// `AV-<erro>`.
class AvisosApi {
  AvisosApi({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/notificacoes.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'AV';

  Future<Map> _pedir(Map<String, String> campos) async {
    final j = await api.postJson(url, prefixo: prefixo,
        campos: {'matricula': matricula, 'senha': senhaMd5, ...campos});
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'notificacoes.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    return j;
  }

  /// Mais antigas primeiro, como a lista do Firestore (a tela inverte).
  Future<List<NotificationModel>> listar() async {
    final j = await _pedir({'acao': 'listar'});
    final itens = [
      for (final i in (j['itens'] as List? ?? const []))
        if (i is Map && i['id'] is num) modelo(i),
    ];
    return itens.reversed.toList();
  }

  static NotificationModel modelo(Map i) {
    final dados = i['dados'] is Map ? i['dados'] as Map : const {};
    return NotificationModel(
      id: '${i['id']}',
      title: '${i['titulo'] ?? ''}',
      body: '${i['mensagem'] ?? ''}',
      timestamp: DateTime.tryParse('${i['criado_em']}')?.toLocal() ?? DateTime.now(),
      clicked: i['lida'] == true,
      route: (i['rota'] as String?)?.isEmpty ?? true ? null : i['rota'] as String,
      isGlobal: i['geral'] == true,
      tipoEvento: i['tipo_evento'] as String?,
      referenciaId: dados['referencia_id']?.toString(),
      notificacaoId: dados['notificacao_id']?.toString(),
    );
  }

  Future<void> marcarLida(String id) => _pedir({'acao': 'lida', 'id': id});
  Future<void> marcarTodas() => _pedir({'acao': 'todas_lidas'});
  Future<void> excluir(String id) => _pedir({'acao': 'excluir', 'id': id});
  Future<void> limpar() => _pedir({'acao': 'limpar'});
}

/// O aparelho para o push (`sigrh/dispositivo.php`), no lugar de
/// militares/{m}.fcmToken. Roda em segundo plano: falha só vai para o log.
class DispositivoApi {
  DispositivoApi({ApiClient? api, Uri? url})
      : api = api ?? ApiClient(),
        url = url ?? Uri.parse('$urlSigrh/dispositivo.php');

  final ApiClient api;
  final Uri url;

  Future<void> registrar({required String token, required String matricula, required String senhaMd5}) async {
    try {
      final j = await api.postJson(url, prefixo: 'AV', campos: {
        'acao': 'registrar',
        'token': token,
        'aparelho_id': await aparelhoIdApp(),
        'matricula': matricula,
        'senha': senhaMd5,
        'plataforma': AmbienteApp.plataforma,
        'app_versao': AmbienteApp.versao,
      });
      if (j is Map && j['code'] != 1) {
        throw FalhaApp.daApi('AV', '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
      }
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'dispositivo', mostrado: false);
    }
  }

  /// Sair da conta: o token fica sem matrícula e o push daquela conta para.
  Future<void> remover(String token) async {
    try {
      await api.postJson(url, prefixo: 'AV',
          campos: {'acao': 'remover', 'token': token, 'aparelho_id': await aparelhoIdApp()});
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'dispositivo', mostrado: false);
    }
  }
}
