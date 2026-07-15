import 'package:flutter/material.dart';

import '../models/escala_model.dart';
import '../services/escala_service.dart';
import '../utils/app_theme.dart';

// ── EscalaDetalhePage ─────────────────────────────────────────────────────────
class EscalaDetalhePage extends StatefulWidget {
  const EscalaDetalhePage({Key? key}) : super(key: key);

  @override
  State<EscalaDetalhePage> createState() => _EscalaDetalhePageState();
}

class _EscalaDetalhePageState extends State<EscalaDetalhePage> {
  EscalaService? _service;
  int? _escalaId;

  EscalaModel? _escala;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  void _logUi(String message) {
    debugPrint('[EscalaDetalhePage] $message');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_escalaId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _escalaId = args?['escalaId'] as int?;
      _service = args?['service'] as EscalaService?;
      _service ??= EscalaService();
      // Escala já carregada na listagem: usamos como dado inicial para a tela
      // renderizar imediatamente, mesmo que o refresh via /escala/{id} falhe.
      final escalaArg = args?['escala'];
      if (escalaArg is EscalaModel) {
        _escala = escalaArg;
        _escalaId ??= escalaArg.escalaId;
        _loading = false;
      }
      _logUi(
          'didChangeDependencies escalaId=$_escalaId temFallback=${_escala != null}');
      _load();
    }
  }

  Future<void> _load() async {
    if (_escalaId == null) return;
    _logUi('load start escalaId=$_escalaId');
    // Só mostra o spinner de tela cheia se ainda não temos nenhum dado.
    if (_escala == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final escala = await _service!.getEscalaDetalhe(_escalaId!);
      _logUi(
          'load success escalaStatus=${escala.escalaStatus} temCiencia=${escala.temCiencia}');
      if (!mounted) return;
      setState(() {
        _escala = escala;
        _loading = false;
        _error = null;
      });
    } on EscalaServiceException catch (e) {
      _logUi('load falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Se já temos a escala vinda da listagem, mantemos exibindo e não
        // bloqueamos a tela — o usuário ainda consegue dar ciência.
        _error = _escala != null ? null : e.message;
      });
    } catch (_) {
      _logUi('load erro inesperado');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _escala != null
            ? null
            : 'Erro ao carregar detalhes. Verifique sua conexão.';
      });
    }
  }

  // ── Dar Ciência ─────────────────────────────────────────────────────────────
  Future<void> _darCiencia() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 10),
            Text('Confirmar Ciência'),
          ],
        ),
        content: const Text(
            'Ao confirmar, você declara que tomou conhecimento desta escala de serviço.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _actionLoading = true);

    try {
      _logUi('darCiencia start escalaId=$_escalaId');
      final result = await _service!.registrarCiencia(_escalaId!);
      if (!mounted) return;
      setState(() {
        _escala!.temCiencia = true;
        _escala!.cienciaEmBr = result['ciencia_em']?.toString();
        _actionLoading = false;
      });
      _logUi('darCiencia success cienciaEm=${result['ciencia_em']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Ciência registrada com sucesso!'),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on EscalaServiceException catch (e) {
      _logUi('darCiencia falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Impossibilidade ─────────────────────────────────────────────────────────
  Future<void> _declararImpossibilidade() async {
    List<EscalaImpossibilidadeTipo> tipos = [];
    try {
      tipos = await _service!.getTiposImpossibilidade();
    } catch (_) {}
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImpossibilidadeSheet(tipos: tipos),
    );
    if (result == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      _logUi(
          'impossibilidade start escalaId=$_escalaId tipo=${result['tipo_id']}');
      await _service!.registrarImpossibilidade(
        _escalaId!,
        result['tipo_id'] as int,
        result['observacao'] as String?,
      );
      if (!mounted) return;
      setState(() {
        _escala!.temImpossibilidade = true;
        _actionLoading = false;
      });
      _logUi('impossibilidade success');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.info_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Impossibilidade registrada.'),
          ]),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on EscalaServiceException catch (e) {
      _logUi('impossibilidade falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        title: const Text(
          'Detalhe da Escala',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _loading
          ? const _LoadingBody()
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _buildContent(theme, isDark),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    final e = _escala!;
    final status = e.statusVisual;
    final (statusLabel, statusColor, statusIcon) = _statusVisualInfo(status);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Banner ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: statusColor.withOpacity(0.35), width: 1),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
                if (e.temCiencia && e.cienciaEmBr != null) ...[
                  const Spacer(),
                  Text(
                    'em ${e.cienciaEmBr}',
                    style: TextStyle(
                        fontSize: 11, color: statusColor.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Bloco principal ───────────────────────────────────────
          _Section(
            isDark: isDark,
            theme: theme,
            icon: Icons.shield_rounded,
            title: 'Dados da Escala',
            children: [
              _InfoRow(label: 'Data', value: e.dataEscala, theme: theme),
              _InfoRow(
                  label: 'Horário',
                  value: '${e.horarioIni} – ${e.horarioFim}  (${e.horas}h)',
                  theme: theme),
              _InfoRow(label: 'Tipo', value: e.tipoServico, theme: theme),
              _InfoRow(
                  label: 'Guarnição', value: e.guarnicaoNome, theme: theme),
              if (e.vtr != null)
                _InfoRow(label: 'Viatura', value: e.vtr!, theme: theme),
              if (e.localAtuacao != null)
                _InfoRow(
                    label: 'Local de Atuação',
                    value: e.localAtuacao!,
                    theme: theme),
              if (e.localAssuncao != null)
                _InfoRow(
                    label: 'Local de Assunção',
                    value: e.localAssuncao!,
                    theme: theme),
              _InfoRow(label: 'Função', value: e.funcaoNome, theme: theme),
              if (e.uniforme != null)
                _InfoRow(label: 'Uniforme', value: e.uniforme!, theme: theme),
            ],
          ),

          // ── Corpo da notificação ──────────────────────────────────
          if (e.corpoNotificacao != null && e.corpoNotificacao!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              isDark: isDark,
              theme: theme,
              icon: Icons.article_rounded,
              title: 'Ordem de Missão',
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    e.corpoNotificacao!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: theme.colorScheme.onSurface.withOpacity(0.85)),
                  ),
                ),
              ],
            ),
          ],

          // ── Observações ───────────────────────────────────────────
          if (e.observacoesGerais != null &&
              e.observacoesGerais!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              isDark: isDark,
              theme: theme,
              icon: Icons.info_outline_rounded,
              title: 'Observações',
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    e.observacoesGerais!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: theme.colorScheme.onSurface.withOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ],

          // ── Composição ────────────────────────────────────────────
          if (e.composicao.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              isDark: isDark,
              theme: theme,
              icon: Icons.groups_rounded,
              title: 'Composição da Guarnição',
              children: [
                ...e.composicao.map((m) =>
                    _ComposicaoTile(membro: m, isDark: isDark, theme: theme)),
              ],
            ),
          ],

          // ── Ações ─────────────────────────────────────────────────
          const SizedBox(height: 24),
          if (_actionLoading)
            const Center(
                child: CircularProgressIndicator(
                    color: AppColors.blue, strokeWidth: 2.5))
          else
            _buildActions(e),
        ],
      ),
    );
  }

  Widget _buildActions(EscalaModel e) {
    if (e.temCiencia && !e.temImpossibilidade) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              e.cienciaEmBr != null
                  ? 'Ciência registrada em ${e.cienciaEmBr}'
                  : 'Ciência registrada',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (e.temImpossibilidade) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.25), width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text('Impossibilidade declarada',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // Ações disponíveis
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _darCiencia,
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Dar Ciência',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _declararImpossibilidade,
            icon:
                const Icon(Icons.block_rounded, size: 18, color: Colors.orange),
            label: const Text('Declarar Impossibilidade',
                style: TextStyle(color: Colors.orange)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.isDark,
    required this.theme,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE8EFFA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.blue),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoRow(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ComposicaoTile extends StatelessWidget {
  final EscalaComposicaoModel membro;
  final bool isDark;
  final ThemeData theme;

  const _ComposicaoTile(
      {required this.membro, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.blue.withOpacity(0.12),
            child: Text(
              membro.nomeGuerra.isNotEmpty ? membro.nomeGuerra[0] : '?',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${membro.postoSigla} ${membro.nomeGuerra}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${membro.funcao}  ·  ${membro.quadroSigla}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          if (membro.telefone != null)
            Icon(Icons.phone_rounded,
                size: 15, color: theme.colorScheme.onSurface.withOpacity(0.35)),
        ],
      ),
    );
  }
}

// ── Bottom Sheet Impossibilidade ──────────────────────────────────────────────
class _ImpossibilidadeSheet extends StatefulWidget {
  final List<EscalaImpossibilidadeTipo> tipos;
  const _ImpossibilidadeSheet({required this.tipos});

  @override
  State<_ImpossibilidadeSheet> createState() => _ImpossibilidadeSheetState();
}

class _ImpossibilidadeSheetState extends State<_ImpossibilidadeSheet> {
  EscalaImpossibilidadeTipo? _selected;
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Declarar Impossibilidade',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Motivo',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            if (widget.tipos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Nenhum tipo disponível.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...widget.tipos.map((t) =>
                  RadioListTile<EscalaImpossibilidadeTipo>(
                    value: t,
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                    title: Text(t.descricao, style: theme.textTheme.bodyMedium),
                    subtitle: t.requerAnexo
                        ? const Text('* Requer anexo',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 11))
                        : null,
                    dense: true,
                    activeColor: AppColors.blue,
                    contentPadding: EdgeInsets.zero,
                  )),
            const SizedBox(height: 8),
            Text('Observação (opcional)',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            TextField(
              controller: _obs,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Descreva o motivo...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop({
                          'tipo_id': _selected!.id,
                          'observacao': _obs.text.trim(),
                        }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Registrar Impossibilidade',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Views de Estado ───────────────────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => const Center(
        child:
            CircularProgressIndicator(color: AppColors.blue, strokeWidth: 2.5),
      );
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
(String, Color, IconData) _statusVisualInfo(EscalaStatusVisual s) {
  return switch (s) {
    EscalaStatusVisual.aguardandoCiencia => (
        'Aguardando Ciência',
        Colors.amber,
        Icons.schedule_rounded
      ),
    EscalaStatusVisual.ciente => (
        'Ciente',
        Colors.green,
        Icons.check_circle_rounded
      ),
    EscalaStatusVisual.impossibilidade => (
        'Impossibilidade Declarada',
        Colors.red,
        Icons.block_rounded
      ),
    EscalaStatusVisual.realizada => (
        'Escala Realizada',
        Colors.grey,
        Icons.task_alt_rounded
      ),
    EscalaStatusVisual.semCienciaHistorico => (
        'Sem Ciência no Histórico',
        Colors.blueGrey,
        Icons.remove_circle_outline_rounded
      ),
  };
}
