// lib/pages/militar_detalhe_full_page.dart
//
// ▸ Foto com “carimbo” anti‐cópia (login, CPF, IP, data/hora) sobreposta.
// ▸ Bloqueio de captura de tela ligado **aqui**, não no app inteiro: esta é
//   a tela com dado pessoal de terceiro. Ver lib/utils/protecao_tela.dart.
// ▸ IP público obtido na montagem via api.ipify.org.
// ▸ Restante da lógica permanece intocada.

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../models/endereco.dart';
import '../models/militar.dart';
import '../models/militar_detalhe_full.dart';
import '../models/ficha_funcional.dart';
import '../services/dados_sql.dart';
import '../widgets/cartao_painel.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/vidro.dart';
import '../widgets/dados_situacao_funcional.dart';
import '../widgets/aviso_rapido.dart';
import '../models/auth_model.dart'; // fornece auth.matricula, auth.cpf
import '../utils/app_theme.dart';
import '../utils/protecao_tela.dart';
import '../core/design/arte_cartao.dart';
import '../core/erros/falha_de.dart';
import '../core/erros/estado_erro.dart';

class MilitarDetalheFullPage extends StatefulWidget {
  final String matricula;

  /// URL da foto já resolvida vinda da tela anterior (fallback caso a API
  /// de detalhe retorne imagemurl nulo ou inválido).
  final String? preloadedImageUrl;

  const MilitarDetalheFullPage({
    Key? key,
    required this.matricula,
    this.preloadedImageUrl,
  }) : super(key: key);

  @override
  State<MilitarDetalheFullPage> createState() => _MilitarDetalheFullPageState();
}

class _MilitarDetalheFullPageState extends State<MilitarDetalheFullPage> {
  late Future<Tuple> _future; // (dados pessoais, ficha funcional)

  String _ip = '...';
  final String _dateTimeStr =
      DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    _future = _fetchTudo();
    _fetchIp();

