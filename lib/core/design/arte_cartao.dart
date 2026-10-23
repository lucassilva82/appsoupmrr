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
    'task_alt': Icons.task_alt, 'favorite': Icons.favorite_outline, 'volunteer_activism': Icons.volunteer_activism_outlined,
    'health_and_safety': Icons.health_and_safety_outlined, 'badge': Icons.badge_outlined, 'verified': Icons.verified_outlined,
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
  };
}

/// Ícone do catálogo do painel pelo nome ('campaign', 'local_police'...).
IconData? iconePorNome(String? nome) => Arte._iconesPorNome[nome];

/// Fundo com a arte no estilo cheio. O conteúdo vai por cima, sobre um véu
/// escuro embaixo que garante texto branco legível (4,5:1) nos dois temas.
class FundoArte extends StatelessWidget {
  const FundoArte({
    super.key,
    required this.arte,
    required this.child,
    this.raio = 18,
    this.tamanhoIcone = 96,
  });

  final Arte arte;
  final Widget child;
  final double raio;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [arte.base, arte.meio],
          ),
        ),
        child: Stack(
          children: [
            // Brilho da cor de destaque no canto.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.1, -1.1),
                    radius: 1.1,
                    colors: [
                      arte.destaque.withValues(alpha: 0.35),
                      arte.destaque.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _Trilhas(arte.destaque)),
            ),
            // Três ícones grandes e apagados no canto direito.
            Positioned(
              right: -tamanhoIcone * 0.18,
              top: -tamanhoIcone * 0.12,
              child: Transform.rotate(
                angle: -0.22,
                child: Icon(arte.icones[0],
                    size: tamanhoIcone,
                    color: Colors.white.withValues(alpha: 0.16)),
              ),
            ),
            Positioned(
              right: tamanhoIcone * 0.62,
              top: tamanhoIcone * 0.12,
              child: Icon(arte.icones[1],
                  size: tamanhoIcone * 0.42,
                  color: Colors.white.withValues(alpha: 0.11)),
            ),
            Positioned(
              right: tamanhoIcone * 0.08,
              top: tamanhoIcone * 0.78,
              child: Icon(arte.icones[2],
                  size: tamanhoIcone * 0.36,
                  color: Colors.white.withValues(alpha: 0.10)),
            ),
            // Véu escuro embaixo, para o texto.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Color(0x00000000), Color(0x8C000000)],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Duas trilhas de circuito finas, com um ponto na ponta.
class _Trilhas extends CustomPainter {
  _Trilhas(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = cor.withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final ponto = Paint()..color = cor.withValues(alpha: 0.5);
    final a = Path()
      ..moveTo(0, s.height * 0.30)
      ..lineTo(s.width * 0.22, s.height * 0.30)
      ..lineTo(s.width * 0.30, s.height * 0.18)
      ..lineTo(s.width * 0.46, s.height * 0.18);
    final b = Path()
      ..moveTo(s.width, s.height * 0.72)
      ..lineTo(s.width * 0.80, s.height * 0.72)
      ..lineTo(s.width * 0.72, s.height * 0.86)
      ..lineTo(s.width * 0.58, s.height * 0.86);
    canvas
      ..drawPath(a, p)
      ..drawPath(b, p)
      ..drawCircle(Offset(s.width * 0.46, s.height * 0.18), 2.4, ponto)
      ..drawCircle(Offset(s.width * 0.58, s.height * 0.86), 2.4, ponto);
  }

  @override
  bool shouldRepaint(_Trilhas old) => old.cor != cor;
}

/// Ícone do app pela chave que vem da API (o painel nunca manda nome de
/// ícone solto). Chave desconhecida mostra um ícone neutro.
IconData iconePorChave(String? chave) => switch (chave) {
      'pessoa' => Icons.badge_outlined,
      'certidao' => Icons.edit_document,
      'contracheque' => Icons.request_quote_outlined,
      'grafico' => Icons.insights_outlined,
      'ferias' => Icons.beach_access_outlined,
      'declaracao' => Icons.description_outlined,
      'tempo' => Icons.hourglass_bottom_rounded,
      'carreira' => Icons.timeline_rounded,
      'documento' => Icons.folder_open_rounded,
      'validar' => Icons.qr_code_scanner_rounded,
      'escala' => Icons.calendar_month_outlined,
      'svi' => Icons.more_time_rounded,
      'lei' => Icons.library_books_outlined,
      'pop' => Icons.gavel_rounded,
      'efetivo' => Icons.groups_2_outlined,
      'ajuda' => Icons.help_outline_rounded,
      'feedback' => Icons.lightbulb_outline_rounded,
      'chamado' => Icons.support_agent_outlined,
      'aviso' => Icons.notifications_outlined,
      'config' => Icons.settings_outlined,
      _ => Icons.apps_rounded,
    };
