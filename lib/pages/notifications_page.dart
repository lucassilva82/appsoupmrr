import 'package:flutter/material.dart';
import 'package:projetonovo/main.dart' show abrirAviso, navegarPorNotificacao;
import 'package:projetonovo/models/aviso_model.dart';
import 'package:projetonovo/models/notification_model.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';
import '../widgets/vidro.dart';
import '../widgets/aviso_rapido.dart';

// ── Helpers de categoria / tempo ──────────────────────────────────────────────
/// Mapeia a rota da notificação para um ícone + cor de categoria, dando o
/// visual "por assunto" (estilo BB / Instagram) sem perder o padrão de cores.
class _NotifCategoria {
  final IconData icon;
  final Color color;
  final String label;
  const _NotifCategoria(this.icon, this.color, this.label);
}

_NotifCategoria _categoriaDe(NotificationModel n, ThemeData theme) {
  final r = (n.route ?? '').toLowerCase();
  if (r.contains('svi')) {
    return const _NotifCategoria(
        Icons.more_time_rounded, Color(0xFF059669), 'SVI');
  }
  if (r.contains('escala')) {
    return const _NotifCategoria(
        Icons.assignment_rounded, AppColors.blue, 'Escalas');
  }
  if (r.contains('contracheque')) {
    return const _NotifCategoria(
        Icons.receipt_long_rounded, Color(0xFF7C3AED), 'Contracheque');
  }
  if (r.contains('feria')) {
    return const _NotifCategoria(
        Icons.beach_access_rounded, Color(0xFF0EA5E9), 'Férias');
  }
  if (r.contains('declaraco')) {
    return const _NotifCategoria(
        Icons.attach_money_rounded, Color(0xFF059669), 'Declarações');
  }
  if (r.contains('certid')) {
    return const _NotifCategoria(
        Icons.verified_outlined, Color(0xFF6366F1), 'Certidões');
  }
  if (r.contains('feedback') || r.contains('sugest')) {
    return _NotifCategoria(Icons.rate_review_outlined, theme.colorScheme.primary, 'Sugestões');
  }
  if (r.contains('legisla')) {
    return const _NotifCategoria(
        Icons.library_books_rounded, Color(0xFF2563EB), 'Legislações');
  }
  if (r.contains('pop')) {
    return const _NotifCategoria(Icons.gavel_rounded, Color(0xFF64748B), 'POP');
  }
  if (r.contains('mapa')) {
    return const _NotifCategoria(
        Icons.groups_2_rounded, AppColors.gold, 'Mapa da Força');
  }
  return _NotifCategoria(
      Icons.campaign_rounded, theme.colorScheme.primary, 'Aviso');
}

String _formatFull(DateTime ts) {
  const meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(ts.day)} ${meses[ts.month - 1]} ${ts.year} · ${two(ts.hour)}:${two(ts.minute)}';
}

// ── NotificationsBody ─────────────────────────────────────────────────────────
// Conteúdo da aba "Notificações" dentro do MainShell.
class NotificationsBody extends StatelessWidget {
  const NotificationsBody({Key? key}) : super(key: key);

  // ── Ações do topo ───────────────────────────────────────────────────────────
  Future<void> _confirmarLimpar(
      BuildContext context, NotificationProvider provider) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpar notificações'),
        content: const Text(
            'Deseja remover todas as notificações? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await provider.clearAll();
    if (context.mounted) {
      avisoSucesso(context, 'Notificações removidas');
    }
  }

