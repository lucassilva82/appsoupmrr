import 'package:flutter/material.dart';

/// Arte de um cartão (docs/SOUPM_2_2.md §4.6, PAINEL_ADMIN §5.3b): degradê
/// da base ao meio, brilho e trilhas na cor de destaque e três ícones
/// grandes e apagados no canto direito. O painel escolhe a arte pela chave;
/// a chave desconhecida cai na `rh`.
class Arte {
  const Arte(this.base, this.meio, this.destaque, this.icones);

  final Color base;
  final Color meio;
  final Color destaque;
  final List<IconData> icones;

  /// Carga inicial do catálogo (mesmas cores do painel).
  static const catalogo = <String, Arte>{
    'cc': Arte(Color(0xFF0A2350), Color(0xFF1565C0), Color(0xFF4FD8F0),
        [Icons.payments_outlined, Icons.receipt_long_outlined, Icons.savings_outlined]),
    'ts': Arte(Color(0xFF251800), Color(0xFF8A5A00), Color(0xFFFFC233),
        [Icons.military_tech_outlined, Icons.hourglass_top_outlined, Icons.workspace_premium_outlined]),
    'fe': Arte(Color(0xFF00303A), Color(0xFF00838F), Color(0xFF80DEEA),
        [Icons.beach_access_outlined, Icons.flight_outlined, Icons.wb_sunny_outlined]),
    'dc': Arte(Color(0xFF1A1846), Color(0xFF4338CA), Color(0xFFA5B4FC),
        [Icons.tips_and_updates_outlined, Icons.search, Icons.lightbulb_outline]),
    'pe': Arte(Color(0xFF2B0F12), Color(0xFF9F1D2B), Color(0xFFFF9E9E),
        [Icons.pending_actions_outlined, Icons.assignment_late_outlined, Icons.task_alt]),
    'rosa': Arte(Color(0xFF3A0A1E), Color(0xFFB0225A), Color(0xFFFF8FB8),
        [Icons.favorite_outline, Icons.volunteer_activism_outlined, Icons.health_and_safety_outlined]),
    'rh': Arte(Color(0xFF14205C), Color(0xFF4338CA), Color(0xFF38BDF8),
        [Icons.badge_outlined, Icons.receipt_long_outlined, Icons.verified_outlined]),
    'operacional': Arte(Color(0xFF071A33), Color(0xFF1D4ED8), Color(0xFFEF4444),
        [Icons.local_police_outlined, Icons.calendar_month_outlined, Icons.shield_outlined]),
    // Verde de operação: o card de Operações saía azul como o Contracheque e
    // quase igual ao índigo das Dicas, e os três empilhados viravam um bloco
    // só (usuário, 30/10/2026). A arte `operacional` continua azul para as
    // telas da área; só o card de resumo usa esta.
    'operacoes': Arte(Color(0xFF07220F), Color(0xFF15692F), Color(0xFFB9F27C),
        [Icons.shield_outlined, Icons.local_police_outlined, Icons.calendar_month_outlined]),
    'normas': Arte(Color(0xFF2A1704), Color(0xFFA15C07), Color(0xFFFCD34D),
        [Icons.gavel_outlined, Icons.menu_book_outlined, Icons.balance_outlined]),
    'gestao': Arte(Color(0xFF1A1405), Color(0xFF7A5800), Color(0xFFFFC233),
        [Icons.monitor_heart_outlined, Icons.groups_outlined, Icons.military_tech_outlined]),
    'atendimento': Arte(Color(0xFF032A28), Color(0xFF0F766E), Color(0xFF5EEAD4),
        [Icons.support_agent_outlined, Icons.forum_outlined, Icons.build_outlined]),
    'institucional': Arte(Color(0xFF06281A), Color(0xFF15803D), Color(0xFF86EFAC),
        [Icons.account_balance_outlined, Icons.campaign_outlined, Icons.newspaper_outlined]),
  };

  /// Artes do painel (app_config `artes`), por cima do catálogo do código.
  /// Preenchido pelo AppConfig; arte nova ou editada vale sem versão nova.
  static Map<String, Arte> doPainel = const {};

  static Arte de(String? chave) => doPainel[chave] ?? catalogo[chave] ?? catalogo['rh']!;

