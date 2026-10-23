import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/log/registro_log.dart';
import '../../widgets/carouselSlider.dart' show CachedImageFromPrefs;

/// Faixa do Comando (docs/SOUPM_2_2.md §4.1): dois cartões lado a lado,
/// 64 pt, com a arte `estrelas` (azul-marinho, brilho dourado e três
/// estrelas apagadas). Tocar num deles abre o cartão grande dele.
///
/// Os dados vêm do `app_config` (`home.comandantes`), aprovados no painel a
/// partir do SIGRH. Enquanto o painel não aprovar ninguém, vêm da coleção
/// 'stores' do Firestore, como na 2.1.x.
class FaixaComando extends StatelessWidget {
  const FaixaComando({super.key});

  // Uma assinatura só para o app: a Início redesenha a faixa quando o
  // app_config chega, e um stream novo a cada vez fazia a faixa piscar.
  static final Stream<List<Map<String, dynamic>>> _slides = FirebaseFirestore.instance
      .collection('stores')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static const _cargos = ['Comandante-Geral', 'Subcomandante-Geral'];

  /// Um comandante do app_config no formato que os cartões desenham.
  static Map<String, dynamic> doPainel(Map<String, dynamic> c) {
    final posto = '${c['posto'] ?? ''}'.trim();
    final nome = '${c['nome_guerra'] ?? c['nome'] ?? ''}'.trim();
    String data(Object? v) {
      final d = DateTime.tryParse('${v ?? ''}');
      return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final cursos = c['cursos'] is List ? (c['cursos'] as List).map((e) => '$e').join(', ') : '';
    return {
      'img': c['foto'] ?? '',
      'title': [posto, nome].where((e) => e.isNotEmpty).join(' '),
      'cargo': c['cargo'],
      'subtitle': '${c['mensagem'] ?? ''}'.trim(),
      'detalhes': [
        if ('${c['nome'] ?? ''}'.trim().isNotEmpty && c['nome_guerra'] != null) ('Nome', '${c['nome']}'),
        if ('${c['quadro'] ?? ''}'.trim().isNotEmpty) ('Quadro', '${c['quadro']}'),
        if (data(c['desde']).isNotEmpty) ('No cargo desde', data(c['desde'])),
        if (data(c['inclusao']).isNotEmpty) ('Na PMRR desde', data(c['inclusao'])),
        if ('${c['lotacao'] ?? ''}'.trim().isNotEmpty) ('Lotação', '${c['lotacao']}'),
        if (cursos.isNotEmpty) ('Cursos', cursos),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: RepositorioConfig.emUso,
      builder: (context, config, _) {
        final aprovados = config.bloco('home.comandantes')?.itens ?? const [];
        if (aprovados.isNotEmpty) return _faixa([for (final c in aprovados) doPainel(c)]);
        return _doFirestore();
      },
    );
  }

  Widget _faixa(List<Map<String, dynamic>> lista) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SizedBox(
          height: 64,
          child: Row(children: [
            for (var i = 0; i < math.min(2, lista.length); i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _CartaoComandante(
                  dados: lista[i],
                  cargo: '${lista[i]['cargo'] ?? _cargos[i]}',
                  tag: 'comando-$i',
                ),
              ),
            ],
          ]),
        ),
      );

  Widget _doFirestore() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _slides,
      builder: (context, snap) {
        final lista = snap.data ?? const [];
        if (lista.isEmpty) {
          // Carregando: reserva o espaço para a tela não pular.
          return snap.connectionState == ConnectionState.waiting
              ? const SizedBox(height: 64 + 16)
              : const SizedBox.shrink();
        }
        return _faixa([
          for (var i = 0; i < lista.length; i++) {...lista[i], 'cargo': i < _cargos.length ? _cargos[i] : ''},
        ]);
      },
    );
  }
}

const _navy = Color(0xFF081A36);
const _navyMeio = Color(0xFF16396B);
const _dourado = Color(0xFFE0A100);

