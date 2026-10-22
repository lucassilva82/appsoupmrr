import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ambiente_app.dart';
import '../erros/falha_app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Log de ações e erros do app (docs/SOUPM_2_2.md §9.2; regra "Tudo tem log").
//
// Toda interação vira um evento `<modulo>.<acao>` e todo erro, mostrado ou
// não, vira um registro com código. Tudo entra numa fila local (até 500, os
// mais antigos saem primeiro) e vai em lotes de até 50 para `log.php`: a cada
// 30 s, ao ir para o fundo e ao abrir. Sem rede, espera. Erro do próprio envio
// não gera log, para não entrar em laço.
//
// Nunca entra no log: senha, MD5, token, CPF completo, valores e conteúdo de
// documentos. Os dados extras passam por [_limpar] antes de entrar na fila.
//
// Log leve (decisão do usuário, 22/10/2026): os últimos 20 eventos da sessão
// ficam só na memória e vão junto com cada erro (`passos`), para o suporte ver
// o caminho até ele. Os eventos de [soPassos] nunca viram linha no banco.
// ─────────────────────────────────────────────────────────────────────────────

/// Onde a fila fica guardada entre uma abertura e outra.
abstract class ArmazemLog {
  Future<List<Map<String, Object?>>> ler();
  Future<void> gravar(List<Map<String, Object?>> itens);
}

class ArmazemLogPreferencias implements ArmazemLog {
  static const _chave = 'soupm_log_fila';

  @override
  Future<List<Map<String, Object?>>> ler() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chave);
    if (bruto == null) return [];
    try {
      return (jsonDecode(bruto) as List)
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> gravar(List<Map<String, Object?>> itens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, jsonEncode(itens));
  }
}

/// Manda um lote ao servidor. Lança se não foi aceito.
typedef EnviarLog = Future<void> Function(List<Map<String, Object?>> itens);

class RegistroLog {
  RegistroLog({
    required ArmazemLog armazem,
    required EnviarLog enviar,
    required String? Function() matricula,
    String? aparelhoId,
    this.limite = 500,
    this.lote = 50,
  })  : _armazem = armazem,
        _enviar = enviar,
        _matricula = matricula,
        _aparelhoId = aparelhoId ?? _idAleatorio(),
        sessaoId = _idAleatorio();

  /// Instância do app, criada no `main`. Nula nos testes que não a usam:
  /// [registrar] e [registrarErro] simplesmente não fazem nada.
  static RegistroLog? atual;

  final ArmazemLog _armazem;
  final EnviarLog _enviar;
  final String? Function() _matricula;
  final String _aparelhoId;

  /// Muda a cada abertura do app; junta tudo o que o militar fez numa sessão.
  final String sessaoId;
  final int limite;
  final int lote;

  /// Movimentos que só servem de contexto para um erro.
  static const soPassos = {
    'app.fundo',
    'app.voltar',
    'tela.sair',
    'rede.trocou',
    'config.recebida',
  };
  static const maxPassos = 20;
  final _passos = <Map<String, Object?>>[];

  /// Cópia dos últimos passos (para testes e para a tela de erro).
  List<Map<String, Object?>> get passos => List.unmodifiable(_passos);

  // Leitura e gravação da fila uma de cada vez (APRENDIZADOS §26).
  Future<void> _fila = Future.value();
  bool _enviando = false;
  Timer? _relogio;

  Future<void> evento(
    String nome, {
    String? chave,
    String resultado = 'ok',
    String? codigo,
    Map<String, Object?>? dados,
  }) {
    _passos.add({
      'evento': nome,
      if (chave != null) 'chave': chave,
      if (resultado != 'ok') 'resultado': resultado,
      if (codigo != null) 'codigo': codigo,
      'em': DateTime.now().toIso8601String(),
    });
    if (_passos.length > maxPassos) _passos.removeAt(0);
    if (soPassos.contains(nome)) return Future.value();
    return _acrescentar({
      'tipo': 'evento',
      'evento': nome,
      'chave': chave,
      'resultado': resultado,
      'codigo': codigo,
      if (dados != null) 'dados': _limpar(dados),
    });
  }

  Future<void> erro(
    FalhaApp falha, {
    String? tela,
    bool mostrado = true,
    String? pilha,
  }) =>
      _acrescentar({
        'tipo': 'erro',
        'codigo': falha.codigo,
        'modulo': falha.codigo.split('-').first,
        'origem': falha.origem.name,
        'tela': tela,
        'mensagem': falha.detalhe ?? falha.titulo,
        'pilha': pilha,
        'mostrado': mostrado,
        if (_passos.isNotEmpty) 'passos': List.of(_passos),
      });

  /// Manda o lote mais antigo. Só tira da fila o que o servidor aceitou.
  Future<void> enviar() async {
    if (_enviando) return;
    _enviando = true;
    try {
      final itens = await _emFila(_armazem.ler);
      if (itens.isEmpty) return;
      final pedaco = itens.take(lote).toList();
      await _enviar(pedaco);
      await _emFila(() async {
        final agora = await _armazem.ler();
        // Tira só os que foram enviados (pelo id), mesmo que entrem outros
        // enquanto o lote viajava.
        final ids = pedaco.map((e) => e['id']).toSet();
        await _armazem
            .gravar(agora.where((e) => !ids.contains(e['id'])).toList());
      });
    } catch (e) {
      // Sem rede ou servidor fora: fica para a próxima. Não vira log.
      debugPrint('[LOG] envio adiado: $e');
    } finally {
      _enviando = false;
    }
  }

  /// Envio a cada 30 s enquanto o app está aberto.
  void iniciarRelogio({Duration intervalo = const Duration(seconds: 30)}) {
    _relogio?.cancel();
    _relogio = Timer.periodic(intervalo, (_) => enviar());
  }

  void pararRelogio() => _relogio?.cancel();

  Future<void> _acrescentar(Map<String, Object?> item) => _emFila(() async {
        final itens = await _armazem.ler();
        itens.add({
          'id': _idAleatorio(),
          ...item,
          'ocorrido_em': DateTime.now().toIso8601String(),
          'matricula': _matricula(),
          'aparelho_id': _aparelhoId,
          'sessao_id': sessaoId,
          'plataforma': AmbienteApp.plataforma,
          'app_versao': AmbienteApp.versao,
          'app_build': AmbienteApp.build,
          'aparelho': AmbienteApp.aparelho,
        });
        final sobra = itens.length - limite;
        await _armazem.gravar(sobra > 0 ? itens.sublist(sobra) : itens);
      });

  Future<T> _emFila<T>(Future<T> Function() passo) {
    final r = _fila.then((_) => passo());
    _fila = r.then((_) {}, onError: (_) {});
    return r;
  }

  static final _sensivel = RegExp(
      r'senha|password|md5|cpf|token|valor|conteudo',
      caseSensitive: false);

  static Map<String, Object?> _limpar(Map<String, Object?> dados) =>
      Map.fromEntries(dados.entries.where((e) => !_sensivel.hasMatch(e.key)));

  static String _idAleatorio() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Atalhos para qualquer tela registrar sem saber de onde vem a instância.
void registrar(String evento,
        {String? chave,
        String resultado = 'ok',
        String? codigo,
        Map<String, Object?>? dados}) =>
    unawaited(RegistroLog.atual?.evento(evento,
        chave: chave, resultado: resultado, codigo: codigo, dados: dados));

void registrarErro(FalhaApp falha,
        {String? tela, bool mostrado = true, String? pilha}) =>
    unawaited(RegistroLog.atual
        ?.erro(falha, tela: tela, mostrado: mostrado, pilha: pilha));