  /// Lê uma arte do app_config: três cores #RRGGBB e até três ícones por
  /// nome. Cor inválida descarta a arte; ícone desconhecido usa o da arte do
  /// catálogo de mesma chave (ou um neutro).
  static Arte? deJson(Map j) {
    final cores = j['cores'];
    if (cores is! List || cores.length != 3) return null;
    final c = <Color>[];
    for (final hex in cores) {
      final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('$hex');
      if (m == null) return null;
      c.add(Color(int.parse('FF${m.group(1)}', radix: 16)));
    }
    final base = catalogo['${j['chave']}'];
    final nomes = j['icones'] is List ? (j['icones'] as List).map((e) => '$e').toList() : const <String>[];
    final icones = [
      for (var i = 0; i < 3; i++)
        (i < nomes.length ? _iconesPorNome[nomes[i]] : null) ?? base?.icones[i] ?? Icons.apps_rounded,
    ];
    return Arte(c[0], c[1], c[2], icones);
  }

  /// Os nomes do catálogo de ícones do painel que este app sabe desenhar.
  static const _iconesPorNome = <String, IconData>{
    'payments': Icons.payments_outlined, 'receipt_long': Icons.receipt_long_outlined,
    'savings': Icons.savings_outlined, 'military_tech': Icons.military_tech_outlined,
    'hourglass_top': Icons.hourglass_top_outlined, 'workspace_premium': Icons.workspace_premium_outlined,
    'beach_access': Icons.beach_access_outlined, 'flight': Icons.flight_outlined, 'wb_sunny': Icons.wb_sunny_outlined,
    'tips_and_updates': Icons.tips_and_updates_outlined, 'search': Icons.search, 'lightbulb': Icons.lightbulb_outline,
    'pending_actions': Icons.pending_actions_outlined, 'assignment_late': Icons.assignment_late_outlined,
    'task_alt': Icons.task_alt, 'favorite': Icons.favorite_outline,
    'volunteer_activism': Icons.volunteer_activism_outlined,
    'health_and_safety': Icons.health_and_safety_outlined, 'badge': Icons.badge_outlined,
    'verified': Icons.verified_outlined,
    'local_police': Icons.local_police_outlined, 'calendar_month': Icons.calendar_month_outlined,
    'shield': Icons.shield_outlined, 'gavel': Icons.gavel_outlined, 'menu_book': Icons.menu_book_outlined,
    'balance': Icons.balance_outlined, 'monitoring': Icons.monitor_heart_outlined, 'groups': Icons.groups_outlined,
    'support_agent': Icons.support_agent_outlined, 'forum': Icons.forum_outlined, 'build': Icons.build_outlined,
    'account_balance': Icons.account_balance_outlined, 'campaign': Icons.campaign_outlined,
    'newspaper': Icons.newspaper_outlined, 'celebration': Icons.celebration_outlined, 'flag': Icons.flag_outlined,
    'emergency': Icons.emergency_outlined, 'radar': Icons.radar, 'psychology': Icons.psychology_outlined,
    'diversity_1': Icons.diversity_1_outlined, 'man': Icons.man_outlined,
    'fingerprint': Icons.fingerprint, 'notifications': Icons.notifications_outlined, 'event': Icons.event_outlined,
    'description': Icons.description_outlined, 'lock': Icons.lock_outline, 'place': Icons.place_outlined,
    'chat': Icons.chat_outlined, 'rocket_launch': Icons.rocket_launch_outlined, 'handshake': Icons.handshake_outlined,
    // Categorias e assuntos dos comunicados (protótipo).
    'how_to_vote': Icons.how_to_vote_outlined, 'schedule': Icons.schedule_rounded, 'vaccines': Icons.vaccines_outlined,
    'event_busy': Icons.event_busy_outlined, 'contact_page': Icons.contact_page_outlined,
    'school': Icons.school_outlined,
    'phone_iphone': Icons.phone_iphone_rounded, 'calendar_today': Icons.calendar_today_outlined,
    'new_releases': Icons.new_releases_outlined, 'request_quote': Icons.request_quote_outlined,
    'edit_note': Icons.edit_note_rounded, 'priority_high': Icons.priority_high_rounded,
  };
}

