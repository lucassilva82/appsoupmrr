import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enderecos.dart';
import '../../core/erros/estado_erro.dart';
import '../../core/erros/falha_app.dart';
import '../../core/log/registro_log.dart';
import '../../core/rede/api_client.dart';
import '../../models/auth_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/vidro.dart';

const _chave = 'rh.carreira';

/// Um marco da carreira (P5, docs/SOUPM_2_2.md §11): incorporação,
/// promoção, comportamento, escolaridade ou tempo averbado.
class MarcoCarreira {
  const MarcoCarreira({required this.data, required this.tipo, required this.titulo, this.detalhe});
  final DateTime data;
  final String tipo;
  final String titulo;
  final String? detalhe;

  static MarcoCarreira? deJson(Object? j) {
    if (j is! Map || j['titulo'] is! String) return null;
    final d = DateTime.tryParse('${j['data'] ?? ''}');
    if (d == null) return null;
    return MarcoCarreira(data: d, tipo: '${j['tipo'] ?? ''}', titulo: j['titulo'] as String, detalhe: j['detalhe'] as String?);
  }
}

/// Resposta do `carreira.php`. [falhas] são as seções que o SIGRH não
/// respondeu: aparecem como "não foi possível conferir", nunca como vazio.
class LinhaDoTempo {
  const LinhaDoTempo({required this.marcos, required this.falhas});
  final List<MarcoCarreira> marcos;
  final List<String> falhas;
}

class CarreiraRepositorio {
  CarreiraRepositorio({required this.api, required this.matricula, required this.senhaMd5, Uri? url})
      : url = url ?? Uri.parse('$urlSigrh/carreira.php');

  final ApiClient api;
  final String matricula;
  final String senhaMd5;
  final Uri url;

  static const prefixo = 'CR';

  Future<LinhaDoTempo> carregar() async {
    final j = await api.postJson(url, prefixo: prefixo, campos: {'matricula': matricula, 'senha': senhaMd5});
    if (j is! Map) throw FalhaApp.respostaInvalida(prefixo, detalhe: 'carreira.php não devolveu objeto');
    if (j['code'] != 1) throw FalhaApp.daApi(prefixo, '${j['erro'] ?? 'ERRO_SERVIDOR'}', j['message'] as String?);
    final marcos = [
      for (final e in (j['eventos'] as List? ?? const []))
        if (MarcoCarreira.deJson(e) case final m?) m,
    ]..sort((a, b) => a.data.compareTo(b.data));
    return LinhaDoTempo(marcos: marcos, falhas: [for (final f in (j['falhas'] as List? ?? const [])) '$f']);
  }
}

const _nomesSecao = {
  'incorporacao': 'a incorporação',
  'promocoes': 'as promoções',
  'comportamento': 'o comportamento',
  'escolaridade': 'a escolaridade',
  'averbacao': 'o tempo averbado',
};

IconData _icone(String tipo) => switch (tipo) {
      'incorporacao' => Icons.flag_rounded,
      'promocao' => Icons.military_tech_rounded,
      'comportamento' => Icons.verified_rounded,
      'escolaridade' => Icons.school_rounded,
      'averbacao' => Icons.history_rounded,
      _ => Icons.circle,
    };

String _data(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Linha do tempo da carreira (`rh.carreira`).
class CarreiraPage extends StatefulWidget {
  const CarreiraPage({super.key, this.repositorio});
  final CarreiraRepositorio? repositorio;

  @override
  State<CarreiraPage> createState() => _CarreiraPageState();
}

class _CarreiraPageState extends State<CarreiraPage> {
  late final CarreiraRepositorio _repo = widget.repositorio ?? _padrao();
  LinhaDoTempo? _linha;
  FalhaApp? _falha;

  CarreiraRepositorio _padrao() {
    final auth = context.read<Auth>();
    return CarreiraRepositorio(
      api: ApiClient(),
      matricula: auth.matricula ?? '',
      senhaMd5: md5.convert(utf8.encode(auth.password ?? '')).toString(),
    );
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _falha = null);
    try {
      final l = await _repo.carregar();
      registrar('carreira.ver', chave: _chave, dados: {'marcos': l.marcos.length, 'falhas': l.falhas.length});
      if (mounted) setState(() => _linha = l);
    } on FalhaApp catch (f) {
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    } catch (e) {
      final f = FalhaApp.inesperada(CarreiraRepositorio.prefixo, e);
      registrarErro(f, tela: _chave);
      if (mounted) setState(() => _falha = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linha = _linha;
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Linha do tempo'),
        body: _falha != null && linha == null
            ? EstadoErro(falha: _falha!, aoTentar: _carregar, tela: _chave, chave: _chave)
            : linha == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _carregar, child: _Conteudo(linha: linha)),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.linha});
  final LinhaDoTempo linha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anos = <int, List<MarcoCarreira>>{};
    for (final m in linha.marcos.reversed) {
      anos.putIfAbsent(m.data.year, () => []).add(m);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Os marcos da sua carreira na PMRR, do mais recente ao mais antigo, como estão no SIGRH.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final f in linha.falhas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CartaoVidro(
              raio: 14,
              padding: const EdgeInsets.all(12),
              tingimento: theme.colorScheme.error,
              child: Row(children: [
                Icon(Icons.cloud_off_rounded, size: AppIconSize.sm, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Não foi possível conferir ${_nomesSecao[f] ?? f} no SIGRH. Puxe para atualizar. '
                      'Código CR-${f.toUpperCase()}.',
                      style: theme.textTheme.bodySmall),
                ),
              ]),
            ),
          ),
        if (linha.marcos.isEmpty && linha.falhas.isEmpty)
          CartaoVidro(
            child: Text('O SIGRH ainda não tem marcos registrados para você. Se faltar algo, procure a '
                'Diretoria de Recursos Humanos - PMRR.'),
          ),
        for (final MapEntry(key: ano, value: marcos) in anos.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Semantics(
              header: true,
              child: Text('$ano',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          CartaoVidro(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(children: [
              for (final (i, m) in marcos.indexed) _Marco(marco: m, ultimo: i == marcos.length - 1),
            ]),
          ),
        ],
      ],
    );
  }
}

class _Marco extends StatelessWidget {
  const _Marco({required this.marco, required this.ultimo});
  final MarcoCarreira marco;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dourado só no escuro: no claro, o tom escuro da arte de tempo de serviço
    // (o dourado claro não fecha 3:1 sobre fundo claro).
    final cor = marco.tipo != 'promocao'
        ? theme.colorScheme.primary
        : theme.brightness == Brightness.dark
            ? AppColors.gold
            : const Color(0xFF8A5A00);
    return Semantics(
      label: '${_data(marco.data)}: ${marco.titulo}${marco.detalhe != null ? ', ${marco.detalhe}' : ''}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 32,
            child: Column(children: [
              const SizedBox(height: 8),
              Icon(_icone(marco.tipo), size: AppIconSize.sm, color: cor),
              if (!ultimo)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(marco.titulo, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text([_data(marco.data), if (marco.detalhe != null) marco.detalhe!].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
