import 'package:projetonovo/widgets/alerta.dart';
import 'package:projetonovo/widgets/dialogo_confirmacao.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/utils/app_routes.dart';
import '../core/design/arte_cartao.dart';
import '../core/erros/falha_de.dart';
import '../utils/app_theme.dart';
import 'vidro.dart';

class DeclaracaoWidget extends StatefulWidget {
  final String cpf;
  final String ano;

  const DeclaracaoWidget({Key? key, required this.cpf, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoWidget> createState() => _DeclaracaoWidgetState();
}

class _DeclaracaoWidgetState extends State<DeclaracaoWidget> {
  static const _base = 'https://pmrr.online/flutter/sigrh';

  bool _isLoading = true;
  String? _errorMessage;
  List<_DeclaracaoItem> _itens = const [];
  DateTime? _lastSync;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchDeclaracoes(firstLoad: true);

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _fetchDeclaracoes(firstLoad: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeclaracoes({bool firstLoad = false}) async {
    if (firstLoad) setState(() => _isLoading = true);
    _errorMessage = null;

    final url =
        '$_base/buscastatusdeclaracoes.php?cpf=${widget.cpf}&ano=${widget.ano}';
    debugPrint('[Declaracoes2] GET status url=$url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '[Declaracoes2] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          final list = data['result'] as List<dynamic>;
          final payload = list.isNotEmpty && list.first is Map<String, dynamic>
              ? list.first as Map<String, dynamic>
              : <String, dynamic>{};

          setState(() {
            _itens = _mapItens(payload);
            _lastSync = DateTime.now();
            _errorMessage = null;
          });
        } else {
          setState(() {
            _itens = const [];
            _errorMessage = data['message'] ?? 'Erro ao carregar dados.';
          });
        }
      } else {
        setState(() {
          _itens = const [];
          _errorMessage =
              'Erro ao carregar dados. Código: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _itens = const [];
        _errorMessage = textoFalha('DC', e, tela: 'rh.declaracoes');
      });
    } finally {
      if (firstLoad && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirDeclaracao(
    String cpf,
    int ano,
    String title,
    String id,
  ) async {
    final confirmar = await _showConfirmDialog(
      title: 'Excluir declaração',
      message: 'Deseja realmente excluir $title?',
    );
    if (!confirmar) return;

    String url = '';
    if (id == '1') {
      url = '$_base/excluibens.php?cpf=$cpf&ano=$ano';
    } else if (id == '2') {
      url = '$_base/excluipdfirpf.php?cpf=$cpf&ano=$ano';
    } else if (id == '3') {
      url = '$_base/excluitodosparentescos.php?cpf=$cpf&ano=$ano';
    } else if (id == '4') {
      url = '$_base/excluiacumulotodoscargos.php?cpf=$cpf&ano=$ano';
    }

    _showBusyDialog();

    try {
      final response = await http.get(Uri.parse(url));
      _dismissIfOpen();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          await _showInfoDialog(
            title: 'Sucesso',
            message: '$title excluída com sucesso.',
            isError: false,
          );
          _fetchDeclaracoes(firstLoad: false);
        } else {
          await _showInfoDialog(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao excluir $title.',
            isError: true,
          );
        }
      } else {
        await _showInfoDialog(
          title: 'Erro',
          message: 'Erro na exclusão de $title. Código: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      _dismissIfOpen();
      await _showInfoDialog(
        title: 'Erro',
        message: textoFalha('DC', e, tela: 'rh.declaracoes'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return _buildLoadingState(theme);
    if (_errorMessage != null) return _buildErrorState(theme);
    if (_itens.isEmpty) return _buildEmptyState(theme);

    return _buildDeclaracoesList(theme);
  }

  Widget _buildLoadingState(ThemeData theme) {
    return CartaoVidro(
      arte: Arte.de('rh'),
      raio: 14,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: 10),
          Text('Buscando suas declarações...',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return CartaoVidro(
      raio: 14,
      tingimento: theme.colorScheme.error,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const SizedBox(width: double.infinity),
          Icon(Icons.error_outline_rounded,
              color: theme.colorScheme.error, size: AppIconSize.sm),
          const SizedBox(height: 8),
          Text(_errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _fetchDeclaracoes(firstLoad: true),
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return CartaoVidro(
      arte: Arte.de('rh'),
      raio: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const SizedBox(width: double.infinity),
          Icon(Icons.inbox_outlined,
              size: AppIconSize.sm,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text('Nenhuma declaração encontrada para o ciclo selecionado.',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDeclaracoesList(ThemeData theme) {
    final pendentes = _itens.where((e) => e.status == 'Pendente').length;
    final declarados = _itens.where((e) => e.status == 'Declarado').length;
    final homologados = _itens.where((e) => e.status == 'Homologado').length;

    return Column(
      children: [
        CartaoVidro(
          arte: Arte.de('rh'),
          raio: 14,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined,
                      size: AppIconSize.xs, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Visão geral do ciclo',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _fetchDeclaracoes(firstLoad: false),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _statChip('Pendentes', pendentes, Colors.orange.shade700),
                  _statChip('Declarados', declarados, Colors.blue.shade700),
                  _statChip('Recebidos', homologados, Colors.green.shade700),
                ],
              ),
              if (_lastSync != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Última sincronização: ${_formatTime(_lastSync!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 11,
                  ),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._itens.asMap().entries.map(
              (entry) => _buildDeclaracaoCard(
                context,
                theme,
                entry.value,
                entry.key,
              ),
            ),
      ],
    );
  }

  Widget _buildDeclaracaoCard(
    BuildContext context,
    ThemeData theme,
    _DeclaracaoItem item,
    int index,
  ) {
    final statusView = _statusVisual(item.status);
    final delay = (index * 45).clamp(0, 240);

    return TweenAnimationBuilder<double>(
      key: ValueKey('decl-card-${item.id}-$index-${item.status}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      // Item da lista: vidro simples (a arte fica nos cartões de seção).
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        child: CartaoVidro(
          raio: 14,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusView.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusView.icon,
                        color: statusView.color, size: AppIconSize.xs),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusView.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusView.color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      statusView.label,
                      style: TextStyle(
                        color: statusView.color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _buildActions(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(_DeclaracaoItem item) {
    final compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    );

    if (item.status == 'Homologado') {
      return [
        FilledButton.tonalIcon(
          style: compact,
          onPressed: () => _openForm(item.id),
          icon: const Icon(Icons.visibility_rounded, size: 15),
          label: const Text('Ver'),
        ),
      ];
    }

    if (item.status == 'Pendente') {
      return [
        FilledButton.icon(
          style: compact,
          onPressed: () => _openForm(item.id),
          icon: const Icon(Icons.edit_document, size: 15),
          label: const Text('Preencher'),
        ),
      ];
    }

    if (item.status == 'Declarado') {
      if (item.id == '2') {
        return [
          FilledButton.tonalIcon(
            style: compact,
            onPressed: () => _openForm(item.id),
            icon: const Icon(Icons.visibility_rounded, size: 15),
            label: const Text('Visualizar'),
          ),
        ];
      }

      return [
        FilledButton.icon(
          style: compact,
          onPressed: () => _openForm(item.id),
          icon: const Icon(Icons.edit_rounded, size: 15),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          style: compact,
          onPressed: () => _excluirDeclaracao(
            widget.cpf,
            int.parse(widget.ano),
            item.title,
            item.id,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 15),
          label: const Text('Excluir'),
        ),
      ];
    }

    return [
      OutlinedButton.icon(
        style: compact,
        onPressed: () => _openForm(item.id),
        icon: const Icon(Icons.open_in_new_rounded, size: 15),
        label: const Text('Abrir'),
      ),
    ];
  }

  void _openForm(String id) {
    String route;
    switch (id) {
      case '1':
        route = AppRoutes.DECLARACAODEBENS;
        break;
      case '2':
        route = AppRoutes.DECLARACAO_BENS_PDF_PAGE;
        break;
      case '3':
        route = AppRoutes.DECLARACAO_PARENTESCO_PAGE;
        break;
      case '4':
        route = AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE;
        break;
      default:
        route = AppRoutes.DECLARACOES_PAGE;
    }

    Navigator.of(context)
        .pushNamed(route, arguments: widget.ano)
        .then((_) => _fetchDeclaracoes(firstLoad: false));
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) =>
      dialogoConfirmacao(
        context,
        titulo: title,
        mensagem: message,
        // Todas as confirmações desta tela são de exclusão.
        textoConfirmar: 'Excluir',
        icone: Icons.delete_outline_rounded,
        cor: Theme.of(context).colorScheme.error,
        arte: Arte.de('rh'),
      );

  void _showBusyDialog() =>
      mostrarCarregandoDialogo(context, 'Processando...', arte: Arte.de('rh'));

  void _dismissIfOpen() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    required bool isError,
  }) =>
      isError
          ? alertaErro(context,
              titulo: title, texto: message, arte: Arte.de('rh'))
          : alertaSucesso(context,
              titulo: title, texto: message, arte: Arte.de('rh'));

  List<_DeclaracaoItem> _mapItens(Map<String, dynamic> payload) {
    return [
      _DeclaracaoItem(
        id: '1',
        title: 'Declaração de Bens',
        status: _mapStatus(payload['declaracao_bens']?.toString()),
      ),
      _DeclaracaoItem(
        id: '2',
        title: 'Declaração de Bens (IRPF)',
        status: _mapStatus(payload['declaracao_bens_pdf']?.toString()),
      ),
      _DeclaracaoItem(
        id: '3',
        title: 'Declaração de Parentesco',
        status: _mapStatus(payload['declaracao_parentesco']?.toString()),
      ),
      _DeclaracaoItem(
        id: '4',
        title: 'Declaração de Acúmulo de Cargos',
        status: _mapStatus(payload['acumulo_cargos']?.toString()),
      ),
    ];
  }

  _StatusView _statusVisual(String status) {
    switch (status) {
      case 'Homologado':
        return _StatusView(
          label: 'Recebido',
          color: Colors.green.shade700,
          icon: Icons.verified_rounded,
        );
      case 'Declarado':
        return _StatusView(
          label: 'Em análise',
          color: Colors.blue.shade700,
          icon: Icons.hourglass_top_rounded,
        );
      default:
        return _StatusView(
          label: 'Pendente',
          color: Colors.orange.shade700,
          icon: Icons.pending_actions_rounded,
        );
    }
  }

  String _mapStatus(String? status) {
    switch (status) {
      case 'Não Declarado':
        return 'Pendente';
      case 'Declarado':
        return 'Declarado';
      case 'Homologado':
        return 'Homologado';
      default:
        return 'Pendente';
    }
  }
}

class _DeclaracaoItem {
  final String id;
  final String title;
  final String status;

  const _DeclaracaoItem({
    required this.id,
    required this.title,
    required this.status,
  });
}

class _StatusView {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusView({
    required this.label,
    required this.color,
    required this.icon,
  });
}