    // Liga o bloqueio ao abrir a ficha e desliga ao sair, para o resto do
    // app continuar livre para print e gravação.
    ProtecaoTela.ligar();
  }

  @override
  void dispose() {
    ProtecaoTela.desligar();
    super.dispose();
  }

  Future<void> _fetchIp() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        setState(() => _ip = j['ip'] ?? '...');
      }
    } catch (_) {
      // se falhar mantemos "..."
    }
  }

  String? _resolveImageUrl(String? raw) {
    final value = (raw ?? '').trim().replaceAll('pmrr.net', 'pmrr.online');
    if (value.isEmpty || value.toLowerCase() == 'null') return null;

    // Placeholder legado do backend sem arquivo real.
    if (value.endsWith('/pix_db/') || value.endsWith('/pix_db')) return null;

    // Sempre forçar HTTPS (iOS bloqueia HTTP via ATS)
    if (value.startsWith('https://')) return value;
    if (value.startsWith('http://')) {
      return 'https://${value.substring(7)}';
    }
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://rh.pmrr.online$value';

    // URL sem scheme mas com domínio (ex: rh.pmrr.online/pix_db/...)
    if (value.contains('.') && value.contains('/')) {
      return 'https://$value';
    }

    // Caminho relativo sem host.
    return 'https://rh.pmrr.online/$value';
  }

  /* ---------- API 1: dados pessoais ---------- */
  Future<MilitarDetalheFull?> _fetchPessoal() async {
    final uri = Uri.parse(
        'https://pmrr.online/flutter/sigrh/buscapormatricula.php?matricula=${widget.matricula}');
    final r = await http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final Map<String, dynamic> d = jsonDecode(r.body);
    if (d['code'] == 0) return null;
    return MilitarDetalheFull.fromJson(d['result'][0]);
  }

  /* ---------- API 2: ficha funcional ---------- */
  Future<FichaFuncional?> _fetchFicha() async {
    final ds = DadosSql();
    return ds.buscarSituacaoFuncional(widget.matricula);
  }

  Future<Tuple> _fetchTudo() async {
    final pessoal = await _fetchPessoal();
    final ficha = await _fetchFicha();
    return Tuple(pessoal, ficha);
  }

  /* ---------- abrir WhatsApp ---------- */
  Future<void> _whats(String fone) async {
    final uri = Uri.parse('https://wa.me/55$fone');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<Auth>(context, listen: false); // para carimbo

    return FundoSuave(
        child: Scaffold(
      appBar: const CustomAppBar(title: 'Dados do Militar'),
      body: FutureBuilder<Tuple>(
        future: _future,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return EstadoErro(
                falha: falhaDe('MF', s.error, tela: 'gestao.mapa_forca'),
                tela: 'gestao.mapa_forca');
          }

          final tuple = s.data!;
          final m = tuple.pessoal;
          if (m == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CartaoVidro(
                  arte: Arte.de('gestao'),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: AppIconSize.xl,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text('Não possui dados.',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                // ── Header com foto ───────────────────────────────────────
                _buildHeroHeader(context, m, auth, theme, isDark),

                // O aviso fica escrito na tela porque é a única forma de o
                // militar saber da regra nos dois sistemas antes de tentar:
                // no Android quem avisa é o próprio sistema, no iOS só dá
                // para avisar depois da captura.
                const _AvisoPrintBloqueado(),

                const SizedBox(height: 12),

                // ── Telefone ──────────────────────────────────────────────
                _buildSection(
                  theme: theme,
                  isDark: isDark,
                  child: Row(
                    children: [
                      _iconBox(Icons.phone_rounded,
                          theme.colorScheme.primary, isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.telefone,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Telefone',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ligar',
                        icon: const Icon(Icons.call_rounded,
                            size: AppIconSize.md),
                        color: theme.colorScheme.primary,
                        onPressed: () => _ligar(context, m.telefone),
                        // Cor do tema (o verde fixo saiu) e alvo de 44 pt.
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary
                              .withValues(alpha: isDark ? 0.16 : 0.10),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'WhatsApp',
                        icon: Image.asset('assets/imagens/whatsapp.png',
                            width: 22, height: 22),
                        onPressed: () => _whats(m.telefone),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: isDark ? 0.08 : 0.05),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Lotação ───────────────────────────────────────────────
                _buildSection(
                  theme: theme,
                  isDark: isDark,
                  child: Column(
                    children: [
                      _infoRow(Icons.apartment_rounded, 'Unidade',
                          m.unidadeSigla, theme, isDark),
                      _divider(theme),
                      _infoRow(Icons.location_on_rounded,
                          'Subunidade / Lotação', m.subunidade, theme, isDark),
                      _divider(theme),
                      _infoRow(
                          Icons.home_rounded,
                          'Endereço',
                          '${m.rua}, Nº ${m.numero} · ${m.bairro}, ${m.municipio}',
                          theme,
                          isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Ficha Funcional ───────────────────────────────────────
                if (tuple.ficha != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DadosSituacaoFuncional(
                      militar: MilitarMock(tuple.ficha!),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ));
  }

  /* formata data do banco (YYYY-MM-DD) para padrão brasileiro */
  String _fmtDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw.trim()));
    } catch (_) {
      return raw;
    }
  }

  /* ligar via discador nativo */
  Future<void> _ligar(BuildContext context, String fone) async {
    final clean = fone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      avisoErro(context, 'Não foi possível abrir o discador');
    }
  }

  /* ── Widgets auxiliares 2.0 ─────────────────────────────────────────────── */

  Widget _buildHeroHeader(BuildContext context, MilitarDetalheFull m, Auth auth,
      ThemeData theme, bool isDark) {
    final imageUrl = _resolveImageUrl(m.imagemUrl) ?? widget.preloadedImageUrl;
    // Era um degradê azul sólido ocupando a largura toda — a última
    // superfície chapada desta tela, e justamente o que o DESIGN.md §1 manda
    // não fazer: a tela não pinta o próprio fundo. No padrão 2.2 o cabeçalho
    // é a arte cheia da área de Gestão, como o TopoArte das outras telas, e
    // por isso o texto branco abaixo fica legível nos dois temas.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: FundoArte(
        arte: Arte.de('gestao'),
        raio: 20,
        child: Theme(
          data: temaSobreArte(theme),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto com carimbo
                GestureDetector(
                  onTap: () => _showImageModal(context, m.imagemUrl ?? ''),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 100,
                      height: 125,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: imageUrl ?? '',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            memCacheWidth: 200,
                            placeholder: (_, __) => Container(
                                color: Colors.white.withValues(alpha: 0.1),
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(Icons.person_outline_rounded,
                                  size: AppIconSize.xl, color: Colors.white54),
                            ),
                          ),
                          IgnorePointer(
                            child: Opacity(
                              opacity: .12,
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2, mainAxisExtent: 75),
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (_, __) => Text(
                                  'Login: ${auth.matricula}\nCPF: ${auth.cpf}\nIP : $_ip\n$_dateTimeStr',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${m.postoGraduacao} • ${m.quadro}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(m.nomeCompleto,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.25)),
                      const SizedBox(height: 12),
                      _headerRow(
                          Icons.badge_rounded, 'Mat. PMRR: ${m.matricula}'),
                      const SizedBox(height: 5),
                      _headerRow(Icons.verified_user_rounded,
                          'Mat. SEGAD: ${m.matRhNova}'),
                      const SizedBox(height: 5),
                      _headerRow(Icons.credit_card_rounded, 'CPF: ${m.cpf}'),
                      const SizedBox(height: 5),
                      _headerRow(Icons.calendar_today_rounded,
                          'Incorporação: ${_fmtDate(m.incorporacao)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: AppIconSize.xxs, color: Colors.white70),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11.5, height: 1.2)),
          ),
        ],
      );

  Widget _buildSection(
      {required ThemeData theme, required bool isDark, required Widget child}) {
    // Margem 16 como o resto do app (era 12) e a superfície do app no lugar
    // do Container com cardColor, borda e sombra próprios.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CartaoVidro(
        arte: Arte.de('gestao'),
        raio: 16,
        padding: kPaddingCartao,
        child: child,
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _iconBox(icon, theme.colorScheme.primary, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ícone de linha, sem o quadrado tingido que havia atrás.
  ///
  /// O quadrado era uma segunda superfície dentro de um card que já é
  /// superfície — o empilhamento de tons do DESIGN.md §3b. Sem ele a linha
  /// fica mais leve e o dado, que é o que importa, ganha o peso.
  Widget _iconBox(IconData icon, Color color, bool isDark) => SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: AppIconSize.sm, color: color),
      );

  Widget _divider(ThemeData theme) => Divider(
        height: 1,
        indent: 48,
        color: theme.dividerColor.withValues(alpha: 0.25),
      );

  /* ---------- Exibir imagem em tela cheia ---------- */
  void _showImageModal(BuildContext context, String urlImage) {
    // Obtenha os dados do usuário para o carimbo
    final auth = Provider.of<Auth>(context, listen: false);
    final String ipText = _ip;
    final String dateTimeText = _dateTimeStr;
    final resolvedUrl = _resolveImageUrl(urlImage);

    showGeneralDialog(
      context: context,
      barrierLabel: "Exibir Imagem",
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width * 0.7,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem com CachedNetworkImage, exibindo CircularProgressIndicator como placeholder
                  FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          child: resolvedUrl == null
                              ? Image.asset(
                                  'assets/imagens/avatar2.jpg',
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: resolvedUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                    'assets/imagens/avatar2.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Sobreposição com o "carimbo" de proteção
                  IgnorePointer(
                    child: Opacity(
                      opacity: .12,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 75,
                        ),
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) => Text(
                          'Login: ${auth.matricula}\nCPF: ${auth.cpf}\nIP : $ipText\n$dateTimeText',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Botão de fechar no canto superior direito
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      tooltip: 'Fechar',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: AppIconSize.md,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
    );
  }
}

/* ---------------------- helpers ---------------------- */

class Tuple {
  final MilitarDetalheFull? pessoal;
  final FichaFuncional? ficha;
  Tuple(this.pessoal, this.ficha);
}

class MilitarMock extends Militar {
  MilitarMock(FichaFuncional ficha)
      : super(
          qra: '',
          matRhNova: '',
          cpf: '',
          grupo: '',
          nivel: '',
          idPosto: '',
          endereco: Endereco(
            Municipio(id: '', nome: ''),
            Bairro(id: '', nome: ''),
            Rua(id: '', nome: ''),
            '',
            '',
          ),
          matricula: '',
          nomeCompleto: '',
          postoGraduacao: '',
          quadro: '',
          subUnidade: '',
          dataIncorporacao: '',
          imageUrl: '',
          fichaFuncional: ficha,
        );
}

/// Faixa que informa o bloqueio de captura na ficha do militar.
class _AvisoPrintBloqueado extends StatelessWidget {
  const _AvisoPrintBloqueado({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const cor = Color(0xFFC77800);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CartaoVidro(
        raio: 12,
        tingimento: cor,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          const Icon(Icons.no_photography_outlined,
              size: AppIconSize.sm, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ProtecaoTela.aviso,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.85),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