class _CartaoComandante extends StatelessWidget {
  const _CartaoComandante(
      {required this.dados, required this.cargo, required this.tag});

  final Map<String, dynamic> dados;
  final String cargo;
  final String tag;

  String get _foto => '${dados['img'] ?? ''}';
  String get _nome => '${dados['title'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$cargo, $_nome. Toque para ver mais.',
      excludeSemantics: true,
      child: _FundoEstrelas(
        raio: 16,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              registrar('inicio.card_tocar',
                  chave: 'home.comandantes', dados: {'cargo': cargo});
              Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                barrierDismissible: true,
                barrierColor: Colors.black54,
                transitionDuration: const Duration(milliseconds: 400),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, a, __) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                  child: _ComandanteAberto(
                      dados: dados, cargo: cargo, tag: tag),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Hero(tag: tag, child: _Foto(url: _foto, tamanho: 40)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Posto e nome numa linha que encolhe, sem reticências:
                      // o nome cortado não identifica ninguém.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_nome,
                            maxLines: 1,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(cargo,
                            maxLines: 1,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// O cartão aberto: foto grande com aro dourado, cargo, nome e o texto
/// que o Firestore traz. Fecha tocando fora ou no botão.
class _ComandanteAberto extends StatelessWidget {
  const _ComandanteAberto(
      {required this.dados, required this.cargo, required this.tag});

  final Map<String, dynamic> dados;
  final String cargo;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final subtitulo = '${dados['subtitle'] ?? ''}'.trim();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _FundoEstrelas(
            raio: 22,
            grande: true,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Hero(
                      tag: tag,
                      child: _Foto(url: '${dados['img'] ?? ''}', tamanho: 112)),
                  const SizedBox(height: 14),
                  Text(cargo.toUpperCase(),
                      style: const TextStyle(
                          color: _dourado,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${dados['title'] ?? ''}'.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13)),
                  ],
                  for (final (rotulo, valor) in (dados['detalhes'] is List
                      ? (dados['detalhes'] as List).whereType<(String, String)>()
                      : const <(String, String)>[]))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 110,
                          child: Text(rotulo,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar',
                        style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.tamanho});

  final String url;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final ok = url.startsWith('https://') || url.startsWith('http://');
    return Container(
      width: tamanho,
      height: tamanho,
      padding: EdgeInsets.all(tamanho > 60 ? 3 : 1.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _dourado),
      child: ClipOval(
        child: ok
            ? CachedImageFromPrefs(imageUrl: url)
            : Container(
                color: _navyMeio,
                child: Icon(Icons.person_rounded,
                    color: Colors.white70, size: tamanho * 0.6)),
      ),
    );
  }
}

/// A arte especial `estrelas` (PAINEL_ADMIN §5.3b): degradê azul-marinho,
/// brilho dourado e três estrelas brancas apagadas no canto direito.
class _FundoEstrelas extends StatelessWidget {
  const _FundoEstrelas(
      {required this.child, required this.raio, this.grande = false});

  final Widget child;
  final double raio;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final t = grande ? 120.0 : 46.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, _navyMeio]),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, -1.2),
                  radius: 1.0,
                  colors: [
                    _dourado.withValues(alpha: 0.30),
                    _dourado.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -t * 0.15,
            top: -t * 0.2,
            child: Transform.rotate(
              angle: 0.25,
              child: Icon(Icons.star_rounded,
                  size: t, color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          Positioned(
            right: t * 0.75,
            top: t * 0.05,
            child: Icon(Icons.star_rounded,
                size: t * 0.4, color: Colors.white.withValues(alpha: 0.14)),
          ),
          Positioned(
            right: t * 0.55,
            bottom: -t * 0.08,
            child: Icon(Icons.star_rounded,
                size: t * 0.34, color: Colors.white.withValues(alpha: 0.12)),
          ),
          child,
        ]),
      ),
    );
  }
}
