import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:quickalert/quickalert.dart';

import '../models/militar.dart';
import '../models/telefone.dart';
import '../services/dados_sql.dart';

class DadosContato extends StatefulWidget {
  final Militar militar;
  final Function atualizarDados;
  const DadosContato(
      {Key? key, required this.militar, required this.atualizarDados})
      : super(key: key);

  @override
  State<DadosContato> createState() => _DadosContatoState();
}

class _DadosContatoState extends State<DadosContato> {
  late TextEditingController _telController;
  bool _saving = false;

  @override
  void initState() {
    _telController = TextEditingController(text: '95');
    super.initState();
  }

  @override
  void dispose() {
    _telController.dispose();
    super.dispose();
  }

  // ── Salva WhatsApp direto no banco com loading + feedback ─────────────
  Future<void> _salvarWhatsapp(Telefone tel, bool isWhats) async {
    if (_saving) return;

    // Atualiza estado local
    for (final t in widget.militar.telefones) {
      t.value = false;
      t.tipo = Tipos.comum;
    }
    if (!isWhats) {
      tel.tipo = Tipos.whats;
      tel.value = true;
    }
    widget.militar.alterouDados = true;
    setState(() => _saving = true);
    widget.atualizarDados();

    // Exibe loading centralizado
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _LoadingDialog(),
    );

    try {
      final dadosSql = DadosSql();
      await dadosSql.excluiContatos(widget.militar.matricula);
      for (final element in widget.militar.telefones) {
        final tipo = element.value == false ? '0' : '1';
        await dadosSql.adicionaContatos(
            widget.militar.matricula, element.numeroTel, tipo);
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // fecha loading

      // Confirmação de sucesso
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Salvo!',
        text: !isWhats
            ? 'WhatsApp marcado para\n${tel.numeroTel}'
            : 'Contato alterado para chamada comum.',
        confirmBtnText: 'OK',
        confirmBtnColor: AppColors.blue,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text:
            'Não foi possível salvar.\nVerifique sua conexão e tente novamente.',
        confirmBtnText: 'OK',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = AppColors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header com botão adicionar ────────────────────────────────────
        Row(
          children: [
            Text('Números cadastrados',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_call, size: 14),
              label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                widget.militar.alterouDados = true;
                await _openDialogAdd(widget.militar.telefones);
                widget.atualizarDados();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Lista de telefones ────────────────────────────────────────────
        if (widget.militar.telefones.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Nenhum contato cadastrado.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade500)),
            ),
          )
        else
          ...widget.militar.telefones.asMap().entries.map((entry) {
            final index = entry.key;
            final tel = entry.value;
            final isWhats = tel.value == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF21262D) : const Color(0xFFF5F8FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE0E7F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Número
                  const Icon(Icons.phone_outlined,
                      size: 16, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tel.numeroTel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // WhatsApp toggle — toque no chip para salvar direto no banco
                  GestureDetector(
                    onTap: () => _salvarWhatsapp(tel, isWhats),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isWhats
                            ? const Color(0xFF25D366)
                            : (isDark
                                ? const Color(0xFF2D333B)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isWhats
                              ? const Color(0xFF25D366)
                              : (isDark
                                  ? const Color(0xFF444D56)
                                  : Colors.grey.shade300),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/imagens/whatsapp.png',
                            width: 14,
                            height: 14,
                            color: isWhats ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isWhats ? Colors.white : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Excluir
                  GestureDetector(
                    onTap: () async {
                      if (widget.militar.telefones.length <= 1) {
                        QuickAlert.show(
                          confirmBtnText: 'OK',
                          context: context,
                          type: QuickAlertType.error,
                          title: 'Atenção',
                          text:
                              'É necessário ter ao menos um contato cadastrado.',
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          titleColor: Theme.of(context).colorScheme.onSurface,
                          textColor: Theme.of(context).colorScheme.onSurface,
                        );
                      } else {
                        widget.militar.alterouDados = true;
                        await _openDialogExclui(widget.militar.telefones, index);
                        widget.atualizarDados();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 15, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Future<void> _openDialogAdd(List<Telefone> lista) async {
    _telController.text = '95';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isValid = _telController.text.length == 11;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2128) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Gradient header ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.blue, AppColors.navy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_call,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Novo Contato',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Campo de número ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _telController,
                          keyboardType: TextInputType.phone,
                          autofocus: true,
                          maxLength: 11,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: 1.2,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Número de telefone',
                            hintText: '95912345678',
                            counterText: '',
                            prefixIcon: const Icon(Icons.phone_outlined,
                                color: AppColors.blue, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'DDD + número (11 dígitos)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  // ── Botões ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isValid
                                ? () => Navigator.of(ctx).pop(true)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              disabledBackgroundColor:
                                  AppColors.blue.withValues(alpha: 0.3),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Adicionar',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || _telController.text.length != 11) return;

    final novoNumero = _telController.text;
    lista.add(Telefone(numeroTel: novoNumero, tipo: Tipos.comum, value: false));
    setState(() {});

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _LoadingDialog(),
    );

    try {
      final dadosSql = DadosSql();
      await dadosSql.excluiContatos(widget.militar.matricula);
      for (final element in lista) {
        final tipo = element.value == false ? '0' : '1';
        await dadosSql.adicionaContatos(
            widget.militar.matricula, element.numeroTel, tipo);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Adicionado!',
        text: 'Número $novoNumero cadastrado com sucesso.',
        confirmBtnText: 'OK',
        confirmBtnColor: AppColors.blue,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text:
            'Não foi possível salvar.\nVerifique sua conexão e tente novamente.',
        confirmBtnText: 'OK',
      );
    }
  }

  Future<void> _openDialogExclui(List<Telefone> lista, int index) async {
    final numero = lista[index].numeroTel;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2128) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header perigo ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_disabled_outlined,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Excluir Contato',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Corpo ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Deseja excluir o número',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        numero,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 1.2,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Esta ação não pode ser desfeita.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),

                // ── Botões ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Excluir',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    lista.removeAt(index);
    setState(() {});

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _LoadingDialog(),
    );

    try {
      final dadosSql = DadosSql();
      await dadosSql.excluiContatos(widget.militar.matricula);
      for (final element in lista) {
        final tipo = element.value == false ? '0' : '1';
        await dadosSql.adicionaContatos(
            widget.militar.matricula, element.numeroTel, tipo);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Excluído!',
        text: 'O número $numero foi removido.',
        confirmBtnText: 'OK',
        confirmBtnColor: AppColors.blue,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      // Reverte remoção local em caso de falha
      lista.insert(
          index, Telefone(numeroTel: numero, tipo: Tipos.comum, value: false));
      setState(() {});
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text:
            'Não foi possível excluir.\nVerifique sua conexão e tente novamente.',
        confirmBtnText: 'OK',
      );
    }
  }
}

// ── Loading dialog centralizado ───────────────────────────────────────────────
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2128) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppColors.blue,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Salvando...',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aguarde um momento',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
