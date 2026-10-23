import 'dart:convert';

import '../../core/ambiente_app.dart';
import '../../core/enderecos.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';

/// Tipos aceitos pela API (só ideias e elogios; problema vai por chamado).
enum TipoFeedback {
  melhoria('melhoria', 'Sugerir melhoria'),
  funcaoNova('funcao_nova', 'Pedir função nova'),
  elogio('elogio', 'Elogio');

  const TipoFeedback(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static TipoFeedback? de(String? api) {
    for (final t in values) {
      if (t.api == api) return t;
    }
    return null;
  }
}

class ResumoFeedback {
  const ResumoFeedback({
    required this.id,
    required this.protocolo,
    required this.tipo,
    required this.trecho,
    required this.situacao,
    required this.criadoEm,
    required this.respostasNovas,
  });

  final int id;
  final String protocolo;
  final TipoFeedback? tipo;
  final String trecho;
  final String situacao;
  final DateTime? criadoEm;
  final int respostasNovas;
}

class MensagemFeedback {
  const MensagemFeedback({required this.daEquipe, required this.texto, this.criadoEm, this.anexos = 0});

  final bool daEquipe;
  final String texto;
  final DateTime? criadoEm;
  final int anexos;
}

class DetalheFeedback {
  const DetalheFeedback({required this.resumo, required this.texto, required this.aguardaMilitar,
      required this.anexos, required this.mensagens});

  final ResumoFeedback resumo;
  final String texto;
  final bool aguardaMilitar;
  final int anexos;
  final List<MensagemFeedback> mensagens;

  bool get encerrado => resumo.situacao == 'concluido' || resumo.situacao == 'arquivado';
}

/// Nome da situação para o militar (§8.2).
String nomeSituacao(String s) => switch (s) {
      'recebido' => 'Recebido',
      'em_analise' => 'Em análise',
      'planejado' => 'Planejado',
      'concluido' => 'Concluído',
      'arquivado' => 'Arquivado',
      _ => s,
    };

/// Fala com `sigrh/feedback.php`. Toda falha sai como [FalhaApp] com o
/// prefixo FB (FB-REDE, FB-ANEXO-GRANDE...).
class FeedbackRepositorio {
  FeedbackRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/feedback.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'FB';

  Future<Map<String, dynamic>> _pedir(Map<String, String> campos,
      {List<({String caminho, String nome})> anexos = const []}) async {
    final j = await api.postMultipart(url,
        prefixo: prefixo,
        campos: {'matricula': matricula, 'senha': senhaMd5, ...campos},
        arquivos: anexos);
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'feedback.php não devolveu objeto');
    if (j['code'] != 1) {
      throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    }
    return Map<String, dynamic>.from(j);
  }

  /// Devolve o protocolo (FB-2026-00042).
  Future<String> enviar({
    required TipoFeedback tipo,
    required String texto,
    List<({String caminho, String nome})> anexos = const [],
    Map<String, String>? contexto,
  }) async {
    final j = await _pedir({
      'acao': 'enviar',
      'tipo': tipo.api,
      'texto': texto,
      'plataforma': AmbienteApp.plataforma,
      'app_versao': AmbienteApp.versao,
      if (contexto != null) 'contexto': jsonEncode(contexto),
    }, anexos: anexos);
    return '${j['protocolo']}';
  }

  Future<List<ResumoFeedback>> listar() async {
    final j = await _pedir({'acao': 'listar'});
    return [
      for (final i in (j['itens'] as List? ?? const []))
        if (i is Map) _resumo(i),
    ];
  }

  Future<DetalheFeedback> ver(int id) async {
    final j = await _pedir({'acao': 'ver', 'id': '$id'});
    final f = j['feedback'] as Map;
    return DetalheFeedback(
      resumo: _resumo({...f, 'trecho': f['texto']}),
      texto: '${f['texto']}',
      aguardaMilitar: f['aguarda_militar'] == true,
      anexos: (f['anexos'] as num?)?.toInt() ?? 0,
      mensagens: [
        for (final m in (j['mensagens'] as List? ?? const []))
          if (m is Map)
            MensagemFeedback(
              daEquipe: m['autor'] == 'equipe',
              texto: '${m['texto']}',
              criadoEm: DateTime.tryParse('${m['criado_em']}'),
              anexos: (m['anexos'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  Future<void> responder(int id, String texto,
          {List<({String caminho, String nome})> anexos = const []}) =>
      _pedir({'acao': 'responder', 'id': '$id', 'texto': texto}, anexos: anexos);

  static ResumoFeedback _resumo(Map i) => ResumoFeedback(
        id: (i['id'] as num).toInt(),
        protocolo: '${i['protocolo']}',
        tipo: TipoFeedback.de(i['tipo'] as String?),
        trecho: '${i['trecho'] ?? ''}',
        situacao: '${i['situacao'] ?? 'recebido'}',
        criadoEm: DateTime.tryParse('${i['criado_em']}'),
        respostasNovas: (i['respostas_novas'] as num?)?.toInt() ?? 0,
      );
}
