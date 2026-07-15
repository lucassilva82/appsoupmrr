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
import 'package:projetonovo/pages/certidoes_page.dart';
import 'package:projetonovo/pages/legislacoes_page.dart';
import 'package:projetonovo/pages/militar_detalhe_full_page.dart';
import 'package:projetonovo/pages/planodeferias.dart';
import 'package:projetonovo/pages/pop_page.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/utils/theme_provider.dart';
import 'package:projetonovo/utils/app_theme.dart';
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
import 'package:projetonovo/pages/contracheque_grafico_page.dart';
import 'package:projetonovo/pages/contracheque.dart';
import 'package:projetonovo/pages/declaracao_acumulo_cargos_page.dart';
import 'package:projetonovo/pages/declaracao_bens_page.dart';
import 'package:projetonovo/pages/declaracao_parentesco_page.dart';
import 'package:projetonovo/pages/declaracoes_bens_pdf_page.dart';
import 'package:projetonovo/pages/declaracoes_page.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_comando_page.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/pages/edicao_endereco_page.dart';
import 'package:projetonovo/pages/mapa_da_forca.dart';
import 'package:projetonovo/pages/notifications_page.dart';
import 'package:projetonovo/pages/page_contracheque.dart';
import 'package:projetonovo/pages/page_militar.dart';
import 'package:projetonovo/pages/plano_de_ferias.dart';
import 'package:projetonovo/pages/plantao_page.dart';
import 'package:projetonovo/pages/escala_page.dart';
import 'package:projetonovo/pages/escala_detalhe_page.dart';
import 'package:projetonovo/pages/svi_escalas_page.dart';
import 'package:projetonovo/pages/svi_meus_voluntarios_page.dart';
import 'package:projetonovo/pages/main_shell.dart';
import 'package:projetonovo/utils/app_routes.dart';

import 'firebase_options.dart';
import 'models/auth_model.dart';
import 'package:projetonovo/data/store.dart'; // Certifique-se de que Store está acessível

