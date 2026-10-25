import 'package:flutter/material.dart';

import '../models/svi_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';
import '../widgets/alerta.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../core/design/arte_cartao.dart';
import '../core/design/folha_arte.dart';
import '../widgets/aviso_rapido.dart';

// ── Vagas SVI ─────────────────────────────────────────────────────────────────
/// Lista de escalas SVI com vagas disponíveis para o militar se candidatar.
/// Alimentada por GET /svi/escalas-disponiveis. Toda validação é server-side.
class SviEscalasPage extends StatefulWidget {
  const SviEscalasPage({Key? key}) : super(key: key);

  @override
  State<SviEscalasPage> createState() => _SviEscalasPageState();
}

class _SviEscalasPageState extends State<SviEscalasPage> {
  final EscalaService _service = EscalaService();

  bool _loading = true;
  String? _error;
  SviEscalasDisponiveisResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getSviEscalasDisponiveis();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as vagas SVI.';
        _loading = false;
      });
    }
  }

  // ── Candidatura ─────────────────────────────────────────────────────────────
  Future<void> _abrirEscala(SviEscalaDisponivelModel escala) async {
    final candidatou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SviEscalaDetalheSheet(
        escala: escala,
        onLoadSlots: () => _service.getSviEscalaSlots(escala.id),
        onCandidatar: _candidatar,
      ),
    );
    if (candidatou == true) {
      _load();
    }
  }

  /// Envia POST /svi/auto-escalar. Retorna a mensagem de sucesso, ou lança
  /// [EscalaServiceException] com a mensagem de bloqueio (server-side).
  Future<String> _candidatar(
      SviEscalaDisponivelModel escala, SviSlotModel slot) {
    return _service.autoEscalarSvi(
      escalaId: escala.id,
      guarnicaoId: slot.guarnicaoId,
      funcaoId: slot.funcaoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FundoSuave(
        child: Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: const FundoBarraVidro(),
        title: const Text(
          'Vagas SVI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Meus Voluntários',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.SVI_MEUS_VOLUNTARIOS),
          ),
        ],
      ),
      body: _buildBody(theme, isDark),
    ));
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) return const _SviLoadingView();

    if (_error != null) {
      return _SviErrorView(message: _error!, onRetry: _load);
    }

    final result = _result;
    if (result == null) {
      return _SviErrorView(
        message: 'Não foi possível carregar as vagas SVI.',
        onRetry: _load,
      );
    }

    if (!result.temAdesao) {
      return _SviSemAdesaoView(
        mensagem: result.mensagem,
        onAderir: () => Navigator.of(context).pushNamed(AppRoutes.ESCALAS),
        onRefresh: _load,
      );
    }

    if (result.escalas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: const [_SviEmptyView()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: result.escalas.length,
        itemBuilder: (ctx, i) {
          final escala = result.escalas[i];
          return _SviEscalaCard(
            escala: escala,
            isDark: isDark,
            theme: theme,
            index: i,
            onTap: () => _abrirEscala(escala),
          );
        },
      ),
    );
  }
}

// ── Card de escala disponível ─────────────────────────────────────────────────
class _SviEscalaCard extends StatelessWidget {
  final SviEscalaDisponivelModel escala;
  final bool isDark;
  final ThemeData theme;
  final int index;
  final VoidCallback onTap;

