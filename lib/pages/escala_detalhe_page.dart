import 'package:flutter/material.dart';

import '../models/escala_model.dart';
import '../services/escala_service.dart';
import '../utils/app_theme.dart';
import '../widgets/barra_vidro.dart';
import '../widgets/vidro.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../core/design/arte_cartao.dart';
import '../core/design/folha_arte.dart';
import '../widgets/aviso_rapido.dart';

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
    final confirm = await dialogoConfirmacao(
      context,
      titulo: 'Confirmar Ciência',
      mensagem:
          'Ao confirmar, você declara que tomou conhecimento desta escala de serviço.',
      textoConfirmar: 'Confirmar',
      icone: Icons.check_circle_rounded,
      cor: AppColors.acao,
      arte: Arte.de('operacional'),
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
      avisoSucesso(context, 'Ciência registrada');
    } on EscalaServiceException catch (e) {
      _logUi('darCiencia falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      avisoErro(context, 'Não foi possível registrar', texto: e.message);
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
      avisoAtencao(context, 'Impossibilidade registrada');
    } on EscalaServiceException catch (e) {
      _logUi('impossibilidade falhou code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      avisoErro(context, 'Não foi possível registrar', texto: e.message);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
    ));
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
          CartaoVidro(
            raio: 12,
            tingimento: statusColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          else
            _buildActions(e),
        ],
      ),
    );
  }

  Widget _buildActions(EscalaModel e) {
    final theme = Theme.of(context);
    final verde = theme.brightness == Brightness.dark
        ? AppColors.sucessoEscuro
        : AppColors.sucesso;
    final erro = theme.colorScheme.error;
    if (e.temCiencia && !e.temImpossibilidade) {
      return CartaoVidro(
        raio: 12,
        tingimento: verde,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, color: verde, size: AppIconSize.sm),
            const SizedBox(width: 8),
            Text(
              e.cienciaEmBr != null
                  ? 'Ciência registrada em ${e.cienciaEmBr}'
                  : 'Ciência registrada',
              style: TextStyle(color: verde, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (e.temImpossibilidade) {
      return CartaoVidro(
        raio: 12,
        tingimento: erro,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: erro, size: AppIconSize.sm),
            const SizedBox(width: 8),
            Text('Impossibilidade declarada',
                style: TextStyle(color: erro, fontWeight: FontWeight.w600)),
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
            icon: const Icon(Icons.check_circle_rounded, size: AppIconSize.sm),
            label: const Text('Dar Ciência'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _declararImpossibilidade,
            icon: const Icon(Icons.block_rounded, size: AppIconSize.sm),
            label: const Text('Declarar Impossibilidade'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCorAtencao,
              side: BorderSide(color: kCorAtencao.withValues(alpha: 0.5)),
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
    return CartaoVidro(
      arte: Arte.de('operacional'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Icon(icon,
                    size: AppIconSize.sm, color: theme.colorScheme.primary),
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
                color: theme.colorScheme.onSurface.withOpacity(0.70),
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
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              membro.nomeGuerra.isNotEmpty ? membro.nomeGuerra[0] : '?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.70)),
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

    return FolhaArte(
      arte: Arte.de('operacional'),
      icone: Icons.block_rounded,
      titulo: 'Declarar Impossibilidade',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motivo',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          if (widget.tipos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Nenhum tipo disponível.'),
            )
          else
            ...widget.tipos.map((t) => RadioListTile<EscalaImpossibilidadeTipo>(
                  value: t,
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                  title: Text(t.descricao, style: theme.textTheme.bodyMedium),
                  subtitle: t.requerAnexo
                      ? const Text('* Requer anexo',
                          style: TextStyle(color: kCorAtencao, fontSize: 11))
                      : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
          const SizedBox(height: 8),
          Text('Observação (opcional)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          TextField(
            controller: _obs,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Descreva o motivo...',
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
              child: const Text('Registrar Impossibilidade'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Views de Estado ───────────────────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CartaoVidro(
          arte: Arte.de('operacional'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: AppIconSize.xl, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
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