// Instância global de notificações locais
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Exibe um banner local (usado quando o app está em foreground). Funciona no
/// iOS em primeiro plano e também no simulador, onde o push remoto do FCM não
/// é entregue. O histórico permanece no Firestore (fonte de verdade).
Future<void> mostrarBannerNotificacao(
  String title,
  String body, {
  String? route,
}) async {
  try {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Notificações',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
    print('[DEBUG] Banner local exibido (foreground): $title');
  } catch (e) {
    print('[DEBUG] Erro ao exibir banner local: $e');
  }
}

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

  // O histórico da lista interna é gravado no Firestore pela Cloud Function
  // (militares/{matricula}/notificacoes). O banner do sistema é exibido
  // automaticamente pelo SO a partir do payload de notificação. Nada a salvar
  // aqui — o app sincroniza o stream do Firestore ao abrir.
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
      print('[DEBUG] Notificação local clicada – payload: ${resp.payload}');
      navegarPorNotificacao(resp.payload);
    },
  );

  print('[DEBUG] 5) Registrando background handler FCM');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Em foreground NÃO deixamos o FCM apresentar o banner nativo, pois o banner
  // é exibido pelo stream do Firestore (funciona no device E no simulador).
  // Isso evita banner duplicado no iPhone real. Em background/terminado o SO
  // continua exibindo a notificação normalmente (estas opções não se aplicam).
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  // 6) Permissões iOS
  if (Platform.isIOS) {
    print('[FCM] Solicitando permissão de notificação iOS');
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] Permissão iOS: ${settings.authorizationStatus}');
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
        print(
            '[FCM] ✅ Token renovado salvo → militares/$matricula → fcmToken OK');
      }
    } catch (e) {
      print('[FCM] ❌ ERRO ao salvar token renovado: $e');
    }
  });

  // Obtém o FCM token. No iOS device físico o getToken() funciona direto.
  // No simulador, getToken() lança apns-token-not-set, mas o AppDelegate
  // captura o token nativamente e grava em UserDefaults (native_fcm_token).
  print('[FCM] ── Obtendo token inicial ──');
  String? fcmToken;
  try {
    fcmToken = await FirebaseMessaging.instance.getToken();
  } catch (e) {
    print('[FCM] getToken() falhou no startup ($e)');
  }
  if (fcmToken == null) {
    // Fallback nativo (simulador): aguarda o AppDelegate gravar o token.
    for (int i = 0; i < 6 && (fcmToken == null || fcmToken.isEmpty); i++) {
      fcmToken = await Store.getString('native_fcm_token');
      if (fcmToken.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
  if (fcmToken != null && fcmToken.isNotEmpty) {
    print('[FCM] ✅ Token inicial: ${fcmToken.substring(0, 40)}...');
  } else {
    print(
        '[FCM] ⚠️ Token não obtido no startup — onTokenRefresh/login salvarão depois.');
  }

  try {
    await FirebaseMessaging.instance.subscribeToTopic('todos_militares');
    await FirebaseMessaging.instance.subscribeToTopic('pmrr_usuarios');
    print('[FCM] ✅ Inscrito nos tópicos: todos_militares, pmrr_usuarios');
  } catch (e) {
    print('[FCM] ⚠️ Inscrição em tópicos adiada (APNs não pronto): $e');
  }

  print('[DEBUG] Inicializando datas e rodando app');
  initializeDateFormatting().then((_) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => Auth()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
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

/// Chave global do ScaffoldMessenger — permite exibir toasts (SnackBars)
/// coloridos a partir de callbacks de push, sem depender de um BuildContext.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Exibe um toast (SnackBar) colorido no topo do app.
void mostrarToastEvento(String mensagem, Color cor, {IconData? icone}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            if (icone != null) ...[
              Icon(icone, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Trata os valores do campo `tipo_evento` do payload de push (adição
/// retrocompatível: o restante do payload não mudou).
///
/// [interacao] = true quando o usuário TOCOU na notificação (app aberto pelo
/// toque / trazido do background). false quando a mensagem apenas chegou com o
/// app em foreground.
void tratarTipoEvento(Map<String, dynamic> data, {required bool interacao}) {
  final tipo = (data['tipo_evento'] ?? '').toString().trim();
  if (tipo.isEmpty) return;

  const verde = Color(0xFF059669);
  const laranja = Color(0xFFEA580C);
  const vermelho = Color(0xFFDC2626);
  const cinza = Color(0xFF475569);

  switch (tipo) {
    case 'cancelada':
      // Alerta vermelho; a escala já sai da lista de próximas ao recarregar.
      mostrarToastEvento('Uma escala foi cancelada.', vermelho,
          icone: Icons.event_busy_rounded);
      if (interacao) navegarPorNotificacao('/escalas');
      break;

    case 'removido':
      // Alerta laranja; removido da lista.
      mostrarToastEvento('Você foi removido de uma escala.', laranja,
          icone: Icons.person_remove_rounded);
      if (interacao) navegarPorNotificacao('/escalas');
      break;

    case 'escalado':
      // Badge verde; abrir escala ao tocar.
      mostrarToastEvento('Você foi escalado para um serviço.', verde,
          icone: Icons.assignment_turned_in_rounded);
      if (interacao) navegarPorNotificacao('/escalas');
      break;

    case 'svi_inscrito':
      // Confirmação; navegar para "Meus Voluntários".
      mostrarToastEvento('Inscrição no SVI confirmada.', verde,
          icone: Icons.more_time_rounded);
      if (interacao) navegarPorNotificacao('/svi/meus-voluntarios');
      break;

    case 'svi_adesao_reativada':
      mostrarToastEvento('Adesão SVI reativada.', verde,
          icone: Icons.check_circle_rounded);
      break;

    case 'svi_adesao_cancelada':
      mostrarToastEvento('Adesão SVI cancelada.', cinza,
          icone: Icons.info_rounded);
      break;

    default:
      // Valor desconhecido — ignora silenciosamente (retrocompatível).
      break;
  }
}

/// Rotas seguras para deep-link via notificação (sem argumentos obrigatórios).
/// Mantenha sincronizada com a lista entregue ao desenvolvedor web.
const Set<String> kRotasNotificacaoPermitidas = {
  '/home-page',
  '/plantao',
  '/escalas',
  '/svi/escalas',
  '/svi/meus-voluntarios',
  '/notifications-page',
  '/contracheque-page',
  '/plano-de-ferias-page',
  '/certidoes-page',
  '/declaracoes-page',
  '/legislacoes-page',
  '/pop-page',
  '/mapa-da-forca-page',
  '/ajuda-page',
  '/configuracoes',
  '/page-militar',
};

/// Navega para a rota indicada por uma notificação, de forma segura.
/// Ignora rotas vazias, desconhecidas ou que exijam argumentos.
void navegarPorNotificacao(String? rota) {
  if (rota == null || rota.trim().isEmpty) return;
  final r = rota.trim();
  if (!kRotasNotificacaoPermitidas.contains(r)) {
    print('[NOTIF] Rota "$r" não permitida/desconhecida — navegação ignorada.');
    return;
  }
  final nav = navigatorKey.currentState;
  if (nav == null) {
    print('[NOTIF] Navigator indisponível — navegação adiada.');
    return;
  }
  print('[NOTIF] Navegando para "$r" via notificação.');
  nav.pushNamed(r);
}

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
    // Banner em foreground é disparado pelo stream do Firestore (fonte de
    // verdade), e não pelo FCM. Assim funciona no iPhone real E no simulador
    // (onde o push remoto não chega). Só exibe quando o app está em foreground
    // para não duplicar com o banner nativo do SO em background.
    try {
      final notifProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      notifProvider.onNewNotificationForeground = (notif) {
        final estado = WidgetsBinding.instance.lifecycleState;
        if (estado == null || estado == AppLifecycleState.resumed) {
          mostrarBannerNotificacao(
            notif.title,
            notif.body,
            route: notif.route,
          );
        }
      };
    } catch (e) {
      print('[DEBUG] Erro ao registrar callback de banner foreground: $e');
    }

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print('[DEBUG] ===== getInitialMessage =====');
        print('[DEBUG] App aberto via notificação: ${message.data}');
        // App estava terminado e foi aberto pelo toque na notificação.
        tratarTipoEvento(message.data, interacao: true);
        navegarPorNotificacao(message.data['route']?.toString());
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('[DEBUG] ===== FOREGROUND MESSAGE RECEBIDO =====');
      print('[DEBUG] Message ID: ${message.messageId}');
      print('[DEBUG] Data: ${message.data}');
      print('[DEBUG] Notification: ${message.notification?.toMap()}');

      // Apenas garante que o provider esteja conectado ao stream. O banner em
      // foreground é exibido pelo callback do stream do Firestore, evitando
      // banners duplicados no device.
      if (mounted) {
        try {
          await Provider.of<NotificationProvider>(context, listen: false)
              .bindUser();
        } catch (e) {
          print('[DEBUG] Erro ao conectar provider no onMessage: $e');
        }
      }
      // Toast colorido em foreground conforme o tipo_evento do payload.
      tratarTipoEvento(message.data, interacao: false);
      print('[DEBUG] ===== FOREGROUND MESSAGE PROCESSADO =====');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[DEBUG] ===== onMessageOpenedApp INICIADO =====');
      print('[DEBUG] App aberto pelo toque na notificação: ${message.data}');
      // App em background e foi trazido ao foreground pelo toque.
      tratarTipoEvento(message.data, interacao: true);
      navegarPorNotificacao(message.data['route']?.toString());
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
          print('[DEBUG] Notificação clicada (resume) — navegando por rota');
          navegarPorNotificacao(message.data['route']?.toString());
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
    return Consumer2<ThemeProvider, Auth>(
      builder: (context, themeProvider, auth, _) {
        final isDark = themeProvider.isDark;
        final isSuperUser = auth.isSuperUser;
        final theme = AppTheme.build(isDark: isDark, isSuperUser: isSuperUser);
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'SouPMRR',
          theme: theme,
          darkTheme: AppTheme.build(isDark: true, isSuperUser: isSuperUser),
          themeMode: themeProvider.themeMode,
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
            AppRoutes.HOME_PAGE: (_) => MainShell(),
            AppRoutes.PLANTAO: (_) => PlantaoPage(),
            AppRoutes.ESCALAS: (_) => const EscalasPage(),
            AppRoutes.ESCALA_DETALHE: (_) => const EscalaDetalhePage(),
            AppRoutes.SVI_ESCALAS: (_) => const SviEscalasPage(),
            AppRoutes.SVI_MEUS_VOLUNTARIOS: (_) =>
                const SviMeusVoluntariosPage(),
            AppRoutes.NOTIFICATIONS_PAGE: (_) => NotificationsPage(),
            AppRoutes.AJUDA_PAGE: (_) => AjudaPage(),
            AppRoutes.CONTRACHEQUE_PAGE: (_) => Contracheque(),
            AppRoutes.CONTRACHEQUE_GRAFICO_PAGE: (ctx) {
              final args =
                  ModalRoute.of(ctx)!.settings.arguments as Map<String, String>;
              return ContrachequeGraficoPage(
                  cpf: args['cpf']!, ano: args['ano']!);
            },
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
        );
      },
    );
  }
}
