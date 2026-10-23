import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ambiente_app.dart';
import '../enderecos.dart';
import '../erros/falha_app.dart';
import '../log/registro_log.dart';
import '../rede/api_client.dart';
import '../../features/ajuda/ajuda_modelo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// O que o app desenha vem da API (docs/SOUPM_2_2.md §5, PAINEL_ADMIN §9).
//
// [RepositorioConfig.carregar] lê `app_config.php` e devolve sempre um
// [AppConfig]: o da rede, o último guardado (quando a rede falha ou o
// servidor responde "não mudou") ou os padrões do código, nessa ordem. A
// falha nunca impede o app de abrir; ela vai para o log com o código CF-.
// ─────────────────────────────────────────────────────────────────────────────

/// De onde veio a configuração em uso.
enum OrigemConfig { rede, cache, padrao }

class MensagemBloqueio {
  const MensagemBloqueio({
    required this.motivo,
    required this.titulo,
    required this.texto,
    required this.codigo,
    this.previsao,
    this.acao,
    this.acaoDestino,
  });

  final String motivo;
  final String titulo;
  final String texto;

  /// `MD-<CHAVE>-<MOTIVO>`, gerado pela API (§3.2).
  final String codigo;
  final DateTime? previsao;
  final String? acao;
  final String? acaoDestino;

  static MensagemBloqueio? deJson(Object? j) {
    if (j is! Map) return null;
    return MensagemBloqueio(
      motivo: '${j['motivo'] ?? 'indisponivel'}',
      titulo: '${j['titulo'] ?? 'Função indisponível'}',
      texto:
          '${j['texto'] ?? 'Esta função está temporariamente indisponível.'}',
      codigo: '${j['codigo'] ?? 'MD-DESCONHECIDO'}',
      previsao: DateTime.tryParse('${j['previsao'] ?? ''}'),
      acao: j['acao'] as String?,
      acaoDestino: j['acao_destino'] as String?,
    );
  }
}

/// Um nó da árvore de funções (área, função ou ação), já filtrado pelo
/// servidor para este militar.
class ItemMenu {
  const ItemMenu({
    required this.chave,
    required this.tipo,
    required this.rotulo,
    this.descricao,
    this.icone,
    this.rota,
    this.arte,
    this.visivel = true,
    this.bloqueado = false,
    this.selo,
    this.mensagem,
    this.sinonimos = const [],
    this.apelidos = const [],
    this.filhos = const [],
  });

  final String chave;
  final String tipo;
  final String rotulo;
  final String? descricao;
  final String? icone;
  final String? rota;
  final String? arte;

  /// Aparece no menu e na busca (§3.0). Fora do menu continua abrindo por
  /// card, push e link.
  final bool visivel;
  final bool bloqueado;
  final String? selo;
  final MensagemBloqueio? mensagem;
  final List<String> sinonimos;
  final List<String> apelidos;
  final List<ItemMenu> filhos;

  static List<String> _textos(Object? j) =>
      j is List ? j.map((e) => '$e').toList() : const [];

  /// Nó com campo essencial faltando é ignorado (versão nova do painel não
  /// pode derrubar versão velha do app, §2 princípio 4).
  static ItemMenu? deJson(Object? j) {
    if (j is! Map || j['chave'] is! String || j['rotulo'] is! String) {
      return null;
    }
    return ItemMenu(
      chave: j['chave'] as String,
      tipo: '${j['tipo'] ?? 'funcao'}',
      rotulo: j['rotulo'] as String,
      descricao: j['descricao'] as String?,
      icone: j['icone'] as String?,
      rota: j['rota'] as String?,
      arte: j['arte'] as String?,
      visivel: j['visivel'] != false,
      bloqueado: j['estado'] == 'bloqueado',
      selo: j['selo'] as String?,
      mensagem: MensagemBloqueio.deJson(j['mensagem']),
      sinonimos: _textos(j['sinonimos']),
      apelidos: _textos(j['apelidos']),
      filhos: lista(j['filhos']),
    );
  }

