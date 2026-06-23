import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AjudaPage — Suporte Técnico
// ─────────────────────────────────────────────────────────────────────────────

class AjudaPage extends StatefulWidget {
  const AjudaPage({Key? key}) : super(key: key);

  @override
  State<AjudaPage> createState() => _AjudaPageState();
}

class _AjudaPageState extends State<AjudaPage> {
  String _version = '—';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar expandida ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Suporte Técnico',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _AppBarBackground(),
            ),
          ),

          // ── Corpo ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AppInfoCard(version: _version, isDark: isDark, theme: theme),
                  const SizedBox(height: 24),
                  _SectionLabel('Fale Conosco', theme: theme),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactCard(
                          color: const Color(0xFF25D366),
                          icon: Image.asset(
                            'assets/imagens/whatsapp.png',
                            width: 26,
                            height: 26,
                          ),
                          label: 'WhatsApp',
                          sublabel: 'Seg–Sex, 8h–17h',
                          onTap: () => _launch(
                              'https://wa.me/5595991298238?text='
                              'Ol%C3%A1%2C+preciso+de+suporte+no+app+SouPMRR.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ContactCard(
                          color: AppColors.blue,
                          icon: const Icon(Icons.email_rounded,
                              color: Colors.white, size: 26),
                          label: 'E-mail',
                          sublabel: 'dti@pmrr.rr.gov.br',
                          onTap: () => _launch(
                              'mailto:dti@pmrr.rr.gov.br?subject=Suporte%20SouPMRR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('Informações do Sistema', theme: theme),
                  const SizedBox(height: 12),
                  _SystemInfoCard(
                      version: _version, isDark: isDark, theme: theme),
                  const SizedBox(height: 24),
                  _SectionLabel('Perguntas Frequentes', theme: theme),
                  const SizedBox(height: 12),
                  _FaqCard(isDark: isDark, theme: theme),
                  const SizedBox(height: 24),
                  _DtiCard(isDark: isDark, theme: theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App Bar Background ───────────────────────────────────────────────────────

class _AppBarBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/imagens/iconesoupm.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          size: 36,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'SouPMRR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Polícia Militar de Roraima',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card identidade do app ───────────────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  final String version;
  final bool isDark;
  final ThemeData theme;

  const _AppInfoCard(
      {required this.version, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blue.withOpacity(0.12),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/imagens/iconesoupm.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.shield_rounded, color: AppColors.blue, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SouPMRR',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Versão $version  •  Módulo 2.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 11, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'PMRR',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.blue,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de contato ──────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Color color;
  final Widget icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _ContactCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card informações do sistema ──────────────────────────────────────────────

class _SystemInfoCard extends StatelessWidget {
  final String version;
  final bool isDark;
  final ThemeData theme;

  const _SystemInfoCard(
      {required this.version, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoRow(Icons.smartphone_rounded, 'Versão do app', version),
      _InfoRow(Icons.layers_rounded, 'Módulo', '2.0 — Redesenhado'),
      _InfoRow(Icons.shield_moon_rounded, 'Plataforma',
          'Polícia Militar de Roraima'),
      _InfoRow(Icons.lock_rounded, 'Autenticação', 'JWT + Biometria'),
      _InfoRow(Icons.notifications_rounded, 'Notificações',
          'Firebase Cloud Messaging'),
      _InfoRow(Icons.cloud_done_rounded, 'Backend', 'API REST · PMRR Intranet'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(items[i].icon, size: 18, color: AppColors.blue),
                ),
                title: Text(items[i].label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: Text(
                  items[i].value,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              if (i < items.length - 1)
                Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withOpacity(0.5)),
            ],
          );
        }),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────

class _FaqCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _FaqCard({required this.isDark, required this.theme});

  static const _items = [
    _FaqItem(
      question: 'Não consigo fazer login. O que faço?',
      answer:
          'Verifique se sua matrícula e senha estão corretos. Se o problema persistir, '
          'entre em contato com o DTI para redefinição de acesso.',
    ),
    _FaqItem(
      question: 'Por que não estou recebendo notificações?',
      answer:
          'Acesse Configurações → Notificações e verifique se estão ativadas no app. '
          'Confirme também que o sistema operacional do seu dispositivo permite '
          'notificações para o SouPMRR.',
    ),
    _FaqItem(
      question: 'Minha escala não está aparecendo. Por quê?',
      answer:
          'As escalas são sincronizadas com o sistema da PMRR. Verifique sua conexão '
          'com a internet e tente atualizar a página. Se o problema persistir, '
          'entre em contato com o DTI.',
    ),
    _FaqItem(
      question: 'Como atualizo meus dados cadastrais?',
      answer:
          'Os dados cadastrais (nome, posto, unidade) são gerenciados pelo RH da sua '
          'unidade. Para atualizações, procure o setor responsável na sua OPM.',
    ),
    _FaqItem(
      question: 'O app é seguro? Meus dados estão protegidos?',
      answer:
          'Sim. O SouPMRR utiliza autenticação por token JWT, conexão criptografada '
          '(HTTPS) e não armazena senhas no dispositivo. A biometria é processada '
          'localmente, sem envio de dados biométricos ao servidor.',
    ),
    _FaqItem(
      question: 'Como funciona a biometria?',
      answer:
          'A biometria substitui a digitação da senha na tela de desbloqueio. '
          'É processada inteiramente pelo sistema operacional do dispositivo — '
          'o SouPMRR nunca tem acesso aos dados biométricos. '
          'Para ativar, acesse Configurações → Biometria.',
    ),
    _FaqItem(
      question: 'O app funciona sem internet?',
      answer:
          'A maioria das funcionalidades requer conexão para buscar dados do servidor '
          'da PMRR. Algumas informações já carregadas podem aparecer temporariamente '
          'sem conexão.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: List.generate(_items.length, (i) {
            return Column(
              children: [
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _items[i].question,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _items[i].answer,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _items.length - 1)
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.dividerColor.withOpacity(0.4)),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

// ─── Card sobre o DTI ─────────────────────────────────────────────────────────

class _DtiCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _DtiCard({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.navy.withOpacity(isDark ? 0.6 : 0.08),
            AppColors.blue.withOpacity(isDark ? 0.3 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/imagens/logo_dti.jpeg',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.computer_rounded,
                    color: AppColors.blue, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DTI — Departamento de Tecnologia da Informação',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'O SouPMRR é desenvolvido e mantido pelo DTI da PMRR. '
                  'Nosso compromisso é oferecer soluções tecnológicas seguras, '
                  'modernas e acessíveis para os militares do Estado de Roraima.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 10, color: AppColors.blue.withOpacity(0.7)),
                    const SizedBox(width: 3),
                    Text(
                      'PMRR · Boa Vista, RR',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.blue.withOpacity(0.8)),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_rounded,
                        size: 10, color: AppColors.blue.withOpacity(0.7)),
                    const SizedBox(width: 3),
                    Text(
                      '© 2025–2026',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.blue.withOpacity(0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Label de seção ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _SectionLabel(this.text, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurface.withOpacity(0.45),
      ),
    );
  }
}
