import 'package:flutter/material.dart';
import 'package:projetonovo/models/notification_model.dart';
import 'package:projetonovo/services/notification_service.dart';
import 'package:projetonovo/utils/app_routes.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

// ── NotificationsBody ─────────────────────────────────────────────────────────
// Conteúdo da aba "Notificações" dentro do MainShell.
class NotificationsBody extends StatelessWidget {
  const NotificationsBody({Key? key}) : super(key: key);

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min atrás';
    if (diff.inDays < 1) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'Ontem';
    return '${diff.inDays}d atrás';
  }

  String _groupLabel(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inDays < 1) return 'Hoje';
    if (diff.inDays < 7) return 'Esta semana';
    return 'Anterior';
  }

  void _showDialog(BuildContext context, NotificationModel notif,
      NotificationProvider provider) {
    if (!notif.clicked) provider.markAsClicked(notif.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(notif.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notif.body,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              Text(
                _formatTimestamp(notif.timestamp),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar')),
          if (notif.route != null && notif.route!.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context)
                    .popAndPushNamed(notif.route ?? AppRoutes.HOME_PAGE);
              },
              child: const Text('Ir'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.notifications.reversed.toList();
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma notificação',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        // Agrupa por label
        final grouped = <String, List<NotificationModel>>{};
        for (final n in notifications) {
          final label = _groupLabel(n.timestamp);
          grouped.putIfAbsent(label, () => []).add(n);
        }
        const order = ['Hoje', 'Esta semana', 'Anterior'];
        final entries = order
            .where((k) => grouped.containsKey(k))
            .map((k) => MapEntry(k, grouped[k]!))
            .toList();

        return RefreshIndicator(
          onRefresh: () => provider.loadNotifications(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
            itemBuilder: (context, index) {
              // Calcula qual grupo/item corresponde ao índice
              int cursor = 0;
              for (final entry in entries) {
                if (index == cursor) {
                  // Cabeçalho do grupo
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                    ),
                  );
                }
                cursor++;
                final localIndex = index - cursor;
                if (localIndex >= 0 && localIndex < entry.value.length) {
                  final notif = entry.value[localIndex];
                  return _NotifTile(
                    notif: notif,
                    provider: provider,
                    formatTimestamp: _formatTimestamp,
                    onTap: () => _showDialog(context, notif, provider),
                  );
                }
                cursor += entry.value.length;
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

// ── _NotifTile ────────────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final NotificationProvider provider;
  final String Function(DateTime) formatTimestamp;
  final VoidCallback onTap;

  const _NotifTile({
    Key? key,
    required this.notif,
    required this.provider,
    required this.formatTimestamp,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notif.clicked;

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        provider.removeNotification(notif.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificação removida'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.red,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isUnread
              ? theme.colorScheme.primaryContainer.withOpacity(0.35)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? theme.colorScheme.primary.withOpacity(0.25)
                : theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: isUnread
                ? theme.colorScheme.primary.withOpacity(0.15)
                : theme.colorScheme.surfaceVariant,
            child: Icon(
              isUnread
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: isUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          title: Text(
            notif.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notif.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                formatTimestamp(notif.timestamp),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          trailing: isUnread
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                )
              : null,
          onTap: onTap,
        ),
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