  /// Cópia com outros filhos (a tela tira os que não são visíveis).
  ItemMenu comFilhos(List<ItemMenu> novos) => ItemMenu(
        chave: chave,
        tipo: tipo,
        rotulo: rotulo,
        descricao: descricao,
        icone: icone,
        rota: rota,
        arte: arte,
        visivel: visivel,
        bloqueado: bloqueado,
        selo: selo,
        mensagem: mensagem,
        sinonimos: sinonimos,
        apelidos: apelidos,
        filhos: novos,
      );

  static List<ItemMenu> lista(Object? j) => j is List
      ? j.map(deJson).whereType<ItemMenu>().toList()
      : const <ItemMenu>[];
}

class RegraVersao {
  const RegraVersao(
      {required this.minima,
      required this.recomendada,
      this.titulo,
      this.texto});

  final String minima;
  final String recomendada;
  final String? titulo;
  final String? texto;

  static RegraVersao? deJson(Object? j) {
    if (j is! Map || j['minima'] is! String) return null;
    return RegraVersao(
      minima: j['minima'] as String,
      recomendada: '${j['recomendada'] ?? j['minima']}',
      titulo: j['titulo'] as String?,
      texto: j['texto'] as String?,
    );
  }
}

/// Situação da versão instalada diante da regra da plataforma (§10.2).
enum SituacaoVersao { emDia, recomendada, obrigatoria }

