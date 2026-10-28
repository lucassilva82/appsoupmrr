import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/ambiente_app.dart';
import '../../core/erros/falha_app.dart';
import '../../core/rede/api_client.dart';
import '../../services/escala_service.dart' show CofreSenhaIntranet;

/// API móvel do SISCHAMADOS (intranet, `sischamados/docs/API_MOBILE.md`):
/// chave do aplicativo em todo pedido e token da pessoa, que sai do login com
/// a matrícula e a senha da intranet. O atendimento fica só na intranet; o
/// app abre e acompanha os chamados de quem pede (docs/SOUPM_2_2.md §8.3).
///
/// A chave vem do build (`--dart-define-from-file=env.json`,
/// `SISCHAMADOS_APP_CHAVE`), nunca do código: o repositório é público.
const urlSischamados = String.fromEnvironment('SISCHAMADOS_URL',
    defaultValue: 'https://intranet.pmrr.online/sischamados/api/v1');
const chaveSischamados = String.fromEnvironment('SISCHAMADOS_APP_CHAVE');

class CampoAssunto {
  const CampoAssunto({required this.chave, required this.rotulo, required this.tipo,
      this.obrigatorio = false, this.ajuda, this.exemplo, this.opcoes = const []});

  final String chave;
  final String rotulo;
  final String tipo; // text | textarea | select | date | number
  final bool obrigatorio;
  final String? ajuda;
  final String? exemplo;
  final List<String> opcoes;

  static CampoAssunto? deJson(Object? j) => j is Map && j['chave'] is String
      ? CampoAssunto(
          chave: j['chave'] as String,
          rotulo: '${j['rotulo'] ?? j['chave']}',
          tipo: '${j['tipo'] ?? 'text'}',
          obrigatorio: j['obrigatorio'] == true,
          ajuda: j['ajuda'] as String?,
          exemplo: j['exemplo'] as String?,
          opcoes: [for (final o in (j['opcoes'] is List ? j['opcoes'] as List : const [])) '$o'],
        )
      : null;
}

class Assunto {
  const Assunto({required this.id, required this.nome, this.descricao, this.requerAnexo = false,
      this.instrucaoAnexo, this.campos = const [], this.prioridade, this.prazoHoras});

  final int id;
  final String nome;
  final String? descricao;
  final bool requerAnexo;
  final String? instrucaoAnexo;
  final List<CampoAssunto> campos;
  final String? prioridade;
  final int? prazoHoras;
}

class GrupoAssuntos {
  const GrupoAssuntos({required this.id, required this.nome, this.descricao, required this.assuntos});
  final int id;
  final String nome;
  final String? descricao;
  final List<Assunto> assuntos;
}

class ResumoChamado {
  const ResumoChamado({required this.id, required this.protocolo, required this.titulo, required this.assunto,
      required this.situacao, this.prioridade, this.abertoEm, this.atualizadoEm});

  final int id;
  final String protocolo;
  final String titulo;
  final String assunto;
  final String situacao;
  final String? prioridade;
  final DateTime? abertoEm;
  final DateTime? atualizadoEm;

  /// Encerrado, cancelado ou resolvido: vai para a aba Encerrados.
  bool get encerrado => RegExp(r'encerr|cancel|resolvid|conclu|fechad', caseSensitive: false).hasMatch(situacao);

  /// O DTI pediu algo a quem abriu.
  bool get aguardandoVoce => RegExp(r'aguardando (o )?(solicitante|usu[aá]rio|voc[eê])', caseSensitive: false)
      .hasMatch(situacao);
}

class MensagemChamado {
  const MensagemChamado({required this.texto, required this.minha, this.quando});
  final String texto;
  final bool minha;
  final DateTime? quando;
}

class DetalheChamado {
  const DetalheChamado({required this.resumo, required this.descricao, required this.mensagens, this.dados = const {}});
  final ResumoChamado resumo;
  final String descricao;
  final List<MensagemChamado> mensagens;
  final Map<String, dynamic> dados;
}

/// Erro que a API devolveu com recado por campo (`DADOS_INVALIDOS`).
class FalhaCampos extends FalhaApp {
  FalhaCampos(FalhaApp f, this.detalhes)
      : super(codigo: f.codigo, origem: f.origem, titulo: f.titulo, texto: f.texto, acao: f.acao, detalhe: f.detalhe);
  final Map<String, String> detalhes;
}

/// Onde fica o token do SISCHAMADOS (Keychain/Keystore, por matrícula).
abstract class CofreToken {
  Future<String?> ler(String matricula);
  Future<void> gravar(String matricula, String token);
  Future<void> apagar(String matricula);
}

class CofreTokenSeguro implements CofreToken {
  const CofreTokenSeguro();
  static const _s = FlutterSecureStorage();
  String _k(String m) => 'sischamados_token_$m';
  @override
  Future<String?> ler(String matricula) => _s.read(key: _k(matricula));
  @override
  Future<void> gravar(String matricula, String token) => _s.write(key: _k(matricula), value: token);
  @override
  Future<void> apagar(String matricula) => _s.delete(key: _k(matricula));
}