  const _SviEscalaCard({
    required this.escala,
    required this.isDark,
    required this.theme,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (dia, mes) = _diaMes(escala.dataInicio, escala.dataEscala);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CartaoVidro(
          onTap: onTap,
          arte: Arte.de('operacional'),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Data
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dia,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          mes,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.75),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Conteúdo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                escala.titulo.isNotEmpty
                                    ? escala.titulo
                                    : escala.tipoServico,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (escala.comandoSigla.isNotEmpty)
                              _chip(escala.comandoSigla,
                                  theme.colorScheme.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _infoLine(
                          Icons.schedule_rounded,
                          '${escala.horarioInicioFmt} – ${escala.horarioFimFmt}',
                        ),
                        if (escala.localAssuncao.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _infoLine(Icons.place_rounded, escala.localAssuncao),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statusRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusRow() {
    final badges = <Widget>[];

    if (escala.jaEscalado) {
      badges.add(_statusBadge(
        Icons.check_circle_rounded,
        'Você já está nesta escala',
        Colors.blueGrey,
      ));
    } else if (escala.prazoEncerrado) {
      badges.add(_statusBadge(
        Icons.timer_off_rounded,
        'Prazo encerrado',
        Colors.redAccent,
      ));
    } else if (escala.semVagas) {
      badges.add(_statusBadge(
        Icons.event_busy_rounded,
        'Vagas preenchidas',
        Colors.orange,
      ));
    } else {
      badges.add(_statusBadge(
        Icons.how_to_reg_rounded,
        escala.slotsDisponiveis == 1
            ? '1 vaga'
            : '${escala.slotsDisponiveis} vagas',
        const Color(0xFF059669),
      ));
    }

    if (!escala.jaEscalado &&
        !escala.prazoEncerrado &&
        escala.prazoVoluntarios != null) {
      badges.add(_prazoBadge(escala.prazoVoluntarios!));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: badges);
  }

  Widget _statusBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prazoBadge(DateTime prazo) {
    final falta = prazo.difference(DateTime.now());
    String txt;
    if (falta.inDays >= 1) {
      txt = 'Prazo: ${falta.inDays}d';
    } else if (falta.inHours >= 1) {
      txt = 'Prazo: ${falta.inHours}h';
    } else {
      txt = 'Prazo: ${falta.inMinutes.clamp(0, 59)}min';
    }
    return _statusBadge(
        Icons.hourglass_bottom_rounded, txt, Colors.amber.shade800);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon,
            size: 13, color: theme.colorScheme.onSurface.withOpacity(0.70)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

(String, String) _diaMes(String iso, String br) {
  const meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  DateTime? dt = DateTime.tryParse(iso);
  if (dt == null && br.contains('/')) {
    final p = br.split('/');
    if (p.length == 3) {
      dt = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }
  }
  if (dt == null) return ('--', '');
  return (dt.day.toString().padLeft(2, '0'), meses[dt.month - 1]);
}

// ── Bottom sheet: detalhe da escala + slots + candidatura ─────────────────────
class _SviEscalaDetalheSheet extends StatefulWidget {
  final SviEscalaDisponivelModel escala;
  final Future<SviEscalaSlotsResult> Function() onLoadSlots;
  final Future<String> Function(
      SviEscalaDisponivelModel escala, SviSlotModel slot) onCandidatar;

  const _SviEscalaDetalheSheet({
    required this.escala,
    required this.onLoadSlots,
    required this.onCandidatar,
  });

  @override
  State<_SviEscalaDetalheSheet> createState() => _SviEscalaDetalheSheetState();
}

class _SviEscalaDetalheSheetState extends State<_SviEscalaDetalheSheet> {
  int? _enviandoSlotIndex;

  bool _loadingSlots = true;
  String? _slotsError;
  SviEscalaSlotsResult? _slotsResult;

  @override
  void initState() {
    super.initState();
    _carregarSlots();
  }

  Future<void> _carregarSlots() async {
    if (!mounted) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final result = await widget.onLoadSlots();
      if (!mounted) return;
      setState(() {
        _slotsResult = result;
        _loadingSlots = false;
      });
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _slotsError = e.message;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slotsError = 'Não foi possível carregar as vagas desta escala.';
        _loadingSlots = false;
      });
    }
  }

  Future<void> _confirmarCandidatura(SviSlotModel slot, int index) async {
    final escala = widget.escala;
    final descricao = [
      if (slot.funcaoNome.isNotEmpty) slot.funcaoNome,
      if (slot.guarnicaoNome.isNotEmpty) slot.guarnicaoNome,
    ].join(' · ');

    final confirmar = await dialogoConfirmacao(
      context,
      titulo: 'Confirmar candidatura',
      mensagem: 'Confirma candidatura para '
          '${descricao.isNotEmpty ? '$descricao ' : ''}'
          'em ${escala.dataEscala}?',
      textoConfirmar: 'Confirmar',
      icone: Icons.volunteer_activism_rounded,
      cor: AppColors.acao,
      arte: Arte.de('operacional'),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _enviandoSlotIndex = index);
    try {
      final mensagem = await widget.onCandidatar(escala, slot);
      if (!mounted) return;
      await _mostrarSucesso(mensagem);
      if (mounted) Navigator.of(context).pop(true);
    } on EscalaServiceException catch (e) {
      if (!mounted) return;
      setState(() => _enviandoSlotIndex = null);
      _mostrarErro(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviandoSlotIndex = null);
      _mostrarErro('Não foi possível concluir a candidatura. Tente novamente.');
    }
  }

  Future<void> _mostrarSucesso(String mensagem) => alertaSucesso(
        context,
        titulo: 'Escalado com sucesso!',
        texto: mensagem,
        confirmar: 'Fechar',
        arte: Arte.de('operacional'),
      );

  void _mostrarErro(String mensagem) {
    avisoErro(context, 'Não foi possível concluir', texto: mensagem);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final escala = widget.escala;

    // Folha do padrão 2.2 (FolhaArte, arte operacional): o corpo rola
    // sozinho quando passa da altura.
    return FolhaArte(
      arte: Arte.de('operacional'),
      icone: Icons.more_time_rounded,
      titulo: escala.titulo.isNotEmpty ? escala.titulo : escala.tipoServico,
      subtitulo: 'Serviço voluntário (SVI)',
      paddingCorpo: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _linha(theme, Icons.event_rounded, 'Data', escala.dataEscala),
          _linha(theme, Icons.schedule_rounded, 'Horário',
              '${escala.horarioInicioFmt} – ${escala.horarioFimFmt}'),
          if (escala.localAssuncao.isNotEmpty)
            _linha(theme, Icons.place_rounded, 'Local', escala.localAssuncao),
          if (escala.comandoSigla.isNotEmpty)
            _linha(theme, Icons.shield_rounded, 'Comando', escala.comandoSigla),
          if (escala.prazoVoluntarios != null)
            _linha(theme, Icons.hourglass_bottom_rounded,
                'Prazo p/ candidatura', _fmtPrazo(escala.prazoVoluntarios!)),
          const SizedBox(height: 8),
          _buildAcao(theme),
        ],
      ),
    );
  }

  Widget _buildAcao(ThemeData theme) {
    final escala = widget.escala;

    if (escala.jaEscalado) {
      return _avisoBox(
        Icons.check_circle_rounded,
        'Você já está escalado neste serviço.',
        Colors.blueGrey,
      );
    }
    if (escala.prazoEncerrado) {
      return _avisoBox(
        Icons.timer_off_rounded,
        'O prazo para candidatura já encerrou.',
        Colors.redAccent,
      );
    }

    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_slotsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _avisoBox(
            Icons.error_outline_rounded,
            _slotsError!,
            Colors.redAccent,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _carregarSlots,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    final result = _slotsResult;
    final slots = result?.slots ?? const <SviSlotModel>[];

    // Escala não está aberta para voluntários.
    if (result != null && !result.aberta) {
      return _avisoBox(
        Icons.lock_clock_rounded,
        result.mensagem ??
            'Esta escala não está aberta para voluntários no momento.',
        Colors.orange,
      );
    }

    // Sem adesão SVI ativa.
    if (result != null && !result.temAdesao) {
      return _avisoBox(
        Icons.assignment_late_rounded,
        result.mensagem ??
            'Você não possui adesão SVI ativa. Assine o termo de adesão primeiro.',
        Colors.orange,
      );
    }

    if (slots.isEmpty) {
      return _avisoBox(
        Icons.event_busy_rounded,
        'Nenhuma vaga compatível com sua graduação nesta escala.',
        Colors.orange,
      );
    }

    final disponiveis = slots.where((s) => s.disponivel).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Vagas',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              disponiveis == 0
                  ? 'Sem vagas disponíveis'
                  : (disponiveis == 1
                      ? '1 disponível'
                      : '$disponiveis disponíveis'),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    disponiveis == 0 ? Colors.orange : const Color(0xFF059669),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < slots.length; i++) _slotTile(theme, slots[i], i),
      ],
    );
  }

  Widget _slotTile(ThemeData theme, SviSlotModel slot, int index) {
    final enviando = _enviandoSlotIndex == index;
    final indisponivel = !slot.disponivel;
    final baseColor =
        indisponivel ? theme.colorScheme.onSurface : theme.colorScheme.primary;

    return Opacity(
      opacity: indisponivel ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CartaoVidro(
          raio: 14,
          tingimento: indisponivel ? null : baseColor,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slot.funcaoNome.isNotEmpty)
                Text(
                  slot.funcaoNome,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              if (slot.guarnicaoNome.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    slot.guarnicaoNome,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ),
              if (slot.postoPermitido != null &&
                  slot.postoPermitido!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Posto/graduação: ${slot.postoPermitido}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.70)),
                  ),
                ),
              if (slot.quadroPermitido != null &&
                  slot.quadroPermitido!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Quadro: ${slot.quadroPermitido}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.70)),
                  ),
                ),
              const SizedBox(height: 12),
              if (indisponivel)
                _avisoBox(
                  Icons.block_rounded,
                  slot.motivoIndisponivel ?? 'Vaga indisponível.',
                  Colors.orange,
                )
              else
                _botaoQuero(
                  enviando: enviando,
                  onPressed: () => _confirmarCandidatura(slot, index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoQuero(
      {required bool enviando, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_enviandoSlotIndex != null) ? null : onPressed,
        icon: enviando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.volunteer_activism_rounded,
                size: AppIconSize.sm),
        label: Text(enviando ? 'Enviando...' : 'Quero este serviço'),
      ),
    );
  }

  Widget _avisoBox(IconData icon, String texto, Color color) {
    return CartaoVidro(
      raio: 12,
      tingimento: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.sm, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.70)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPrazo(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} às ${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ── Estados auxiliares ────────────────────────────────────────────────────────
class _SviLoadingView extends StatelessWidget {
  const _SviLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Estado vazio, de erro ou de adesão no padrão 2.2: caixa de vidro com a
/// arte operacional.
class _SviCaixaEstado extends StatelessWidget {
  final IconData icone;
  final Color? corIcone;
  final String? titulo;
  final String texto;
  final Widget? acao;
  const _SviCaixaEstado(
      {required this.icone,
      this.corIcone,
      this.titulo,
      required this.texto,
      this.acao});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mudo = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return CartaoVidro(
      arte: Arte.de('operacional'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: AppIconSize.xl, color: corIcone ?? mudo),
          const SizedBox(height: 12),
          if (titulo != null) ...[
            Text(titulo!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
          ],
          Text(texto,
              textAlign: TextAlign.center,
              style: titulo == null
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyMedium?.copyWith(color: mudo)),
          if (acao != null) ...[const SizedBox(height: 20), acao!],
        ],
      ),
    );
  }
}

class _SviErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SviErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _SviCaixaEstado(
          icone: Icons.cloud_off_rounded,
          corIcone: Theme.of(context).colorScheme.error,
          texto: message,
          acao: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
            label: const Text('Tentar novamente'),
          ),
        ),
      ),
    );
  }
}

class _SviEmptyView extends StatelessWidget {
  const _SviEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: _SviCaixaEstado(
        icone: Icons.event_available_rounded,
        titulo: 'Nenhuma vaga SVI disponível',
        texto: 'Quando o gestor publicar escalas com vagas compatíveis com sua '
            'graduação, elas aparecerão aqui.',
      ),
    );
  }
}

class _SviSemAdesaoView extends StatelessWidget {
  final String? mensagem;
  final VoidCallback onAderir;
  final Future<void> Function() onRefresh;

  const _SviSemAdesaoView({
    required this.mensagem,
    required this.onAderir,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SviCaixaEstado(
            icone: Icons.assignment_late_rounded,
            titulo: 'Adesão SVI necessária',
            texto: mensagem ??
                'Você não possui adesão SVI ativa. Assine o termo de adesão '
                    'para poder se candidatar às vagas.',
            acao: ElevatedButton.icon(
              onPressed: onAderir,
              icon: const Icon(Icons.assignment_turned_in_rounded,
                  size: AppIconSize.sm),
              label: const Text('Aderir ao SVI'),
            ),
          ),
        ],
      ),
    );
  }
}
