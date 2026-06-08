import 'dart:async';
import 'dart:io';
import 'dart:ui';
//teste de commit

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projetonovo/models/notification_model.dart';
import 'package:projetonovo/pages/certidoes_page.dart';
import 'package:projetonovo/pages/legislacoes_page.dart';
import 'package:projetonovo/pages/militar_detalhe_full_page.dart';
import 'package:projetonovo/pages/planodeferias.dart';
import 'package:projetonovo/pages/pop_page.dart';
import 'package:projetonovo/services/notification_service.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screenshot_recording_detector/models/detection_event.dart';
import 'package:screenshot_recording_detector/screenshot_recording_detector.dart';
import 'package:app_settings/app_settings.dart';
import 'package:quickalert/quickalert.dart';
import 'package:flutter/services.dart'; // Adicione esta linha

// ======== Páginas e models ======== //
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/models/meses_contracheque_model.dart';
import 'package:projetonovo/models/militar.dart';
import 'package:projetonovo/pages/ajuda_page.dart';
import 'package:projetonovo/pages/auth_or_home.dart';
import 'package:projetonovo/pages/auth_page.dart';
import 'package:projetonovo/pages/biometric_auth_page.dart';
import 'package:projetonovo/pages/configura_plantao.dart';
import 'package:projetonovo/pages/configuracoes.dart';
import 'package:projetonovo/pages/contracheque.dart';
import 'package:projetonovo/pages/declaracao_acumulo_cargos_page.dart';
import 'package:projetonovo/pages/declaracao_bens_page.dart';
import 'package:projetonovo/pages/declaracao_parentesco_page.dart';
import 'package:projetonovo/pages/declaracoes_bens_pdf_page.dart';
import 'package:projetonovo/pages/declaracoes_page.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_comando_page.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/pages/edicao_endereco_page.dart';
import 'package:projetonovo/pages/home_page.dart';
import 'package:projetonovo/pages/mapa_da_forca.dart';
import 'package:projetonovo/pages/notifications_page.dart';
import 'package:projetonovo/pages/page_contracheque.dart';
import 'package:projetonovo/pages/page_militar.dart';
import 'package:projetonovo/pages/plano_de_ferias.dart';
import 'package:projetonovo/pages/plantao_page.dart';
import 'package:projetonovo/utils/app_routes.dart';

import 'firebase_options.dart';
import 'models/auth_model.dart';
import 'package:projetonovo/data/store.dart'; // Certifique-se de que Store está acessível

// Instância global de notificações locais
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Handler FCM em background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('[DEBUG] ========================================');
  print('[DEBUG] 🚨 BACKGROUND HANDLER CHAMADO 🚨');
  print('[DEBUG] Message ID: ${message.messageId}');
  print('[DEBUG] Data: ${message.data}');
  print('[DEBUG] Notification: ${message.notification?.toMap()}');
  print('[DEBUG] ========================================');

  try {
    final notification = message.notification;
    final n = NotificationModel(
      title: notification?.title ?? message.data['title'] ?? 'Notificação',
      body: notification?.body ?? message.data['body'] ?? 'Nova mensagem',
      timestamp: DateTime.now(),
      clicked: false,
      route: message.data['route'],
    );

    print('[DEBUG] BG: Salvando: ${n.toMap()}');
    await NotificationService().addNotification(n);
    print('[DEBUG] BG: ✅ SALVO COM SUCESSO!');
  } catch (e) {
    print('[DEBUG] BG: ❌ ERRO: $e');
  }
}

