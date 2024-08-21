import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:projetonovo/pages/ajuda_page.dart';
import 'package:projetonovo/pages/auth_or_home.dart';
import 'package:projetonovo/pages/auth_page.dart';
import 'package:projetonovo/pages/configura_plantao.dart';
import 'package:projetonovo/pages/configuracoes.dart';
import 'package:projetonovo/pages/contracheque.dart';
import 'package:projetonovo/pages/edicao_endereco_page.dart';
import 'package:projetonovo/pages/home_page.dart';
import 'package:projetonovo/pages/meu_patrimonio.dart';
import 'package:projetonovo/pages/notifications_page.dart';
import 'package:projetonovo/pages/page_contracheque.dart';
import 'package:projetonovo/pages/page_militar.dart';
import 'package:projetonovo/pages/plano_de_ferias.dart';
import 'package:projetonovo/pages/plantao_page.dart';
import 'package:projetonovo/utils/my_colors.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'models/auth_model.dart';
import 'models/meses_contracheque_model.dart';
import 'models/militar.dart';
import 'utils/app_routes.dart';
import 'package:intl/date_symbol_data_local.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully.');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('FlutterLocalNotificationsPlugin initialized successfully.');
  } catch (e) {
    print('FlutterLocalNotificationsPlugin initialization failed: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showNotification(message);
    }
  });

  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $fcmToken');
  } catch (e) {
    print('Failed to get FCM token: $e');
  }

  await requestNotificationPermission();

  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

Future<void> _showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'your_channel_id',
    'your_channel_name',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title,
    message.notification?.body,
    platformChannelSpecifics,
    payload: 'item x',
  );
}

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Auth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SouPMRR',
        initialRoute: '/',
        routes: {
          AppRoutes.AUTH_PAGE: (context) => const AuthPage(),
          AppRoutes.AUTH_OR_HOME: (context) => const AuthOrHome(),
          AppRoutes.PAGE_MILITAR: (context) => const PageMilitar(),
          AppRoutes.CONFIGURACOES: (context) => const Configuracoes(),
          AppRoutes.PLANODEFERIAS: (context) => const PlanoDeFerias(),
          AppRoutes.HOME_PAGE: (context) => HomePage(),
          AppRoutes.PLANTAO: (context) => PlantaoPage(),
          AppRoutes.NOTIFICATIONS_PAGE: (context) => NotificationsPage(),
          AppRoutes.AJUDA_PAGE: (context) => AjudaPage(),
          AppRoutes.CONTRACHEQUE_PAGE: (context) => Contracheque(),
          AppRoutes.CONFIGURA_PLANTAO: (context) => ConfiguraPlantao(),
          AppRoutes.DECLARACOES_IRPF_PAGE: (context) =>
              const MeuPatrimonioPage(),
          AppRoutes.ENDERECO_PAGE: (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Militar;
            return EdicaoEnderecoPage(militar: args);
          },
          AppRoutes.PAGE_VIEW_CONTRACHEQUE: (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments as MesesContracheque;
            return PageContracheque(mesSelecionado: args);
          },
        },
      ),
    );
  }
}