/// Ícone do catálogo do painel pelo nome ('campaign', 'local_police'...).
IconData? iconePorNome(String? nome) => Arte._iconesPorNome[nome];

/// Onde a arte vai: muda o tamanho dos ícones e a direção do véu, como no
/// protótipo (`.arte-card` e `.sv-area`).
enum FormatoArte {
  /// Cards de resumo e da Início: ícones 120/48/38 e véu da esquerda para
  /// a direita (o texto fica à esquerda).
  card,

  /// Cartões das áreas de Serviços: ícones 84/38/30 e véu de cima para
  /// baixo (o nome fica embaixo).
  area,
}

/// Fundo com a arte no estilo cheio (protótipo `arteArea`). O conteúdo vai
/// por cima, sobre um véu escuro que garante texto branco legível (4,5:1)
/// nos dois temas.
/// O card com arte é sempre escuro (não clareia no tema claro, SOUPM_2_2
/// §4.6). Quem desenha sobre a arte lê as cores deste tema, senão o
/// azul-marinho do tema claro some sobre o fundo escuro.
ThemeData temaSobreArte(ThemeData atual) => atual.brightness == Brightness.dark
    ? atual
    : atual.copyWith(
        brightness: Brightness.dark,
        colorScheme: atual.colorScheme.copyWith(
          brightness: Brightness.dark,
          onSurface: Colors.white,
          primary: const Color(0xFF42A5F5),
        ),
      );

class FundoArte extends StatelessWidget {
  const FundoArte({
    super.key,
    required this.arte,
    required this.child,
    this.raio = 18,
    this.tamanhoIcone,
    this.formato = FormatoArte.card,
    this.imagem,
  });

  final Arte arte;
  final Widget child;
  final double raio;

  /// Imagem aprovada no painel (https). Vence a arte: some o desenho, fica o
  /// degradê de fundo (enquanto carrega ou se falhar) e um véu mais forte,
  /// para o texto branco passar de 4,5:1 sobre qualquer foto.
  final String? imagem;

  /// Tamanho do ícone grande; os outros dois e as posições acompanham.
  /// Nulo: o do formato (120 no card, 84 na área).
  final double? tamanhoIcone;
  final FormatoArte formato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conteudo =
        tema.brightness == Brightness.dark ? child : Theme(data: temaSobreArte(tema), child: child);
    final area = formato == FormatoArte.area;
    final base = area ? 84.0 : 120.0;
    final k = (tamanhoIcone ?? base) / base;
    // [tamanho, direita, cima ou baixo, giro em graus, opacidade]
    final i1 = area ? [84.0, -8.0, -6.0] : [120.0, -14.0, -18.0];
    final i2 = area ? [38.0, 52.0, 30.0] : [48.0, 92.0, 24.0];
    final i3 = area ? [30.0, 14.0, 30.0] : [38.0, 24.0, 22.0];

    Widget icone(IconData d, double tam, double giro, double alfa) => Transform.rotate(
          angle: giro * 3.1415926535 / 180,
          child: Icon(d, size: tam * k, color: Colors.white.withValues(alpha: alfa)),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // linear-gradient(150deg, base, meio)
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -0.866),
            end: const Alignment(0.5, 0.866),
            colors: [arte.base, arte.meio],
          ),
        ),
        child: Stack(
          children: imagem != null
              ? [
                  Positioned.fill(
                    child: Image.network(
                      imagem!,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.1, 1],
                          colors: [Color(0x33000000), Color(0xC7000000)],
                        ),
                      ),
                    ),
                  ),
                  conteudo,
                ]
              : [
                  // Brilho: radial-gradient(120% 90% at 100% 0%, destaque .45, 0 55%).
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(1, -1),
                          radius: 1.2,
                          stops: const [0, .55],
                          colors: [
                            arte.destaque.withValues(alpha: 0.45),
                            arte.destaque.withValues(alpha: 0),
                          ],
                          transform: const _Elipse(.75),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _Trilhas(arte.destaque)),
                  ),
                  Positioned(
                    right: i1[1] * k,
                    top: i1[2] * k,
                    child: icone(arte.icones[0], i1[0], -12, .20),
                  ),
                  Positioned(
                    right: i2[1] * k,
                    top: i2[2] * k,
                    child: icone(arte.icones[1], i2[0], 10, .16),
                  ),
                  Positioned(
                    right: i3[1] * k,
                    bottom: i3[2] * k,
                    child: icone(arte.icones[2], i3[0], -6, .13),
                  ),
                  // Véu escuro, do lado do texto.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: area
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.35, 1],
                                colors: [Color(0x00000000), Color(0x8C000000)],
                              )
                            : const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0, 0.7],
                                colors: [Color(0x61000000), Color(0x0D000000)],
                              ),
                      ),
                    ),
                  ),
                  conteudo,
                ],
        ),
      ),
    );
  }
}

