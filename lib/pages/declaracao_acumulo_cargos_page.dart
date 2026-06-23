import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:provider/provider.dart';

class DeclaracaoAcumuloCargosPage extends StatefulWidget {
  final String ano;

  const DeclaracaoAcumuloCargosPage({Key? key, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoAcumuloCargosPage> createState() =>
      _DeclaracaoAcumuloCargosPageState();
}

class _DeclaracaoAcumuloCargosPageState
    extends State<DeclaracaoAcumuloCargosPage> {
  bool? acumulaCargo;
  List<dynamic> cargos = [];
  final TextEditingController cargoController = TextEditingController();
  final TextEditingController orgaoController = TextEditingController();
  bool isLoading = true;

  ButtonStyle _compactActionStyle() => const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(Size(0, 34)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      );

  @override
  void initState() {
    super.initState();
    _fetchCargos();
  }

  @override
  void dispose() {
    cargoController.dispose();
    orgaoController.dispose();
    super.dispose();
  }

  Future<void> _fetchCargos() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscaacumulocargos.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          setState(() {
            cargos = data['cargos'] ?? [];
            if (cargos.length == 1 &&
                (cargos[0]['cargo'] == null || cargos[0]['cargo'] == '') &&
                (cargos[0]['orgao'] == null || cargos[0]['orgao'] == '')) {
              acumulaCargo = false;
            } else {
              acumulaCargo = cargos.isNotEmpty;
            }
          });
        } else {
          setState(() {
            cargos = [];
            acumulaCargo = null;
          });
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao buscar cargos: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      await _showNotice(
        title: 'Erro',
        message: 'Erro inesperado: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _inserirCargo(String cpf, bool temAcumulo) async {
    if (temAcumulo) {
      if (cargoController.text.isEmpty || orgaoController.text.isEmpty) {
        await _showNotice(
          title: 'Campos obrigatórios',
          message: 'Preencha os campos de cargo e órgão antes de enviar.',
          isError: true,
        );
        return;
      }
    }

    setState(() => isLoading = true);

    final Map<String, String> params = {
      'cpf': cpf,
      'ano': widget.ano,
      'dataEnvio': DateTime.now().toIso8601String(),
      'cargo': temAcumulo ? cargoController.text : '',
      'orgao': temAcumulo ? orgaoController.text : '',
    };

    final uri =
        Uri.https('pmrr.net', '/flutter/sigrh/insereacumulocargos.php', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          await _showNotice(
            title: 'Sucesso',
            message: temAcumulo
                ? 'Cargo adicionado com sucesso.'
                : 'Declaração de não acúmulo registrada.',
            isError: false,
          );

          await _fetchCargos();
          if (!mounted) return;

          if (temAcumulo) {
            setState(() {
              cargoController.clear();
              orgaoController.clear();
            });
          } else {
            setState(() => acumulaCargo = false);
          }
        } else {
          await _showNotice(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao inserir declaração.',
            isError: true,
          );
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao conectar ao servidor (${response.statusCode}).',
          isError: true,
        );
      }
    } catch (e) {
      await _showNotice(
        title: 'Erro',
        message: 'Erro inesperado: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _excluirCargo(int id) async {
    final confirm = await _showConfirmDialog(
      title: 'Excluir cargo',
      message: 'Deseja realmente excluir este registro?',
    );
    if (!confirm) return;

    _showBusyDialog('Excluindo...');

    try {
      final url =
          'https://pmrr.net/flutter/sigrh/excluiacumulocargos.php?id=$id';
      final response = await http.get(Uri.parse(url));
      _dismissDialogIfOpen();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          await _showNotice(
            title: 'Sucesso',
            message: 'Cargo excluído com sucesso.',
            isError: false,
          );
          if (!mounted) return;
          setState(() {
            cargos.removeWhere((cargo) => cargo['id'] == id);
            if (cargos.isEmpty) acumulaCargo = null;
          });
        } else {
          await _showNotice(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao excluir cargo.',
            isError: true,
          );
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao conectar ao servidor.',
          isError: true,
        );
      }
    } catch (e) {
      _dismissDialogIfOpen();
      await _showNotice(
        title: 'Erro',
        message: 'Erro inesperado: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Acúmulo de Cargos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.blue],
              begin: Alignment.centerLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF0E1B2E) : const Color(0xFFEAF2FF),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _buildContent(theme, auth),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, Auth auth) {
    if (acumulaCargo == null) return _buildQuestionStep(theme, auth);
    if (acumulaCargo == false) return _buildNoCargoStep(theme);
    return _buildHasCargoStep(theme, auth);
  }

  Widget _buildQuestionStep(ThemeData theme, Auth auth) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _introBanner(
          theme,
          title: 'Declaração de Acúmulo',
          subtitle: 'Mantenha os vínculos públicos informados e atualizados.',
        ),
        const SizedBox(height: 10),
        _infoCard(
          theme,
          icon: Icons.business_center_rounded,
          title: 'Pergunta obrigatória',
          text:
              'Você acumula cargo público? Caso tenha mais de um vínculo, declare aqui.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _inserirCargo(auth.cpf!, false),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Não acumulo'),
                style: _compactActionStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => acumulaCargo = true),
                icon: const Icon(Icons.add_link_rounded, size: 15),
                label: const Text('Sim, possuo'),
                style: _compactActionStyle(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoCargoStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _introBanner(
          theme,
          title: 'Situação registrada',
          subtitle: 'Você declarou não possuir acúmulo de cargo no período.',
        ),
        const SizedBox(height: 10),
        _statusBanner(
          theme,
          icon: Icons.check_circle_outline,
          color: Colors.green.shade700,
          text: 'Declaração enviada: não possuo acúmulo de cargo.',
        ),
        const SizedBox(height: 14),
        if (cargos.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _excluirCargo(cargos.first['id']),
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Excluir declaração'),
              style: _compactActionStyle(),
            ),
          ),
      ],
    );
  }

  Widget _buildHasCargoStep(ThemeData theme, Auth auth) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            children: [
              _introBanner(
                theme,
                title: 'Cadastro de vínculos',
                subtitle: 'Adicione cargo e órgão para cada vínculo acumulado.',
              ),
              const SizedBox(height: 10),
              _infoCard(
                theme,
                icon: Icons.badge_rounded,
                title: 'Novo vínculo público',
                text: 'Preencha os dados do cargo acumulado para adicionar.',
              ),
              const SizedBox(height: 10),
              _modernInput(controller: cargoController, label: 'Cargo'),
              const SizedBox(height: 8),
              _modernInput(
                controller: orgaoController,
                label: 'Órgão (Prefeitura, Estado, etc.)',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _inserirCargo(auth.cpf!, true),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Adicionar'),
                  style: _compactActionStyle(),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Cargos cadastrados',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...cargos.asMap().entries.map((entry) {
                final index = entry.key;
                final cargo = entry.value;
                return _buildCargoCard(theme, cargo, index);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCargoCard(ThemeData theme, dynamic cargo, int index) {
    final delay = (index * 40).clamp(0, 220);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + delay),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.blue.withValues(alpha: 0.12),
            child: const Icon(Icons.work_outline_rounded, size: 15),
          ),
          title: Text(cargo['cargo'] ?? 'Sem cargo'),
          subtitle: Text('Órgão: ${cargo['orgao'] ?? 'Desconhecido'}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => _excluirCargo(cargo['id']),
          ),
        ),
      ),
    );
  }

  Widget _modernInput({
    required TextEditingController controller,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.7)
            : Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
    );
  }

  Widget _infoCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introBanner(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _showNotice({
    required String title,
    required String message,
    required bool isError,
  }) async {
    final color = isError ? Colors.red.shade700 : Colors.green.shade700;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showBusyDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dismissDialogIfOpen() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