class ChamadosApi {
  ChamadosApi({
    required this.api,
    required this.matricula,
    required this.senhaApp,
    CofreToken? cofre,
    Future<String?> Function()? senhaIntranetGuardada,
    String? base,
    String? chave,
  })  : _cofre = cofre ?? const CofreTokenSeguro(),
        _senhaIntranet = senhaIntranetGuardada ?? (() => _lerSenhaIntranet(matricula)),
        base = base ?? urlSischamados,
        chave = chave ?? chaveSischamados;

  final ApiClient api;
  final String matricula;
  final String senhaApp;
  final CofreToken _cofre;
  final Future<String?> Function() _senhaIntranet;
  final String base;
  final String chave;

  static const prefixo = 'CH';

  static Future<String?> _lerSenhaIntranet(String matricula) async {
    final s = await const CofreSenhaIntranet().ler();
    return s != null && s.matricula == matricula ? s.senha : null;
  }

  String? _token;

  /// Este build tem a chave do aplicativo? Sem ela, nada funciona.
  bool get configurado => chave.isNotEmpty;

  FalhaApp _falha(Object? corpo, int status) {
    final e = corpo is Map && corpo['erro'] is Map ? corpo['erro'] as Map : const {};
    final codigo = '${e['codigo'] ?? 'HTTP_$status'}';
    final f = FalhaApp.daApi(prefixo, codigo, e['mensagem'] as String?);
    final det = e['detalhes'];
    if (det is Map) {
      return FalhaCampos(f, {for (final d in det.entries) '${d.key}': d.value is List ? (d.value as List).join(' ') : '${d.value}'});
    }
    return f;
  }

  Future<dynamic> _pedir(String metodo, String rota,
      {Object? json, Map<String, String>? campos, List<({String caminho, String nome})> arquivos = const [],
      bool autenticado = true, bool tentouEntrar = false}) async {
    if (!configurado) {
      throw const FalhaApp(
          codigo: 'CH-CHAVE',
          origem: OrigemFalha.aparelho,
          titulo: 'Chamados indisponíveis nesta versão',
          texto: 'Esta versão do app não tem a ligação com o SISCHAMADOS. Atualize o app ou abra o chamado pela intranet.',
          acao: AcaoFalha.nenhuma);
    }
    if (autenticado) _token ??= await _cofre.ler(matricula) ?? await entrar();
    final r = await api.requisicao(metodo, Uri.parse('$base/$rota'),
        prefixo: prefixo,
        cabecalhos: {'X-App-Chave': chave, if (autenticado && _token != null) 'Authorization': 'Bearer $_token'},
        json: json,
        campos: campos,
        arquivos: arquivos,
        tempo: arquivos.isEmpty ? null : const Duration(seconds: 120));
    final corpo = r.corpo;
    if (corpo is Map && corpo['ok'] == true) return corpo['dados'];
    final codigo = corpo is Map && corpo['erro'] is Map ? '${(corpo['erro'] as Map)['codigo']}' : '';
    // O token vence enquanto a pessoa usa o app: entra de novo uma vez, sozinho.
    if (autenticado && codigo == 'SESSAO_EXPIRADA' && !tentouEntrar) {
      await _cofre.apagar(matricula);
      _token = await entrar();
      return _pedir(metodo, rota, json: json, campos: campos, arquivos: arquivos, tentouEntrar: true);
    }
    throw _falha(corpo, r.status);
  }

  /// Entra com a senha da intranet guardada (a mesma das Escalas) e, se não
  /// houver ou for recusada, com a do app. Senha que o militar digitar vem
  /// em [senhaDigitada].
  Future<String> entrar({String? senhaDigitada}) async {
    final guardada = await _senhaIntranet();
    final candidatas = [
      if (senhaDigitada != null && senhaDigitada.isNotEmpty) senhaDigitada
      else ...[if (guardada != null && guardada.isNotEmpty) guardada, if (senhaApp.isNotEmpty) senhaApp],
    ];
    FalhaApp? ultima;
    for (final senha in {...candidatas}) {
      final r = await api.requisicao('POST', Uri.parse('$base/sessao'),
          prefixo: prefixo,
          cabecalhos: {'X-App-Chave': chave},
          json: {'matricula': matricula, 'senha': senha, 'dispositivo': '${AmbienteApp.plataforma} · SouPMRR ${AmbienteApp.versao}'});
      final corpo = r.corpo;
      if (corpo is Map && corpo['ok'] == true && corpo['dados'] is Map && (corpo['dados'] as Map)['token'] is String) {
        final token = (corpo['dados'] as Map)['token'] as String;
        await _cofre.gravar(matricula, token);
        if (senhaDigitada != null) await const CofreSenhaIntranet().gravar(matricula, senhaDigitada);
        return _token = token;
      }
      ultima = _falha(corpo, r.status);
      if (!ultima.codigo.endsWith('CREDENCIAL-INVALIDA')) throw ultima;
    }
    throw FalhaApp(
        codigo: 'CH-SENHA',
        origem: OrigemFalha.conta,
        titulo: 'Informe a senha da intranet',
        texto: 'O SISCHAMADOS usa a senha da intranet, e ela não é a mesma do app. Digite-a uma vez: o app guarda no aparelho com segurança.',
        acao: AcaoFalha.nenhuma,
        detalhe: ultima?.detalhe);
  }

