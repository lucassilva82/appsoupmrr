import 'package:flutter/material.dart';
import 'package:projetonovo/main.dart' show navegarPorNotificacao;
import 'package:projetonovo/models/notification_model.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

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
        Icons.request_quote_rounded, Color(0xFF7C3AED), 'Contracheque');
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
        Icons.edit_document, Color(0xFFEA580C), 'Certidões');
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

String _formatTimestamp(DateTime ts) {
  final now = DateTime.now();
  final diff = now.difference(ts);
  if (diff.inMinutes < 1) return 'Agora';
  if (diff.inHours < 1) return '${diff.inMinutes}min';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Ontem';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year}';
}

String _formatFull(DateTime ts) {
  const meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(ts.day)} ${meses[ts.month - 1]} ${ts.year} · ${two(ts.hour)}:${two(ts.minute)}';
}

String _groupLabel(DateTime ts) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tsDay = DateTime(ts.year, ts.month, ts.day);
  final diff = today.difference(tsDay).inDays;
  if (diff <= 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  if (diff < 7) return 'Esta semana';
  if (diff < 30) return 'Este mês';
  return 'Anteriores';
}

const List<String> _groupOrder = [
  'Hoje',
  'Ontem',
  'Esta semana',
  'Este mês',
  'Anteriores',
];

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notificações removidas'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

        // Agrupa por período
        final grouped = <String, List<NotificationModel>>{};
        for (final n in notifications) {
          grouped.putIfAbsent(_groupLabel(n.timestamp), () => []).add(n);
        }
        final entries = _groupOrder
            .where((k) => grouped.containsKey(k))
            .map((k) => MapEntry(k, grouped[k]!))
            .toList();

        return Column(
          children: [
            _ActionHeader(
              total: notifications.length,
              unread: unread,
              onMarkAll: unread > 0 ? provider.markAllAsRead : null,
              onClear: () => _confirmarLimpar(context, provider),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.loadNotifications,
                color: theme.colorScheme.primary,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.only(bottom: 24, top: 4),
                  itemCount: entries.fold<int>(
                      0, (sum, e) => sum + 1 + e.value.length),
                  itemBuilder: (context, index) {
                    int cursor = 0;
                    for (final entry in entries) {
                      if (index == cursor) {
                        return _GroupHeader(label: entry.key);
                      }
                      cursor++;
                      final localIndex = index - cursor;
                      if (localIndex >= 0 && localIndex < entry.value.length) {
                        final notif = entry.value[localIndex];
                        return _NotifTile(
                          notif: notif,
                          index: localIndex,
                          onTap: () =>
                              _abrirNotificacao(context, notif, provider),
                          onDelete: () => provider.removeNotification(notif),
                        );
                      }
                      cursor += entry.value.length;
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Cabeçalho de ações ────────────────────────────────────────────────────────
class _ActionHeader extends StatelessWidget {
  final int total;
  final int unread;
  final VoidCallback? onMarkAll;
  final VoidCallback onClear;

  const _ActionHeader({
    required this.total,
    required this.unread,
    required this.onMarkAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resumo =
        unread > 0 ? '$unread não lida${unread > 1 ? 's' : ''}' : 'Tudo em dia';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : theme.colorScheme.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: unread > 0
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : theme.colorScheme.onSurface.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unread > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 18,
              color: unread > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resumo,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$total no total',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          if (onMarkAll != null)
            TextButton.icon(
              onPressed: onMarkAll,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Marcar lidas',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: Icon(Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'clear') onClear();
              if (v == 'read' && onMarkAll != null) onMarkAll!();
            },
            itemBuilder: (_) => [
              if (onMarkAll != null)
                const PopupMenuItem(
                  value: 'read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Marcar todas como lidas'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Limpar tudo',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Cabeçalho de grupo (Hoje / Ontem / ...) ───────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurface.withOpacity(0.45),
        ),
      ),
    );
  }
}

// ── _NotifTile ────────────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifTile({
    Key? key,
    required this.notif,
    required this.index,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = !notif.clicked;
    final cat = _categoriaDe(notif, theme);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + (index * 30).clamp(0, 240)),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Dismissible(
        key: Key(NotificationProvider.keyDe(notif)),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          onDelete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notificação removida'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 26),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUnread
                      ? cat.color.withOpacity(isDark ? 0.14 : 0.07)
                      : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnread
                        ? cat.color.withOpacity(0.35)
                        : (isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE8EFFA)),
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar de categoria
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(isDark ? 0.22 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimestamp(notif.timestamp),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.45),
                                  fontSize: 11,
                                ),
                              ),
                              if (isUnread)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cat.color,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detalhe da notificação (aviso) ────────────────────────────────────────────
class _NotifDetailSheet extends StatelessWidget {
  final NotificationModel notif;
  const _NotifDetailSheet({required this.notif});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cat = _categoriaDe(notif, theme);
    final temRota = notif.route != null && notif.route!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
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
                            navegarPorNotificacao(notif.route);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('Abrir',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
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
              color: theme.colorScheme.onSurface.withOpacity(0.45),
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
    return Scaffold(
      appBar: CustomAppBar(title: 'Notificações'),
      body: const NotificationsBody(),
    );
  }
}
