import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:provider/provider.dart';

class DeclaracaoParentescoPage extends StatefulWidget {
  final String ano;

  const DeclaracaoParentescoPage({Key? key, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoParentescoPage> createState() =>
      _DeclaracaoParentescoPageState();
}

class _DeclaracaoParentescoPageState extends State<DeclaracaoParentescoPage> {
  bool? possuiParentesco;
  List<dynamic> parentes = [];
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cargoController = TextEditingController();
  String? parentescoId;
  bool isLoading = true;

  final Map<String, String> grausParentesco = {
    '1': 'Cônjuge',
    '2': 'Filho(a)',
    '3': 'Pai',
    '4': 'Mãe',
    '5': 'Irmão/Irmã',
    '6': 'Avô/Avó',
    '7': 'Neto(a)',
    '8': 'Tio(a)',
    '9': 'Sobrinho(a)',
    '10': 'Primo(a)',
    '11': 'Outro',
  };

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
    _fetchParentescos();
  }

  @override
  void dispose() {
    nomeController.dispose();
    cargoController.dispose();
    super.dispose();
  }

  Future<void> _fetchParentescos() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscaparentescos.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          setState(() {
            parentes = data['parentescos'] ?? [];
            if (parentes.length == 1 &&
                parentes[0]['nome_parente'] == null &&
                parentes[0]['parentesco_id'] == null &&
                parentes[0]['cargo'] == null) {
              possuiParentesco = false;
            } else {
              possuiParentesco = parentes.isNotEmpty;
            }
          });
        } else {
          setState(() {
            parentes = [];
            possuiParentesco = null;
          });
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao buscar parentescos: ${response.statusCode}',
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
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _inserirParentesco(String cpf, bool temParentesco) async {
    if (temParentesco) {
      if (nomeController.text.isEmpty ||
          cargoController.text.isEmpty ||
          parentescoId == null) {
        await _showNotice(
          title: 'Campos obrigatórios',
          message: 'Preencha todos os campos antes de enviar.',
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
    };

    if (temParentesco) {
      params['nome'] = nomeController.text;
      params['idParentesco'] = parentescoId!;
      params['cargo'] = cargoController.text;
    }

    final uri =
        Uri.https('pmrr.net', '/flutter/sigrh/insereparentesco.php', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          await _showNotice(
            title: 'Sucesso',
            message: temParentesco
                ? 'Parentesco adicionado com sucesso.'
                : 'Declaração de não possuir parentesco registrada.',
            isError: false,
          );

          await _fetchParentescos();
          if (temParentesco && mounted) {
            setState(() {
              nomeController.clear();
              cargoController.clear();
              parentescoId = null;
            });
          }
        } else {
          await _showNotice(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao inserir parentesco.',
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
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _excluirParentesco(int id) async {
    final confirm = await _showConfirmDialog(
      title: 'Excluir parentesco',
      message: 'Deseja realmente excluir este registro?',
    );
    if (!confirm) return;

    _showBusyDialog('Excluindo...');

    try {
      final url = 'https://pmrr.net/flutter/sigrh/excluiparentesco.php?id=$id';
      final response = await http.get(Uri.parse(url));
      _dismissDialogIfOpen();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          await _showNotice(
            title: 'Sucesso',
            message: 'Parentesco excluído com sucesso.',
            isError: false,
          );
          if (!mounted) return;
          setState(() {
            parentes.removeWhere((parente) => parente['id'] == id);
            if (parentes.isEmpty) possuiParentesco = null;
          });
        } else {
          await _showNotice(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao excluir parentesco.',
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

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Declaração de Parentesco',
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
            : _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (possuiParentesco == null) {
      return _buildQuestionStep(theme);
    }
    if (possuiParentesco == false) {
      return _buildNoRelationStep(theme);
    }
    return _buildHasRelationStep(theme);
  }

  Widget _buildQuestionStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _introBanner(
          theme,
          title: 'Declaração de Parentesco',
          subtitle: 'Informe vínculos familiares de forma objetiva e segura.',
        ),
        const SizedBox(height: 10),
        _infoCard(
          theme,
          icon: Icons.rule_folder_rounded,
          title: 'Súmula Vinculante n° 13 (STF)',
          text:
              'É cônjuge, companheiro(a) ou parente em linha reta, colateral ou por afinidade até o terceiro grau?',
        ),
        const SizedBox(height: 10),
        _infoCard(
          theme,
          icon: Icons.help_outline_rounded,
          title: 'Pergunta obrigatória',
          text:
              'Você possui familiar até o terceiro grau na Administração Pública Estadual?',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onNaoClicked,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Não'),
                style: _compactActionStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _onSimClicked,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Sim, possuo'),
                style: _compactActionStyle(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoRelationStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _introBanner(
          theme,
          title: 'Situação registrada',
          subtitle: 'Você declarou não possuir parentesco no período.',
        ),
        const SizedBox(height: 10),
        _statusBanner(
          theme,
          icon: Icons.check_circle_outline,
          color: Colors.green.shade700,
          text: 'Declaração registrada: não possuo parentesco.',
        ),
        const SizedBox(height: 14),
        if (parentes.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _excluirParentesco(parentes.first['id']),
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Excluir declaração'),
              style: _compactActionStyle(),
            ),
          ),
      ],
    );
  }

  Widget _buildHasRelationStep(ThemeData theme) {
    final auth = Provider.of<Auth>(context, listen: false);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            children: [
              _introBanner(
                theme,
                title: 'Cadastro de vínculos',
                subtitle:
                    'Adicione apenas familiares com relação até o terceiro grau.',
              ),
              const SizedBox(height: 10),
              _infoCard(
                theme,
                icon: Icons.group_rounded,
                title: 'Novo vínculo familiar',
                text: 'Preencha os dados para adicionar um parentesco.',
              ),
              const SizedBox(height: 10),
              _modernInput(
                controller: nomeController,
                label: 'Nome do familiar',
              ),
              const SizedBox(height: 8),
              _modernInput(
                controller: cargoController,
                label: 'Cargo que ocupa',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: parentescoId,
                decoration: const InputDecoration(
                  labelText: 'Grau de parentesco',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                items: grausParentesco.entries
                    .map((entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => parentescoId = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _inserirParentesco(auth.cpf!, true),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Adicionar'),
                  style: _compactActionStyle(),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Vínculos cadastrados',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...parentes.asMap().entries.map((entry) {
                final index = entry.key;
                final parente = entry.value;
                return _buildParenteCard(theme, parente, index);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParenteCard(ThemeData theme, dynamic parente, int index) {
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
            child: const Icon(Icons.person_rounded, size: 15),
          ),
          title: Text(parente['nome_parente'] ?? 'Sem nome'),
          subtitle: Text(
            'Grau: ${grausParentesco[parente['parentesco_id']?.toString()] ?? "Desconhecido"}\n'
            'Cargo: ${parente['cargo'] ?? "Desconhecido"}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => _excluirParentesco(parente['id']),
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

  void _onNaoClicked() async {
    final auth = Provider.of<Auth>(context, listen: false);
    await _inserirParentesco(auth.cpf!, false);
    if (!mounted) return;
    setState(() => possuiParentesco = false);
  }

  void _onSimClicked() {
    setState(() => possuiParentesco = true);
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
