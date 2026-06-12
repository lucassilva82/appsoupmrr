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
              onPressed: () {
                _openDialogAdd(widget.militar.telefones);
                widget.militar.alterouDados = true;
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
                    onTap: () {
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
                        _openDialogExclui(widget.militar.telefones, index);
                        widget.militar.alterouDados = true;
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
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar contato'),
        content: TextFormField(
          controller: _telController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Ex: 95912345678'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_telController.text.length == 11) {
                lista.add(Telefone(
                    numeroTel: _telController.text,
                    tipo: Tipos.comum,
                    value: false));
                _telController.text = '95';
                setState(() {});
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDialogExclui(List<Telefone> lista, int index) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir contato'),
        content: Text('Excluir o número ${lista[index].numeroTel}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              lista.removeAt(index);
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
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
