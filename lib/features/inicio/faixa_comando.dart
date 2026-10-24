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
  static final Stream<List<Map<String, dynamic>>> _slides =
      FirebaseFirestore.instance.collection('stores').snapshots().map((s) => s.docs.map((d) => d.data()).toList());

  static const _cargos = ['Comandante-Geral', 'Subcomandante-Geral'];

  /// Um comandante do app_config no formato que os cartões desenham.
  static Map<String, dynamic> doPainel(Map<String, dynamic> c) {
    final posto = '${c['posto'] ?? ''}'.trim();
    final nome = '${c['nome_guerra'] ?? c['nome'] ?? ''}'.trim();
    String data(Object? v) {
      final d = DateTime.tryParse('${v ?? ''}');
      return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    final cursos = c['cursos'] is List ? (c['cursos'] as List).map((e) => '$e').join(' · ') : '';
    final completo = '${c['nome'] ?? ''}'.trim();
    return {
      'img': c['foto'] ?? '',
      'title': [posto, nome].where((e) => e.isNotEmpty).join(' '),
      'posto': posto,
      'nome_completo': c['nome_guerra'] != null ? completo : '',
      'cargo': c['cargo'],
      'subtitle': '${c['mensagem'] ?? ''}'.trim(),
      'detalhes': [
        if ('${c['quadro'] ?? ''}'.trim().isNotEmpty) (Icons.military_tech_outlined, 'Quadro', '${c['quadro']}'),
        if (data(c['desde']).isNotEmpty) (Icons.event_outlined, 'No cargo desde', data(c['desde'])),
        if (data(c['inclusao']).isNotEmpty) (Icons.badge_outlined, 'Na PMRR desde', data(c['inclusao'])),
        if ('${c['lotacao'] ?? ''}'.trim().isNotEmpty) (Icons.location_city_outlined, 'Lotação', '${c['lotacao']}'),
        if (cursos.isNotEmpty) (Icons.school_outlined, 'Cursos', cursos),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 84,
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

  /// O último Comando que o Firestore mandou.
  ///
  /// `_slides` é um stream broadcast: quem assina depois não recebe o que já
  /// passou. Sem esta cópia, toda remontagem da faixa (entrar no modo de
  /// edição, por exemplo) deixava a faixa vazia até o Firestore mandar algo
  /// novo — espaço reservado, nada desenhado e nenhum erro no log.
  static List<Map<String, dynamic>>? _ultimoComando;

  Widget _doFirestore() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _slides,
      initialData: _ultimoComando,
      builder: (context, snap) {
        if (snap.hasData) _ultimoComando = snap.data;
        final lista = snap.data ?? const [];
        if (lista.isEmpty) {
          // Carregando: reserva o espaço para a tela não pular.
          return snap.connectionState == ConnectionState.waiting
              ? const SizedBox(height: 84 + 16)
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
  const _CartaoComandante({required this.dados, required this.cargo, required this.tag});

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
              registrar('inicio.card_tocar', chave: 'home.comandantes', dados: {'cargo': cargo});
              Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
                opaque: false,
                barrierDismissible: true,
                barrierColor: const Color(0x6B000000),
                transitionDuration: const Duration(milliseconds: 400),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, a, __) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                  child: _ComandanteAberto(dados: dados, cargo: cargo, tag: tag),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Hero(tag: tag, child: _Foto(url: _foto, tamanho: 60)),
                const SizedBox(width: 10),
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
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(cargo,
                            maxLines: 1, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
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

/// O cartão aberto (protótipo `.cmd-modal`): capa azul-marinho com as três
/// estrelas douradas, foto de 112 com aro dourado, cargo, posto, nome
/// completo, mensagem à tropa e os dados do SIGRH aprovados no painel.
class _ComandanteAberto extends StatelessWidget {
  const _ComandanteAberto({required this.dados, required this.cargo, required this.tag});

  final Map<String, dynamic> dados;
  final String cargo;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escuro = theme.brightness == Brightness.dark;
    final fundo = escuro ? const Color(0xFF10161F) : Colors.white;
    final ouro = escuro ? const Color(0xFFFFB300) : const Color(0xFFB07700);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final linhaCor = theme.colorScheme.onSurface.withValues(alpha: .10);
    final posto = '${dados['posto'] ?? ''}'.trim();
    final completo = '${dados['nome_completo'] ?? ''}'.trim();
    final titulo = posto.isNotEmpty ? posto : '${dados['title'] ?? ''}'.trim();
    final mensagem = '${dados['subtitle'] ?? ''}'.trim();
    final linhas = dados['detalhes'] is List
        ? (dados['detalhes'] as List).whereType<(IconData, String, String)>().toList()
        : const <(IconData, String, String)>[];
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, mq.padding.top + 24, 14, mq.padding.bottom + 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Material(
            color: fundo,
            elevation: 12,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: cargo,
              child: SingleChildScrollView(
                child: Stack(children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 132,
                    child: _CapaComando(escuro: escuro, fundo: fundo),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: escuro ? Colors.white : theme.colorScheme.onSurface),
                        ),
                      ),
                      Hero(tag: tag, child: _Foto(url: '${dados['img'] ?? ''}', tamanho: 112, ouro: ouro)),
                      const SizedBox(height: 12),
                      Text(cargo.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ouro, fontSize: 12, letterSpacing: .96, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(titulo,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: theme.colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w700)),
                      if (completo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(completo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w600)),
                      ],
                      if (mensagem.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text('"$mensagem"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13.5, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface)),
                          ),
                        ),
                      if (linhas.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: .04),
                            border: Border.all(color: linhaCor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(children: [
                            for (final (i, (icone, rotulo, valor)) in linhas.indexed)
                              Container(
                                decoration:
                                    i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: linhaCor))),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  Icon(icone, size: 20, color: ouro),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(rotulo, style: TextStyle(fontSize: 11.5, color: mudo)),
                                      Text(valor, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
                                    ]),
                                  ),
                                ]),
                              ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text('Dados do SIGRH, aprovados no painel.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: mudo)),
                    ]),
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

/// Capa do cartão aberto: degradê azul-marinho (claro no tema claro),
/// brilho dourado em cima e as três estrelas de coronel douradas.
class _CapaComando extends StatelessWidget {
  const _CapaComando({required this.escuro, required this.fundo});
  final bool escuro;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -1),
            end: const Alignment(0.5, 1),
            colors:
                escuro ? const [Color(0xFF0A1A33), Color(0xFF13294A)] : const [Color(0xFFDCE6F3), Color(0xFFEEF3FA)],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            stops: const [0, .65],
            colors: [_dourado.withValues(alpha: escuro ? .28 : .22), _dourado.withValues(alpha: 0)],
          ),
        ),
      ),
      Positioned(
        top: 18,
        left: 0,
        right: 0,
        height: 74,
        child: Center(
          child: Opacity(
            opacity: escuro ? .28 : .5,
            child: const SizedBox(width: 220, height: 74, child: CustomPaint(painter: _EstrelasCoronel())),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fundo.withValues(alpha: 0), fundo],
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Três estrelas de cinco pontas douradas (o `estrelasCel` do protótipo,
/// caixa 120×40 com raio 15).
class _EstrelasCoronel extends CustomPainter {
  const _EstrelasCoronel();

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width / 120, size.height / 40);
    final dx = (size.width - 120 * k) / 2;
    final dy = (size.height - 40 * k) / 2;
    final ouro = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE7A3), Color(0xFFE0A100), Color(0xFF9A6A00)],
        stops: [0, .5, 1],
      ).createShader(Offset.zero & size);
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6 * k
      ..color = const Color(0xFFFFF3CC).withValues(alpha: .55);
    for (final cx in [20.0, 60.0, 100.0]) {
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final r = (i.isOdd ? 15 * .42 : 15) * k;
        final x = dx + cx * k + math.cos(a) * r;
        final y = dy + 20 * k + math.sin(a) * r;
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      p.close();
      canvas.drawPath(p, ouro);
      canvas.drawPath(p, traco);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Foto extends StatelessWidget {
  const _Foto({required this.url, required this.tamanho, this.ouro = _dourado});

  final String url;
  final double tamanho;
  final Color ouro;

  @override
  Widget build(BuildContext context) {
    final ok = url.startsWith('https://') || url.startsWith('http://');
    return Container(
      width: tamanho,
      height: tamanho,
      padding: EdgeInsets.all(tamanho > 60 ? 3 : 1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ouro,
        // Halo de 6 do protótipo (`.cmd-foto`) só na foto grande.
        boxShadow: tamanho > 60 ? [BoxShadow(color: ouro.withValues(alpha: .16), spreadRadius: 6)] : null,
      ),
      child: ClipOval(
        child: ok
            ? CachedImageFromPrefs(imageUrl: url)
            : Container(
                color: _navyMeio, child: Icon(Icons.person_rounded, color: Colors.white70, size: tamanho * 0.6)),
      ),
    );
  }
}

/// A arte especial `estrelas` (PAINEL_ADMIN §5.3b): degradê azul-marinho,
/// brilho dourado e três estrelas brancas apagadas no canto direito.
class _FundoEstrelas extends StatelessWidget {
  const _FundoEstrelas({required this.child, required this.raio});

  final Widget child;
  final double raio;

  @override
  Widget build(BuildContext context) {
    const t = 46.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navyMeio]),
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
              child: Icon(Icons.star_rounded, size: t, color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          Positioned(
            right: t * 0.75,
            top: t * 0.05,
            child: Icon(Icons.star_rounded, size: t * 0.4, color: Colors.white.withValues(alpha: 0.14)),
          ),
          Positioned(
            right: t * 0.55,
            bottom: -t * 0.08,
            child: Icon(Icons.star_rounded, size: t * 0.34, color: Colors.white.withValues(alpha: 0.12)),
          ),
          child,
        ]),
      ),
    );
  }
}