/// Achata o brilho na vertical (a elipse de 120% × 90% do protótipo).
class _Elipse extends GradientTransform {
  const _Elipse(this.y);
  final double y;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final c = bounds.topRight;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, y, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

/// As trilhas de circuito do protótipo: três caminhos num quadro de
/// 200 × 120, cobrindo o cartão (`preserveAspectRatio: slice`), com um ponto
/// na ponta de cada um.
class _Trilhas extends CustomPainter {
  _Trilhas(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    final escala = s.width / 200 > s.height / 120 ? s.width / 200 : s.height / 120;
    final dx = (s.width - 200 * escala) / 2, dy = (s.height - 120 * escala) / 2;
    Offset o(double x, double y) => Offset(dx + x * escala, dy + y * escala);
    Path linha(List<List<double>> pts) {
      final p = Path()..moveTo(o(pts[0][0], pts[0][1]).dx, o(pts[0][0], pts[0][1]).dy);
      for (final q in pts.skip(1)) {
        final v = o(q[0], q[1]);
        p.lineTo(v.dx, v.dy);
      }
      return p;
    }

    final traco = Paint()
      ..color = cor.withValues(alpha: 0.35)
      ..strokeWidth = escala
      ..style = PaintingStyle.stroke;
    final ponto = Paint()..color = cor.withValues(alpha: 0.6);
    canvas
      ..drawPath(
          linha([
            [-5, 30],
            [60, 30],
            [75, 15],
            [130, 15]
          ]),
          traco)
      ..drawPath(
          linha([
            [-5, 92],
            [40, 92],
            [58, 74],
            [110, 74],
            [124, 60],
            [210, 60]
          ]),
          traco)
      ..drawPath(
          linha([
            [150, -5],
            [150, 22],
            [168, 40],
            [168, 130]
          ]),
          traco)
      ..drawCircle(o(130, 15), 2.2 * escala, ponto)
      ..drawCircle(o(110, 74), 2.2 * escala, ponto)
      ..drawCircle(o(168, 40), 2.2 * escala, ponto);
  }