// Bloqueio nativo (Android) + iOS ≤ 16
Future<void> _secureScreen() async {
  if (Platform.isAndroid) {
    await ScreenProtector.protectDataLeakageOn(); // FLAG_SECURE
  } else if (Platform.isIOS) {
    await ScreenProtector.preventScreenshotOn(); // print preto ≤ iOS 16
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('[DEBUG] 1) Bloqueio nativo preliminar');
  await _secureScreen();

  print('[DEBUG] 2) Inicializa detector universal');
  await ScreenshotRecordingDetector.initialize();

  print('[DEBUG] 3) Inicializando Firebase');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('[DEBUG] 3.1) Criando canal de notificação (Android)');
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel',
    'Notificações',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  print('[DEBUG] 4) Inicializando notificações locais');
  const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initAndroid, iOS: initIOS),
    onDidReceiveNotificationResponse: (resp) {
      print('[DEBUG] Notificação clicada – payload: ${resp.payload}');
    },
  );

  print('[DEBUG] 5) Registrando background handler FCM');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // CONFIGURAÇÕES DE FOREGROUND - CORRIGIDO
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // MUDE PARA TRUE
    badge: true,
    sound: true, // MUDE PARA TRUE
  );

  // 6) Permissões iOS
  if (Platform.isIOS) {
    print('[DEBUG] Solicitando permissão de notificação iOS');
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[DEBUG] Permissão iOS: ${settings.authorizationStatus}');
  }

  if (Platform.isIOS) {
    print('[DEBUG] Tentando obter APNs Token...');
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    print('[DEBUG] APNs Token: $apnsToken');
  }

  print('[DEBUG] Registrando listener onTokenRefresh');
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    print('[DEBUG] FCM Token atualizado: $token');
    try {
      final userData = await Store.getMap('userData');
      final matricula = userData['matricula'];
      if (matricula != null && matricula.toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('militares')
            .doc(matricula.toString())
            .set({'fcmToken': token}, SetOptions(merge: true));
        print('[DEBUG] FCM Token renovado salvo no Firestore para $matricula');
      }
    } catch (e) {
      print('[DEBUG] Erro ao salvar FCM token renovado: $e');
    }
  });

  print('[DEBUG] Tentando obter FCM Token inicial');
  String? fcmToken;
  try {
    fcmToken = await FirebaseMessaging.instance.getToken();
    print('[DEBUG] FCM Token inicial: $fcmToken');

    // ===== ADICIONE ESTAS LINHAS AQUI ⬇️ =====
    await FirebaseMessaging.instance.subscribeToTopic('todos_militares');
    await FirebaseMessaging.instance.subscribeToTopic('pmrr_usuarios');
    print('[DEBUG] ✅ Subscrito aos tópicos: todos_militares, pmrr_usuarios');
    // ===== ATÉ AQUI ⬆️ =====
  } catch (e) {
    print('[DEBUG] Erro ao obter FCM Token inicial: $e');
  }

  print('[DEBUG] Inicializando datas e rodando app');
  initializeDateFormatting().then((_) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => Auth()),
        ],
        child: const MyApp(),
      ),
    );
  });
}

// ---------- WIDGET AUXILIAR ----------

class BlurOverlay extends StatelessWidget {
  const BlurOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        // CORRIGIDO: Use withValues() ao invés de withOpacity()
        child: Container(color: Colors.black.withValues(alpha: 0.25)),
      ),
    );
  }
}

// ---------- APP ROOT ----------

