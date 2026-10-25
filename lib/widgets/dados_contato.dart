import 'package:flutter/material.dart';
import 'package:projetonovo/utils/app_theme.dart';

import '../models/militar.dart';
import '../models/telefone.dart';
import '../services/dados_sql.dart';
import '../core/design/arte_cartao.dart';
import '../core/design/folha_arte.dart';
import 'alerta.dart';
import 'dialogo_confirmacao.dart';
import 'vidro.dart';

class DadosContato extends StatefulWidget {
  final Militar militar;
  const DadosContato({Key? key, required this.militar}) : super(key: key);

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
      alertaSucesso(context,
          titulo: 'Salvo!',
          texto: !isWhats
              ? 'WhatsApp marcado para\n${tel.numeroTel}'
              : 'Contato alterado para chamada comum.',
          confirmar: 'OK');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      alertaErro(context,
          titulo: 'Erro',
          texto:
              'Não foi possível salvar.\nVerifique sua conexão e tente novamente.',
          confirmar: 'OK');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aoFundo = theme.colorScheme.onSurface;
    // Verde do WhatsApp, só como tingimento e cor do selo marcado; no claro,
    // um tom mais escuro para o texto passar de 4,5:1.
    final isDark = theme.brightness == Brightness.dark;
    final verdeZap =
        isDark ? const Color(0xFF25D366) : const Color(0xFF14713B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header com botão adicionar ────────────────────────────────────
        Row(
          children: [
            Text('Números cadastrados',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: aoFundo.withValues(alpha: 0.6))),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_call, size: AppIconSize.xs),
              label: const Text('Adicionar'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () async {
                await _openDialogAdd(widget.militar.telefones);
              },
            ),
          ],
        ),

        // ── Lista de telefones ────────────────────────────────────────────
        // Linhas dentro da caixa da seção, separadas por divisor (lista
        // agrupada); antes cada número era uma caixa branca própria.
        if (widget.militar.telefones.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Nenhum contato cadastrado.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: aoFundo.withValues(alpha: 0.6))),
            ),
          )
        else
          ...widget.militar.telefones.asMap().entries.map((entry) {
            final index = entry.key;
            final tel = entry.value;
            final isWhats = tel.value == true;

            return Column(
              children: [
                if (index > 0)
                  Divider(height: 1, color: aoFundo.withValues(alpha: 0.08)),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.phone_outlined,
                            size: AppIconSize.xs,
                            color: theme.colorScheme.primary),
                      ),
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
                      // WhatsApp — toque no selo para salvar direto no banco
                      Semantics(
                        button: true,
                        toggled: isWhats,
                        label: 'WhatsApp',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => _salvarWhatsapp(tel, isWhats),
                          borderRadius: BorderRadius.circular(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Center(
                              widthFactor: 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isWhats
                                      ? verdeZap.withValues(
                                          alpha: isDark ? 0.20 : 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isWhats
                                        ? verdeZap.withValues(alpha: 0.55)
                                        : aoFundo.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/imagens/whatsapp.png',
                                      width: 14,
                                      height: 14,
                                      color: isWhats
                                          ? verdeZap
                                          : aoFundo.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'WhatsApp',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isWhats
                                            ? verdeZap
                                            : aoFundo.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Excluir (alvo de 44 pt)
                      IconButton(
                        tooltip: 'Excluir ${tel.numeroTel}',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: Icon(Icons.delete_outline_rounded,
                            size: AppIconSize.sm,
                            color: theme.colorScheme.error),
                        onPressed: () async {
                          if (widget.militar.telefones.length <= 1) {
                            alertaErro(context,
                                titulo: 'Atenção',
                                texto:
                                    'É necessário ter ao menos um contato cadastrado.',
                                confirmar: 'OK');
                          } else {
                            await _openDialogExclui(
                                widget.militar.telefones, index);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }

  Future<void> _openDialogAdd(List<Telefone> lista) async {
    _telController.text = '95';

    // Folha no padrão 2.2 (faixa com a arte da ficha), com o campo do tema.
    final confirmed = await mostrarFolhaArte<bool>(
      context,
      arte: Arte.de('rh'),
      icone: Icons.add_call,
      titulo: 'Novo contato',
      subtitulo: 'DDD + número (11 dígitos)',
      corpo: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isValid = _telController.text.length == 11;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _telController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                maxLength: 11,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Número de telefone',
                  hintText: '95912345678',
                  counterText: '',
                  prefixIcon:
                      Icon(Icons.phone_outlined, size: AppIconSize.sm),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          isValid ? () => Navigator.of(ctx).pop(true) : null,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('Adicionar'),
                    ),
                  ),
                ],
              ),
            ],
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
      alertaSucesso(context,
          titulo: 'Adicionado!',
          texto: 'Número $novoNumero cadastrado com sucesso.',
          confirmar: 'OK');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      alertaErro(context,
          titulo: 'Erro',
          texto:
              'Não foi possível salvar.\nVerifique sua conexão e tente novamente.',
          confirmar: 'OK');
    }
  }

  Future<void> _openDialogExclui(List<Telefone> lista, int index) async {
    final numero = lista[index].numeroTel;

    // Confirmação no desenho do app, em vermelho (DESIGN §5).
    final confirmed = await dialogoConfirmacao(
      context,
      titulo: 'Excluir contato',
      mensagem: 'Deseja excluir o número $numero? '
          'Esta ação não pode ser desfeita.',
      textoConfirmar: 'Excluir',
      icone: Icons.phone_disabled_outlined,
      cor: Theme.of(context).colorScheme.error,
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
      alertaSucesso(context,
          titulo: 'Excluído!',
          texto: 'O número $numero foi removido.',
          confirmar: 'OK');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      // Reverte remoção local em caso de falha
      lista.insert(
          index, Telefone(numeroTel: numero, tipo: Tipos.comum, value: false));
      setState(() {});
      alertaErro(context,
          titulo: 'Erro',
          texto:
              'Não foi possível excluir.\nVerifique sua conexão e tente novamente.',
          confirmar: 'OK');
    }
  }
}

// ── Aviso de "salvando" centralizado ─────────────────────────────────────────
// Caixa de vidro do app (CartaoVidro), com o indicador da plataforma.
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Salvando. Aguarde um momento.',
          excludeSemantics: true,
          child: CartaoVidro(
            raio: 22,
            arte: Arte.de('rh'),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator.adaptive(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Salvando…',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aguarde um momento',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
