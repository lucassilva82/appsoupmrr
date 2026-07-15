import 'package:flutter/material.dart';

import '../models/svi_model.dart';
import '../services/escala_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
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
    );
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
        color: AppColors.blue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: const [_SviEmptyView()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.blue,
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE8EFFA),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
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
                      color: AppColors.blue.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dia,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.blue,
                          ),
                        ),
                        Text(
                          mes,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue.withOpacity(0.7),
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
                              _chip(escala.comandoSigla, AppColors.blue),
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
            size: 13, color: theme.colorScheme.onSurface.withOpacity(0.45)),
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

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar candidatura'),
        content: Text(
          'Confirma candidatura para '
          '${descricao.isNotEmpty ? '$descricao ' : ''}'
          'em ${escala.dataEscala}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
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

  Future<void> _mostrarSucesso(String mensagem) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x1A059669),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF059669), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escalado com sucesso!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(mensagem)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final escala = widget.escala;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      escala.titulo.isNotEmpty
                          ? escala.titulo
                          : escala.tipoServico,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _linha(
                        theme, Icons.event_rounded, 'Data', escala.dataEscala),
                    _linha(theme, Icons.schedule_rounded, 'Horário',
                        '${escala.horarioInicioFmt} – ${escala.horarioFimFmt}'),
                    if (escala.localAssuncao.isNotEmpty)
                      _linha(theme, Icons.place_rounded, 'Local',
                          escala.localAssuncao),
                    if (escala.comandoSigla.isNotEmpty)
                      _linha(theme, Icons.shield_rounded, 'Comando',
                          escala.comandoSigla),
                    if (escala.prazoVoluntarios != null)
                      _linha(
                          theme,
                          Icons.hourglass_bottom_rounded,
                          'Prazo p/ candidatura',
                          _fmtPrazo(escala.prazoVoluntarios!)),
                    const SizedBox(height: 20),
                    _buildAcao(theme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          child: CircularProgressIndicator(color: AppColors.blue),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: baseColor.withOpacity(0.2)),
        ),
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
            if (slot.postoPermitido != null && slot.postoPermitido!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Posto/graduação: ${slot.postoPermitido}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45)),
                ),
              ),
            if (slot.quadroPermitido != null &&
                slot.quadroPermitido!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Quadro: ${slot.quadroPermitido}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45)),
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
    );
  }

  Widget _botaoQuero(
      {required bool enviando, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_enviandoSlotIndex != null) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF059669).withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: enviando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.volunteer_activism_rounded, size: 18),
        label: Text(
          enviando ? 'Enviando...' : 'Quero este serviço',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _avisoBox(IconData icon, String texto, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
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
          Icon(icon, size: 18, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
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
    return const Center(
      child: CircularProgressIndicator(color: AppColors.blue),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SviEmptyView extends StatelessWidget {
  const _SviEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 120, left: 32, right: 32),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded,
              size: 64, color: theme.colorScheme.onSurface.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma vaga SVI disponível',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando o gestor publicar escalas com vagas compatíveis com sua '
            'graduação, elas aparecerão aqui.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55)),
          ),
        ],
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
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 100, left: 32, right: 32),
        children: [
          Icon(Icons.assignment_late_rounded,
              size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Adesão SVI necessária',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            mensagem ??
                'Você não possui adesão SVI ativa. Assine o termo de adesão '
                    'para poder se candidatar às vagas.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: onAderir,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: const Text('Aderir ao SVI'),
            ),
          ),
        ],
      ),
    );
  }
}