  @override
  bool shouldRepaint(_Trilhas old) => old.cor != cor;
}

/// Ícone do app pela chave que vem da API (o painel nunca manda nome de
/// ícone solto). Chave desconhecida mostra um ícone neutro.
IconData iconePorChave(String? chave) => switch (chave) {
      // Áreas de Serviços.
      'rh' => Icons.badge_outlined,
      'operacional' => Icons.local_police_outlined,
      'normas' => Icons.gavel_rounded,
      // O protótipo usa `monitoring` dos Material Symbols, que não existe no
      // conjunto do Flutter; `analytics` é o mesmo desenho de barras.
      'gestao' => Icons.analytics_outlined,
      'atendimento' => Icons.support_agent_outlined,
      'institucional' => Icons.account_balance_outlined,
      // Funções.
      'pessoa' => Icons.person_outline_rounded,
      'certidao' => Icons.verified_outlined,
      'contracheque' => Icons.receipt_long_outlined,
      'grafico' => Icons.insights_outlined,
      'ferias' => Icons.beach_access_outlined,
      'declaracao' => Icons.request_quote_outlined,
      'tempo' => Icons.hourglass_top_rounded,
      'carreira' => Icons.timeline_rounded,
      'documento' => Icons.folder_open_rounded,
      'validar' => Icons.qr_code_scanner_rounded,
      'escala' => Icons.calendar_month_outlined,
      'escudo' => Icons.shield_outlined,
      'svi' => Icons.more_time_rounded,
      'lei' => Icons.menu_book_outlined,
      'pop' => Icons.rule_rounded,
      'efetivo' => Icons.groups_2_outlined,
      'boletim' => Icons.newspaper_rounded,
      'patrimonio' => Icons.inventory_2_outlined,
      'ajuda' => Icons.help_outline_rounded,
      'feedback' => Icons.lightbulb_outline_rounded,
      'chamado' => Icons.confirmation_number_outlined,
      'comunicado' => Icons.campaign_outlined,
      'noticia' => Icons.newspaper_outlined,
      'aviso' => Icons.notifications_outlined,
      'config' => Icons.settings_outlined,
      'email' => Icons.mail_outline_rounded,
      'senha' => Icons.lock_reset_rounded,
      'biometria' => Icons.face_rounded,
      'notificacao' => Icons.notifications_outlined,
      'tema' => Icons.palette_outlined,
      // Assuntos do "Preciso de ajuda" (protótipo `AJ`).
      'chave' => Icons.key_rounded,
      'erro' => Icons.bug_report_outlined,
      _ => Icons.apps_rounded,
    };

/// Card de resumo com a arte cheia (protótipo `.card.arte-card`): raio 18,
/// borda branca de 10%, sombra embaixo e 14 de respiro. O conteúdo é
/// desenhado com o tema escuro, porque o fundo é sempre escuro: assim os
/// cabeçalhos, números e o azul de destaque das peças dos cards ficam
/// legíveis nos dois temas sem cada card trocar cor à mão.
class CartaoArte extends StatelessWidget {
  const CartaoArte({
    super.key,
    required this.arte,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.raio = 18,
    this.temaEscuro,
  });

  final Arte arte;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double raio;

  /// O tema escuro do app (com a cor de gestor, se for o caso). Nulo: só
  /// força o brilho escuro no tema atual.
  final ThemeData? temaEscuro;