  // ── Leitura (aviso) em bottom sheet moderno ─────────────────────────────────
  void _abrirNotificacao(BuildContext context, NotificationModel notif,
      NotificationProvider provider) {
    if (!notif.clicked) provider.markAsClicked(notif);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifDetailSheet(notif: notif),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.notifications.reversed.toList();
        final unread = provider.unreadCount;

        if (notifications.isEmpty) {
          return _EmptyState(onRefresh: provider.loadNotifications);
        }

        // Uma lista só, de vidro (protótipo `telaAvisos`): a não lida tem
        // o título em negrito e um fio azul à esquerda. "Marcar todos" fica
        // na barra do topo; tirar um aviso é arrastar para a esquerda.
        return RefreshIndicator(
          onRefresh: provider.loadNotifications,
          color: theme.colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              CartaoVidro(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(children: [
                    for (final (i, notif) in notifications.indexed) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: theme.colorScheme.onSurface.withValues(alpha: .10)),
                      _LinhaAviso(
                        notif: notif,
                        onTap: () => _abrirNotificacao(context, notif, provider),
                        onDelete: () => provider.removeNotification(notif),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              if (unread == 0 && notifications.length > 1)
                Center(
                  child: TextButton(
                    onPressed: () => _confirmarLimpar(context, provider),
                    child: Text('Limpar todos',
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: .62))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Linha de um aviso (protótipo `.grupo .linha`): ícone num quadrado de 36,
/// título, texto e "quando · SouPMRR".
class _LinhaAviso extends StatelessWidget {
  const _LinhaAviso({required this.notif, required this.onTap, required this.onDelete});
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static String _quando(DateTime ts) {
    final agora = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    if (ts.year == agora.year && ts.month == agora.month && ts.day == agora.day) {
      return 'Hoje · ${two(ts.hour)}:${two(ts.minute)}';
    }
    final ontem = agora.subtract(const Duration(days: 1));
    if (ts.year == ontem.year && ts.month == ontem.month && ts.day == ontem.day) {
      return 'Ontem · ${two(ts.hour)}:${two(ts.minute)}';
    }
    return ts.year == agora.year ? '${two(ts.day)}/${two(ts.month)}' : '${two(ts.day)}/${two(ts.month)}/${ts.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final naoLida = !notif.clicked;
    final pri = theme.colorScheme.primary;
    final mudo = theme.colorScheme.onSurface.withValues(alpha: .62);
    final cat = _categoriaDe(notif, theme);
    return Dismissible(
      key: Key(NotificationProvider.keyDe(notif)),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        onDelete();
        avisoSucesso(context, 'Aviso removido');
      },
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Semantics(
        button: true,
        label: '${naoLida ? 'Não lido. ' : ''}${notif.title}. ${notif.body}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: naoLida ? Border(left: BorderSide(color: pri, width: 3)) : null,
            ),
            padding: EdgeInsets.fromLTRB(naoLida ? 11 : 14, 9, 14, 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: pri.withValues(alpha: .2), borderRadius: BorderRadius.circular(10)),
                child: Icon(cat.icon, size: AppIconSize.sm, color: pri),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(notif.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15.5,
                          height: 1.35,
                          fontWeight: naoLida ? FontWeight.w700 : FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                  if (notif.body.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(notif.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: mudo)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Text('${_quando(notif.timestamp)} · ', style: TextStyle(fontSize: 12.5, color: mudo)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('SouPMRR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mudo)),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NotifDetailSheet extends StatelessWidget {
  final NotificationModel notif;
  const _NotifDetailSheet({required this.notif});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cat = _categoriaDe(notif, theme);
    final aviso = notif.dadosAviso;
    final temRota =
        aviso != null || (notif.route != null && notif.route!.isNotEmpty);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        // Folha sobre a lista: superfície opaca, como a de emitir certidão.
        // A cor de vidro dos cartões (translúcida) deixava a lista aparecer
        // por trás do texto.
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(isDark ? 0.22 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: cat.color,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatFull(notif.timestamp),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      notif.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notif.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Ações
              Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (temRota) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Fechar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (aviso != null) {
                              abrirAviso(AvisoAberto.doPush(aviso));
                            } else {
                              navegarPorNotificacao(notif.route);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: Text(aviso != null ? 'Ver detalhes' : 'Abrir',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Fechar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Estado vazio ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Icon(
            Icons.notifications_off_outlined,
            size: 72,
            color: theme.colorScheme.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma notificação',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando houver avisos, escalas ou novidades,\neles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.70),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NotificationsPage ─────────────────────────────────────────────────────────
// Mantida para compatibilidade com rota existente.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FundoSuave(child: Scaffold(
      appBar: CustomAppBar(title: 'Notificações'),
      body: const NotificationsBody(),
    ));
  }
}