  Future<List<GrupoAssuntos>> catalogo() async {
    final d = await _pedir('GET', 'catalogo');
    return [
      for (final g in (d is Map && d['grupos'] is List ? d['grupos'] as List : const []))
        if (g is Map)
          GrupoAssuntos(
            id: (g['id'] as num?)?.toInt() ?? 0,
            nome: '${g['nome'] ?? ''}',
            descricao: g['descricao'] as String?,
            assuntos: [
              for (final a in (g['assuntos'] is List ? g['assuntos'] as List : const []))
                if (a is Map && a['id'] is num)
                  Assunto(
                    id: (a['id'] as num).toInt(),
                    nome: '${a['nome'] ?? ''}',
                    descricao: a['descricao'] as String?,
                    requerAnexo: a['requer_anexo'] == true,
                    instrucaoAnexo: a['instrucao_anexo'] as String?,
                    campos: [for (final c in (a['campos'] is List ? a['campos'] as List : const [])) if (CampoAssunto.deJson(c) case final campo?) campo],
                    prioridade: a['prioridade'] as String?,
                    prazoHoras: (a['prazo_resposta_horas'] as num?)?.toInt(),
                  ),
            ],
          ),
    ];
  }

  static ResumoChamado _resumo(Map c) => ResumoChamado(
        id: (c['id'] as num).toInt(),
        protocolo: '${c['protocolo'] ?? ''}',
        titulo: '${c['titulo'] ?? ''}',
        assunto: '${c['assunto'] ?? ''}',
        situacao: '${c['situacao'] ?? ''}',
        prioridade: c['prioridade'] as String?,
        abertoEm: DateTime.tryParse('${c['aberto_em'] ?? c['criado_em'] ?? ''}'),
        atualizadoEm: DateTime.tryParse('${c['atualizado_em'] ?? ''}'),
      );

  /// Os chamados de quem está logado (todas as páginas, até 5).
  Future<List<ResumoChamado>> meus() async {
    final lista = <ResumoChamado>[];
    for (var pagina = 1; pagina <= 5; pagina++) {
      final d = await _pedir('GET', 'chamados?pagina=$pagina');
      if (d is! Map) break;
      for (final c in (d['chamados'] is List ? d['chamados'] as List : const [])) {
        if (c is Map && c['id'] is num) lista.add(_resumo(c));
      }
      if (pagina >= ((d['paginas'] as num?)?.toInt() ?? 1)) break;
    }
    return lista;
  }

  Future<DetalheChamado> ver(int id) async {
    final d = await _pedir('GET', 'chamados/$id');
    final c = (d as Map)['chamado'] as Map;
    return DetalheChamado(
      resumo: _resumo(c),
      descricao: '${c['descricao'] ?? ''}',
      dados: c['dados_adicionais'] is Map ? Map<String, dynamic>.from(c['dados_adicionais'] as Map) : const {},
      mensagens: [
        for (final m in (d['mensagens'] is List ? d['mensagens'] as List : const []))
          if (m is Map)
            MensagemChamado(texto: '${m['texto'] ?? ''}', minha: m['meu'] == true, quando: DateTime.tryParse('${m['quando'] ?? ''}')),
      ],
    );
  }

  /// Abre o chamado; devolve o protocolo. Sem anexo vai em JSON; com anexo,
  /// multipart (`anexos[]`). Não repete sozinho em falha de rede: pode abrir
  /// dois chamados (API_MOBILE.md, "Cuidados").
  Future<({int id, String protocolo, String situacao})> abrir({
    required int assuntoId,
    required String titulo,
    required String descricao,
    Map<String, String> campos = const {},
    List<({String caminho, String nome})> anexos = const [],
  }) async {
    final d = anexos.isEmpty
        ? await _pedir('POST', 'chamados',
            json: {'assunto_id': assuntoId, 'titulo': titulo, 'descricao': descricao, 'campos': campos})
        : await _pedir('POST', 'chamados', campos: {
            'assunto_id': '$assuntoId',
            'titulo': titulo,
            'descricao': descricao,
            for (final c in campos.entries) 'campos[${c.key}]': c.value,
          }, arquivos: anexos);
    final m = d as Map;
    return (id: (m['id'] as num).toInt(), protocolo: '${m['protocolo']}', situacao: '${m['situacao'] ?? 'Aberto'}');
  }

  Future<void> sair() async {
    try {
      if (await _cofre.ler(matricula) != null) await _pedir('DELETE', 'sessao');
    } catch (_) {/* sair não pode travar o logout */}
    await _cofre.apagar(matricula);
    _token = null;
  }
}