  @override
  Widget build(BuildContext context) {
    final escuro = temaEscuro ?? temaSobreArte(Theme.of(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(raio),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .6),
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -14,
          ),
        ],
      ),
      child: FundoArte(
        arte: arte,
        raio: raio,
        child: Theme(
          data: escuro,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(raio),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(raio),
                    border: Border.all(color: Colors.white.withValues(alpha: .10)),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Topo das telas de função (padrão 2.2): o cartão com a arte cheia da área
/// (degradê, brilho, trilhas e ícones apagados), com o ícone num quadrado de
/// vidro, o título e uma linha de apoio. É o mesmo desenho do cartão da área
/// em Serviços, para a tela continuar a área de onde o militar veio.
/// [child] entra abaixo do texto (números, selos); [direita], ao lado do
/// título.
class TopoArte extends StatelessWidget {
  const TopoArte({
    super.key,
    required this.arte,
    required this.icone,
    required this.titulo,
    this.subtitulo,
    this.direita,
    this.child,
    this.margem = const EdgeInsets.fromLTRB(16, 8, 16, 12),
  });

  final Arte arte;
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final Widget? direita;
  final Widget? child;
  final EdgeInsetsGeometry margem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margem,
      child: Semantics(
        header: true,
        label: [titulo, if (subtitulo != null) subtitulo].join('. '),
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .45),
                offset: const Offset(0, 10),
                blurRadius: 24,
                spreadRadius: -14,
              ),
            ],
          ),
          child: FundoArte(
            arte: arte,
            raio: 20,
            child: Theme(
              data: temaSobreArte(Theme.of(context)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 104),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Icon(icone, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ExcludeSemantics(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 19, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
                                if (subtitulo != null) ...[
                                  const SizedBox(height: 3),
                                  Text(subtitulo!,
                                      style: TextStyle(
                                          fontSize: 13, height: 1.35, color: Colors.white.withValues(alpha: 0.84))),
                                ],
                              ]),
                            ),
                          ),
                          if (direita != null) ...[const SizedBox(width: 8), direita!],
                        ]),
                        if (child != null) ...[const SizedBox(height: 14), child!],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A arte em versão discreta, para superfícies de vidro (protótipo
/// `.arte-s`): um brilho de 15% da cor de destaque no canto, duas trilhas
/// finas e dois ícones grandes quase apagados. Vai como primeira camada de
/// um Stack, por baixo do conteúdo.
class ArteDiscreta extends StatelessWidget {
  const ArteDiscreta({super.key, required this.arte, this.raio = 16});

  final Arte arte;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final alfa = escuro ? .09 : .07;
    final c = arte.destaque;
    return Positioned.fill(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(raio),
            child: Stack(children: [
              // radial-gradient(80% 130% at 100% 0%, destaque .15, 0 62%)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1, -1),
                      radius: 1.0,
                      stops: const [0, .62],
                      colors: [c.withValues(alpha: .15), c.withValues(alpha: 0)],
                      transform: const _Elipse(1.3),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _TrilhasDiscretas(c.withValues(alpha: .22))),
              ),
              Positioned(
                right: -10,
                top: -6,
                child: Transform.rotate(
                  angle: -12 * 3.1415926535 / 180,
                  child: Icon(arte.icones[0], size: 92, color: c.withValues(alpha: alfa)),
                ),
              ),
              Positioned(
                right: 84,
                bottom: -12,
                child: Transform.rotate(
                  angle: 8 * 3.1415926535 / 180,
                  child: Icon(arte.icones[1], size: 42, color: c.withValues(alpha: alfa)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// As duas trilhas da arte discreta, presas à direita
/// (`preserveAspectRatio: xMaxYMid slice`).
class _TrilhasDiscretas extends CustomPainter {
  _TrilhasDiscretas(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    final escala = s.height / 120;
    final dx = s.width - 200 * escala;
    Offset o(double x, double y) => Offset(dx + x * escala, y * escala);
    final traco = Paint()
      ..color = cor
      ..strokeWidth = escala
      ..style = PaintingStyle.stroke;
    final ponto = Paint()..color = cor;
    Path p(List<List<double>> pts) {
      final path = Path()..moveTo(o(pts[0][0], pts[0][1]).dx, o(pts[0][0], pts[0][1]).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(o(q[0], q[1]).dx, o(q[0], q[1]).dy);
      }
      return path;
    }

    canvas
      ..drawPath(
          p([
            [60, 22],
            [120, 22],
            [134, 8],
            [210, 8]
          ]),
          traco)
      ..drawPath(
          p([
            [90, 98],
            [140, 98],
            [156, 82],
            [210, 82]
          ]),
          traco)
      ..drawCircle(o(60, 22), 2 * escala, ponto)
      ..drawCircle(o(90, 98), 2 * escala, ponto);
  }

  @override
  bool shouldRepaint(_TrilhasDiscretas old) => old.cor != cor;
}

/// Cabeçalho de seção da Início (protótipo `.sec-cab`): título de 20,
/// pílula com o contador e "Ver todos" na cor de ação.
class CabecalhoSecao extends StatelessWidget {
  const CabecalhoSecao({
    super.key,
    required this.titulo,
    this.pilula,
    this.corPilula,
    this.verTodos,
    this.textoVer = 'Ver todos',
    this.direita,
  });

  final String titulo;
  final String? pilula;

  /// Cor da pílula; nula = a primária do tema.
  final Color? corPilula;
  final VoidCallback? verTodos;
  final String textoVer;

  /// No lugar do "Ver todos" (ex.: "Editar" dos atalhos).
  final Widget? direita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = corPilula ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
      child: SizedBox(
        height: 36,
        child: Row(children: [
          // Título e pílula ocupam o que precisam; o "Ver todos" fica com o
          // resto (com Spacer + Flexible o título levava só metade).
          Expanded(
            child: Row(children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: theme.colorScheme.onSurface)),
                ),
              ),
              if (pilula != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: .12),
                    border: Border.all(color: cor.withValues(alpha: .30)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(pilula!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cor)),
                ),
              ],
            ]),
          ),
          if (direita != null)
            direita!
          else if (verTodos != null)
            TextButton(
              onPressed: verTodos,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 8),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(textoVer,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.primary),
              ]),
            ),
        ]),
      ),
    );
  }
}
