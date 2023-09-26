import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../utils/NotificationService.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Auth auth = Provider.of(context);
    NotificationService notification = auth.notificationService;

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 49, 150, 238),
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.message_outlined,
              size: 48,
              color: Colors.white,
            ),
            const Text(
              'Novidades após a Notificação Push! ',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            ElevatedButton(
              onPressed: () {
                notification.showNotification(CustomNotification(
                    id: 1, title: 'Teste', body: 'Acesse o app', payload: '/'));
              },
              child: Text('Clicar'),
            )
          ],
        ),
      ),
    );
  }
}
