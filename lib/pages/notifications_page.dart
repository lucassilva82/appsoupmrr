import 'package:flutter/material.dart';
import 'package:projetonovo/models/notification_model.dart';
import 'package:projetonovo/services/notification_service.dart';
import 'package:projetonovo/utils/app_routes.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await _notificationService.removeExpiredNotifications();
    final notifs = await _notificationService.getNotifications();
    setState(() {
      _notifications = notifs.reversed.toList();
    });
  }

  void _onNotificationTap(NotificationModel notif) async {
    await _notificationService.markAsClicked(notif.id);
    _loadNotifications();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min atrás';
    if (diff.inDays < 1) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  // NOVO: Método para mostrar dialog com mensagem completa
  void _showNotificationDialog(BuildContext context, NotificationModel notif,
      NotificationProvider provider) {
    // MARCA COMO LIDA IMEDIATAMENTE ao abrir o dialog
    if (!notif.clicked) {
      provider.markAsClicked(notif.id);

      // Força atualização do badge
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.notifyListeners();
        }
      });
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            notif.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notif.body,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatTimestamp(notif.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialog
              },
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialog
                _navigateToRouteOnly(
                    notif); // Navega para a rota (sem marcar como lida novamente)
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
  }

  // NOVO: Método apenas para navegar (sem marcar como lida)
  void _navigateToRouteOnly(NotificationModel notif) {
    print("a rota é ${notif.route}");
    final route = notif.route ?? AppRoutes.HOME_PAGE;
    Navigator.of(context).popAndPushNamed(route);
  }

  // MODIFICADO: Método para navegar para a rota da notificação
  void _navigateToRoute(
      NotificationModel notif, NotificationProvider provider) {
    // Marca como clicada
    provider.markAsClicked(notif.id);

    // Força atualização do badge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.notifyListeners();
      }
    });

    print("a rota é ${notif.route}");
    final route = notif.route ?? AppRoutes.HOME_PAGE;
    Navigator.of(context).popAndPushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Central de Notificações"),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<NotificationProvider>(context, listen: false)
              .loadNotifications();
        },
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            // mostra as notificações mais recentes primeiro
            final notifications = provider.notifications.reversed.toList();
            if (notifications.isEmpty) {
              return const Center(
                  child: Text('Nenhuma notificação disponível.'));
            }
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, index) => const Divider(
                height: 2,
              ),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Dismissible(
                    key: Key(notif.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      provider.removeNotification(notif.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notificação excluída')),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: !notif.clicked
                            ? LinearGradient(
                                colors: [
                                  const Color.fromARGB(255, 132, 245, 136),
                                  Colors.green.shade50
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: notif.clicked ? Colors.grey.shade300 : null,
                      ),
                      child: ListTile(
                        title: Text(
                          notif.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            letterSpacing: 1.2,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(notif.timestamp),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600]),
                            ),
                            // INDICADOR para mensagens longas
                            if (notif.body.length > 100)
                              Text(
                                'Toque para ler completo...',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: notif.clicked
                            ? null
                            : const Icon(Icons.fiber_new, color: Colors.red),
                        onTap: () {
                          // NOVA LÓGICA: Se mensagem for longa, mostra dialog primeiro
                          if (notif.body.length > 2) {
                            _showNotificationDialog(context, notif, provider);
                          } else {
                            // Se for curta, navega diretamente
                            _navigateToRoute(notif, provider);
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