// Coloque essa variável global (pode ser definida fora da classe MyApp)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _needBlur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupFirebaseListeners();
    // _setupMethodChannel();
    ScreenshotRecordingDetector.detectionStream.listen((DetectionEvent event) {
      if (!mounted) return;
      if (Platform.isAndroid) return;
      if (Platform.isIOS) {
        if (event.type == CaptureType.screenshot) {
          setState(() => _needBlur = true);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _needBlur = false);
          });
          return;
        }
        final recording = event.isRecording ?? false;
        setState(() => _needBlur = recording);
      }
    });

    // Aguarda o primeiro frame antes de verificar a permissão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  void _setupFirebaseListeners() {
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print('[DEBUG] ===== getInitialMessage =====');
        print('[DEBUG] App foi aberto via notificação: ${message.data}');
        _processNotification(message);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('[DEBUG] ===== FOREGROUND MESSAGE RECEBIDO =====');
      print('[DEBUG] Message ID: ${message.messageId}');
      print('[DEBUG] Data: ${message.data}');
      print('[DEBUG] Notification: ${message.notification?.toMap()}');

      await _processNotification(message);
      print('[DEBUG] ===== FOREGROUND MESSAGE PROCESSADO =====');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[DEBUG] ===== onMessageOpenedApp INICIADO =====');
      print('[DEBUG] App foi aberto através de notificação: ${message.data}');
      _processNotification(message);
    });
  }

  // // ADICIONE ESTE MÉTODO DE TESTE:
  // void _testNotificationSystem() async {
  //   print('[DEBUG] === TESTE DO SISTEMA DE NOTIFICAÇÕES ===');
  //   try {
  //     final testNotification = NotificationModel(
  //       title: 'Teste Sistema',
  //       body: 'Verificando se Provider funciona',
  //       timestamp: DateTime.now(),
  //       clicked: false,
  //       route: '/test',
  //     );

  //     if (mounted) {
  //       final provider =
  //           Provider.of<NotificationProvider>(context, listen: false);
  //       await provider.addNotification(testNotification);
  //       print('[DEBUG] TESTE: Notificação de teste adicionada com sucesso');
  //     }
  //   } catch (e) {
  //     print('[DEBUG] TESTE: Erro ao adicionar notificação de teste: $e');
  //   }
  // }

  Future<void> _processNotification(RemoteMessage message) async {
    print('[DEBUG] _processNotification iniciado');

    RemoteNotification? notification = message.notification;

    // NO iOS, SEMPRE exiba notificação local quando em foreground
    // if (notification != null || Platform.isIOS) {
    //   final title =
    //       notification?.title ?? message.data['title'] ?? 'Notificação';
    //   final body =
    //       notification?.body ?? message.data['body'] ?? 'Nova mensagem';

    //   print('[DEBUG] Exibindo notificação local: $title');

    //   await flutterLocalNotificationsPlugin.show(
    //     DateTime.now().millisecondsSinceEpoch ~/ 1000,
    //     title,
    //     body,
    //     NotificationDetails(
    //       android: AndroidNotificationDetails(
    //         'default_channel',
    //         'Notificações',
    //         importance: Importance.max,
    //         priority: Priority.high,
    //         icon: '@mipmap/ic_launcher',
    //       ),
    //       iOS: const DarwinNotificationDetails(
    //         presentAlert: true,
    //         presentBadge: true,
    //         presentSound: true,
    //       ),
    //     ),
    //     payload: message.data.toString(),
    //   );
    //   print('[DEBUG] Notificação local exibida com sucesso');
    // }

    // Criar notificação para salvar
    final n = NotificationModel(
      title: notification?.title ?? message.data['title'] ?? '',
      body: notification?.body ?? message.data['body'] ?? '',
      timestamp: DateTime.now(),
      clicked: false,
      route: message.data['route'],
    );
    print('[DEBUG] Criada notificação local: ${n.toMap()}');

    // Salvar via Provider se o contexto estiver disponível
    if (mounted) {
      print('[DEBUG] Widget está mounted, tentando acessar Provider');
      try {
        final notificationProvider =
            Provider.of<NotificationProvider>(context, listen: false);
        await notificationProvider.addNotification(n);
        print('[DEBUG] addNotification() chamado no Provider com sucesso');
      } catch (e) {
        print('[DEBUG] ERRO ao chamar addNotification: $e');
      }
    } else {
      print(
          '[DEBUG] Contexto não disponível, salvando diretamente via Service');
      try {
        await NotificationService().addNotification(n);
        print('[DEBUG] Notificação salva diretamente via Service');
      } catch (e) {
        print('[DEBUG] ERRO ao salvar via Service: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[DEBUG] App resumed, verificando notificações perdidas');

      // FORÇA RELOAD COMPLETO quando voltar (SEM depender de clique)
      Timer(const Duration(milliseconds: 800), () async {
        if (mounted) {
          print('[DEBUG] Forçando reload das notificações após resume');
          final provider =
              Provider.of<NotificationProvider>(context, listen: false);
          await provider.loadNotifications();
          print('[DEBUG] ✅ Notificações recarregadas automaticamente');

          // Força rebuild da UI
          setState(() {});
        }
      });

      // MANTÉM a verificação de getInitialMessage (para quando clica)
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          print(
              '[DEBUG] Processando notificação perdida do background via clique');
          _processNotification(message);
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNotificationPermission();
      });
    }
  }

  Future<void> _checkNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    // Se o sistema retornar autorizado, atualiza o Store e não exibe o diálogo.
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      var userData = await Store.getMap('userData');
      if (userData['notificationsChoice'] != 'authorized') {
        userData['notificationsChoice'] = 'authorized';
        await Store.saveMap('userData', userData);
      }
      return;
    }

    // Se não estiver autorizado, exibe o diálogo
    _showPermissionDialog();
  }

  void _showPermissionDialog() {
    // Usa a chave do Navigator para obter um contexto apropriado
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;

    Future.delayed(Duration.zero, () {
      if (Platform.isIOS) {
        QuickAlert.show(
          context: dialogContext,
          type: QuickAlertType.info,
          title: 'Permissão para Notificações',
          text:
              'Para continuar recebendo atualizações, permita o envio de notificações.',
          confirmBtnText: 'Ativar',
          confirmBtnTextStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          confirmBtnColor: Colors.blue,
          showCancelBtn: true,
          cancelBtnText: 'Cancelar',
          cancelBtnTextStyle: const TextStyle(fontSize: 12),
          onConfirmBtnTap: () async {
            Navigator.of(dialogContext).pop();
            var userData = await Store.getMap('userData');
            userData['notificationsChoice'] = 'denied';
            await Store.saveMap('userData', userData);
            AppSettings.openAppSettings();
          },
          onCancelBtnTap: () async {
            Navigator.of(dialogContext).pop();
            var userData = await Store.getMap('userData');
            userData['notificationsChoice'] = 'denied';
            await Store.saveMap('userData', userData);
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(
                content: Text(
                  "Notificações desativadas. Você pode ativar nas configurações.",
                  style: TextStyle(fontSize: 12),
                ),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      } else {
        QuickAlert.show(
          context: dialogContext,
          type: QuickAlertType.info,
          title: 'Permissão para Notificações',
          text:
              'Para continuar recebendo atualizações, permita o envio de notificações.',
          confirmBtnText: 'Ativar',
          confirmBtnTextStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          confirmBtnColor: Colors.blue,
          showCancelBtn: true,
          cancelBtnText: 'Cancelar',
          cancelBtnTextStyle: const TextStyle(fontSize: 12),
          onConfirmBtnTap: () async {
            Navigator.of(dialogContext).pop();
            // Em Android, se o usuário desativou manualmente, abra as configurações
            AppSettings.openAppSettings();
          },
          onCancelBtnTap: () async {
            Navigator.of(dialogContext).pop();
            var userData = await Store.getMap('userData');
            userData['notificationsChoice'] = 'denied';
            await Store.saveMap('userData', userData);
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(
                content: Text(
                  "Notificações desativadas. Você pode ativar nas configurações.",
                  style: TextStyle(fontSize: 12),
                ),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Auth(),
      child: MaterialApp(
        navigatorKey: navigatorKey, // Define a navigatorKey aqui.
        debugShowCheckedModeBanner: false,
        title: 'SouPMRR',
        builder: (context, child) => Stack(
          children: [
            child!,
            if (_needBlur) const BlurOverlay(),
          ],
        ),
        home: const AuthOrHome(),
        routes: {
          AppRoutes.AUTH_PAGE: (_) => const AuthPage(),
          AppRoutes.BIOMETRIC_AUTH_PAGE: (_) => const BiometricAuthPage(),
          AppRoutes.PAGE_MILITAR: (_) => const PageMilitar(),
          AppRoutes.CONFIGURACOES: (_) => const Configuracoes(),
          AppRoutes.PLANODEFERIAS: (_) => const PlanoDeFerias(),
          AppRoutes.HOME_PAGE: (_) => HomePage(),
          AppRoutes.PLANTAO: (_) => PlantaoPage(),
          AppRoutes.NOTIFICATIONS_PAGE: (_) => NotificationsPage(),
          AppRoutes.AJUDA_PAGE: (_) => AjudaPage(),
          AppRoutes.CONTRACHEQUE_PAGE: (_) => Contracheque(),
          AppRoutes.CONFIGURA_PLANTAO: (_) => ConfiguraPlantao(),
          AppRoutes.DECLARACOES_PAGE: (_) => DeclaracoesPage(),
          AppRoutes.CERTIDOES_PAGE: (_) => CertidoesPage(),
          AppRoutes.MAPA_DA_FORCA: (_) => MapadaforcaPage(),
          AppRoutes.DECLARACAODEBENS: (_) {
            final ano = ModalRoute.of(_)?.settings.arguments as String;
            return DeclaracaoBensPage(ano: ano);
          },
          AppRoutes.DECLARACAO_BENS_PDF_PAGE: (_) {
            final ano = ModalRoute.of(_)?.settings.arguments as String;
            return DeclaracaoBensPdfPage(ano: ano);
          },
          AppRoutes.DECLARACAO_PARENTESCO_PAGE: (_) {
            final ano = ModalRoute.of(_)?.settings.arguments as String;
            return DeclaracaoParentescoPage(ano: ano);
          },
          AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE: (_) {
            final ano = ModalRoute.of(_)?.settings.arguments as String;
            return DeclaracaoAcumuloCargosPage(ano: ano);
          },
          AppRoutes.ENDERECO_PAGE: (_) {
            final militar = ModalRoute.of(_)?.settings.arguments as Militar;
            return EdicaoEnderecoPage(militar: militar);
          },
          AppRoutes.DETALHES_MAPA_FORCA_PAGE: (_) {
            final args =
                ModalRoute.of(_)?.settings.arguments as MapBuscaDetalhesModel;
            return DetalhesMapaForcaPage(dadosBusca: args);
          },
          AppRoutes.DETALHES_MAPA_FORCA_COMANDO_PAGE: (_) {
            final args =
                ModalRoute.of(_)?.settings.arguments as MapBuscaDetalhesModel;
            return DetalhesMapaForcaComandoPage(dadosBusca: args);
          },
          AppRoutes.PAGE_VIEW_CONTRACHEQUE: (_) {
            final mes =
                ModalRoute.of(_)?.settings.arguments as MesesContracheque;
            return PageContracheque(mesSelecionado: mes);
          },
          AppRoutes.MILITAR_DETALHE_FULL_PAGE: (_) {
            final matricula = ModalRoute.of(_)?.settings.arguments as String;
            return MilitarDetalheFullPage(matricula: matricula);
          },
          AppRoutes.LEGISLACOES_PAGE: (_) => LegislacoesPage(),
          AppRoutes.PLANO_DE_FERIAS_PAGE: (_) => PlanoDeFeriasPage(),
          AppRoutes.POP_PAGE: (_) => PopPage(),
        },
      ),
    );
  }
}