/// "2.10.1" > "2.9.0": compara número a número.
int compararVersoes(String a, String b) {
  List<int> partes(String v) => v
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0)
      .toList();
  final x = partes(a), y = partes(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Um bloco da Início como o painel deixou (docs/SOUPM_2_2.md §4).
class BlocoInicio {
  const BlocoInicio({
    required this.chave,
    this.ordem = 0,
    this.escondivel = true,
    this.arte,
    this.arteEstilo,
    this.dados = const [],
  });

  final String chave;
  final int ordem;
  final bool escondivel;
  final String? arte;
  final String? arteEstilo;

  /// Só `home.atalhos` usa: as chaves dos atalhos padrão do militar.
  final List<String> dados;

  static List<BlocoInicio> lista(Object? j) => [
        if (j is List)
          for (final b in j)
            if (b is Map && b['chave'] is String)
              BlocoInicio(
                chave: b['chave'] as String,
                ordem: (b['ordem'] as num?)?.toInt() ?? 0,
                escondivel: b['escondivel'] != false,
                arte: b['arte'] as String?,
                arteEstilo: b['arte_estilo'] as String?,
                dados: b['dados'] is List
                    ? [for (final d in b['dados'] as List) '$d']
                    : const [],
              ),
      ];
}

class AppConfig {
  const AppConfig({
    required this.origem,
    this.versaoConfig = 0,
    this.sessao = 'publica',
    this.versoes = const {},
    this.tempoLimiteRede = const Duration(seconds: 15),
    this.menu = const [],
    this.home,
    this.maisUsados,
    this.ajuda,
    this.recebidoEm,
  });

  /// Sem rede e sem nada guardado: o app segue como hoje.
  static const padrao = AppConfig(origem: OrigemConfig.padrao);

  final OrigemConfig origem;
  final int versaoConfig;

  /// `publica`, `ok` ou `invalida` (senha guardada não confere mais).
  final String sessao;
  final Map<String, RegraVersao> versoes;
  final Duration tempoLimiteRede;

  /// Vazio enquanto não houver sessão: o app usa o menu do código.
  final List<ItemMenu> menu;

  /// Blocos da Início na ordem do painel; nulo = o app usa a ordem dele
  /// (versão da API sem a fase 2, ou sem sessão).
  final List<BlocoInicio>? home;

  /// "Mais usados" de Serviços; nulo = a linha não aparece.
  final List<String>? maisUsados;

  /// "Preciso de ajuda"; nulo = o app usa o [ajudaPadrao].
  final List<AjudaAssunto>? ajuda;

  /// Quando a cópia em uso chegou do servidor ("Atualizado hoje às 07:30").
  final DateTime? recebidoEm;

  static AppConfig deJson(Map<String, dynamic> j,
      {required OrigemConfig origem, DateTime? recebidoEm}) {
    final versoes = <String, RegraVersao>{};
    final v = j['versao'];
    if (v is Map) {
      for (final e in v.entries) {
        final r = RegraVersao.deJson(e.value);
        if (r != null) versoes['${e.key}'] = r;
      }
    }
    final timeout = (j['rede'] is Map) ? j['rede']['timeout_s'] : null;
    return AppConfig(
      origem: origem,
      versaoConfig: (j['versao_config'] as num?)?.toInt() ?? 0,
      sessao: '${j['sessao'] ?? 'publica'}',
      versoes: versoes,
      tempoLimiteRede: timeout is num && timeout >= 3 && timeout <= 60
          ? Duration(seconds: timeout.toInt())
          : const Duration(seconds: 15),
      menu: ItemMenu.lista(j['menu']),
      home: j['home'] is List ? BlocoInicio.lista(j['home']) : null,
      maisUsados: j['servicos'] is Map && j['servicos']['mais_usados'] is List
          ? [for (final c in j['servicos']['mais_usados'] as List) '$c']
          : null,
      ajuda: AjudaAssunto.lista(j['ajuda']),
      recebidoEm: recebidoEm,
    );
  }

  SituacaoVersao situacaoVersao(String plataforma, String instalada) {
    final r = versoes[plataforma];
    if (r == null) return SituacaoVersao.emDia;
    if (compararVersoes(instalada, r.minima) < 0) {
      return SituacaoVersao.obrigatoria;
    }
    if (compararVersoes(instalada, r.recomendada) < 0) {
      return SituacaoVersao.recomendada;
    }
    return SituacaoVersao.emDia;
  }

  /// Acha a função pela chave nova ou pela antiga (apelido), em qualquer
  /// nível da árvore.
  ItemMenu? item(String chave) {
    ItemMenu? busca(List<ItemMenu> itens) {
      for (final i in itens) {
        if (i.chave == chave || i.apelidos.contains(chave)) return i;
        final f = busca(i.filhos);
        if (f != null) return f;
      }
      return null;
    }

    return busca(menu);
  }

  /// O bloco da Início pela chave; nulo se o painel o desligou. Sem `home`
  /// do servidor, todo bloco vale (padrão do app).
  bool blocoLigado(String chave) =>
      home == null || home!.any((b) => b.chave == chave);

  BlocoInicio? bloco(String chave) {
    for (final b in home ?? const <BlocoInicio>[]) {
      if (b.chave == chave) return b;
    }
    return null;
  }
}

/// Onde a última resposta fica guardada entre uma abertura e outra.
/// [quem] é a matrícula do pedido (vazio = pedido público): a cópia de um
/// militar nunca vale para outro no mesmo aparelho.
abstract class ArmazemConfig {
  Future<({String json, String? etag, DateTime? em, String quem})?> ler();
  Future<void> gravar(String json, String? etag, DateTime em, String quem);
}

class ArmazemConfigPreferencias implements ArmazemConfig {
  static const _chave = 'soupm_app_config';

  @override
  Future<({String json, String? etag, DateTime? em, String quem})?>
      ler() async {
    final p = await SharedPreferences.getInstance();
    final bruto = p.getString(_chave);
    if (bruto == null) return null;
    try {
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      return (
        json: m['json'] as String,
        etag: m['etag'] as String?,
        em: DateTime.tryParse('${m['em']}'),
        quem: '${m['quem'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> gravar(
      String json, String? etag, DateTime em, String quem) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _chave,
        jsonEncode({
          'json': json,
          'etag': etag,
          'em': em.toIso8601String(),
          'quem': quem
        }));
  }
}

class RepositorioConfig {
  RepositorioConfig({
    required ApiClient api,
    required Uri url,
    required String plataforma,
    required String versaoApp,
    ArmazemConfig? armazem,
  })  : _api = api,
        _url = url,
        _plataforma = plataforma,
        _versaoApp = versaoApp,
        _armazem = armazem ?? ArmazemConfigPreferencias();

  final ApiClient _api;
  final Uri _url;
  final String _plataforma;
  final String _versaoApp;
  final ArmazemConfig _armazem;

  /// Configuração em uso no app (atualizada a cada [carregar]).
  static AppConfig get atual => emUso.value;
  static set atual(AppConfig c) => emUso.value = c;

  /// O mesmo valor, para as telas (Serviços, Início) redesenharem quando o
  /// `app_config` chega depois que elas abriram.
  static final emUso = ValueNotifier<AppConfig>(AppConfig.padrao);

  /// [matricula] e [senhaMd5] nulos: só a parte pública (antes do login).
  Future<AppConfig> carregar({String? matricula, String? senhaMd5}) async {
    // A cópia só vale para o mesmo pedido (pública ou desta matrícula).
    final logado = matricula != null && senhaMd5 != null;
    final quem = logado ? matricula : '';
    final lida = await _armazem.ler();
    final guardada = lida != null && lida.quem == quem ? lida : null;
    AppConfig? daCopia() {
      if (guardada == null) return null;
      try {
        return AppConfig.deJson(
            jsonDecode(guardada.json) as Map<String, dynamic>,
            origem: OrigemConfig.cache,
            recebidoEm: guardada.em);
      } catch (_) {
        return null;
      }
    }

    try {
      final r = await _api.postCorpoJsonComEtag(_url,
          prefixo: 'CF',
          etag: guardada?.etag,
          corpo: {
            'plataforma': _plataforma,
            'app_versao': _versaoApp,
            if (logado) 'matricula': matricula,
            if (logado) 'senha': senhaMd5,
          });
      AppConfig config;
      if (r.naoMudou) {
        config = daCopia() ?? AppConfig.padrao;
      } else {
        final j = r.json;
        if (j is! Map<String, dynamic> || j['code'] != 1) {
          throw FalhaApp.respostaInvalida('CF', detalhe: 'app_config: $j');
        }
        final agora = DateTime.now();
        await _armazem.gravar(jsonEncode(j), r.etag, agora, quem);
        config =
            AppConfig.deJson(j, origem: OrigemConfig.rede, recebidoEm: agora);
      }
      registrar('config.recebida', dados: {
        'versao': config.versaoConfig,
        'origem': r.naoMudou ? 'cache' : 'rede',
      });
      return atual = config;
    } on FalhaApp catch (f) {
      registrarErro(f, tela: 'app_config', mostrado: false);
      registrar('config.recebida',
          resultado: 'falhou', codigo: f.codigo, dados: {'origem': 'cache'});
      return atual = daCopia() ?? AppConfig.padrao;
    }
  }
}

/// Lê o `app_config` com a sessão de agora: com matrícula e senha, a parte
/// do militar; sem elas, só a pública. Nunca lança (falha vai para o log).
Future<AppConfig> carregarAppConfig(
    {required ApiClient api, String? matricula, String? senha}) {
  final logado = (matricula ?? '').isNotEmpty && (senha ?? '').isNotEmpty;
  return RepositorioConfig(
    api: api,
    url: Uri.parse('$urlSigrh/app_config.php'),
    plataforma: AmbienteApp.plataforma,
    versaoApp: AmbienteApp.versao,
  ).carregar(
    matricula: logado ? matricula : null,
    senhaMd5: logado ? md5.convert(utf8.encode(senha!)).toString() : null,
  );
}
