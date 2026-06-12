import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:quickalert/quickalert.dart';

import '../models/militar.dart';
import '../models/telefone.dart';

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
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF5F8FF),
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
                  // WhatsApp icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isWhats
                          ? const Color(0xFF25D366).withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/imagens/whatsapp.png',
                      width: 16,
                      height: 16,
                      color: isWhats ? const Color(0xFF25D366) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tel.numeroTel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Toggle WhatsApp
                  Switch.adaptive(
                    value: isWhats,
                    activeColor: const Color(0xFF25D366),
                    onChanged: (val) {
                      for (final t in widget.militar.telefones) {
                        t.value = false;
                        t.tipo = Tipos.comum;
                      }
                      if (val) {
                        tel.tipo = Tipos.whats;
                        tel.value = true;
                      }
                      widget.militar.alterouDados = true;
                      setState(() {});
                      widget.atualizarDados();
                    },
                  ),
                  // Excluir
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
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
                          titleColor:
                              Theme.of(context).colorScheme.onSurface,
                          textColor:
                              Theme.of(context).colorScheme.onSurface,
                        );
                      } else {
                        _openDialogExclui(widget.militar.telefones, index);
                        widget.militar.alterouDados = true;
                        widget.atualizarDados();
                      }
                    },
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
        content:
            Text('Excluir o número ${lista[index].numeroTel}?'),
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


