import 'package:projetonovo/core/ambiente_app.dart';
import 'package:projetonovo/core/log/registro_log.dart';
import 'package:projetonovo/features/carreira/carreira_page.dart';
import 'package:projetonovo/features/chamados/chamados_page.dart';
import 'package:projetonovo/features/comunicados/comunicados_page.dart';
import 'package:projetonovo/features/documentos/documentos_page.dart';
import 'package:projetonovo/features/documentos/validar_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
//teste de commit

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:projetonovo/features/avisos/avisos_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projetonovo/core/navegacao/titulos_rota.dart';
import 'widgets/vidro.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projetonovo/pages/calculo_inatividade_page.dart';
import 'package:projetonovo/pages/certidoes_page.dart';
import 'package:projetonovo/pages/legislacoes_page.dart';
import 'package:projetonovo/pages/militar_detalhe_full_page.dart';
import 'package:projetonovo/pages/planodeferias.dart';
import 'package:projetonovo/core/navegacao/guarda_funcao.dart';
import 'package:projetonovo/app/registro_modulos.dart';
import 'package:projetonovo/pages/pop_page.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/utils/theme_provider.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'utils/protecao_tela.dart';
import 'package:screenshot_recording_detector/models/detection_event.dart';
import 'package:screenshot_recording_detector/screenshot_recording_detector.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart'; // Adicione esta linha

// ======== Páginas e models ======== //
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/models/meses_contracheque_model.dart';
import 'package:projetonovo/models/militar.dart';
import 'package:projetonovo/features/ajuda/preciso_de_ajuda_page.dart';
import 'package:projetonovo/features/feedback/sugestoes_page.dart';
import 'package:projetonovo/pages/auth_or_home.dart';
import 'package:projetonovo/pages/auth_page.dart';
import 'package:projetonovo/pages/biometric_auth_page.dart';
import 'package:projetonovo/pages/configura_plantao.dart';
import 'package:projetonovo/pages/alterar_senha_page.dart';
import 'package:projetonovo/pages/configuracoes.dart';
import 'package:projetonovo/pages/confirm_email.dart';
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
import 'package:projetonovo/pages/aviso_detalhe_page.dart';
import 'package:projetonovo/models/aviso_model.dart';
import 'dart:convert';

import 'firebase_options.dart';
import 'models/auth_model.dart';
import 'widgets/aviso_rapido.dart';
import 'package:http/http.dart' as http;
import 'widgets/dialogo_confirmacao.dart';
import 'widgets/convite_biometria.dart' show entradaEmAndamento;
import 'core/design/entrada_inicio.dart' show EntradaInicio;
import 'features/comunicados/comunicados_page.dart' show aberturaEmAndamento;
import 'vitrine/vitrine.dart';
import 'core/erros/captura_global.dart';
import 'core/log/iniciar_log.dart';
import 'core/config/app_config.dart';
import 'core/rede/api_client.dart';
import 'core/sessao/sessao.dart';
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
  Map<String, dynamic>? aviso,
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
      // Aviso do SIGE leva os campos dele no payload, para o toque no banner
      // abrir a mesma tela do toque no push.
      payload: aviso != null ? '$kPrefixoPayloadAviso${jsonEncode(aviso)}' : route,
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

Future<void> main() => modoVitrine
    // Capturas das lojas: o SIGRH responde com o militar fictício (lib/vitrine).
    ? http.runWithClient(_iniciar, clienteVitrine)
    : _iniciar();

Future<void> _iniciar() async {
  AmbienteApp.inicio; // marca o começo, para o tempo de abertura do log
  WidgetsFlutterBinding.ensureInitialized();

  // Antes de tudo: o que escapar de um `try` daqui em diante vai para o log
  // com código AP-FATAL (SouPMRR 2.2, fase 0).
  instalarCapturaGlobal();

  // ── Por que o runApp vem cedo ───────────────────────────────────────────
  //
  // Antes, o `runApp` era a última linha desta função, depois de uns dez
  // `await` — Firebase, canal de notificação, notificações locais pedindo
  // permissão do iOS, `requestPermission` de push, busca do token FCM com
  // um laço de espera de três segundos, inscrição em tópicos. Nada disso
  // protegido por `try`.
  //
  // Isso significa que nenhum pixel era desenhado até tudo terminar. No
  // aparelho do revisor da Apple, em release, o resultado foi "o app trava
  // ao abrir": caixas de permissão do sistema aparecendo sobre uma tela
  // vazia, e o iOS encerra o app que demora a entregar o primeiro quadro.
  // Em debug no simulador isso nunca aparece, porque esse limite não existe
  // ali e as permissões se comportam de outro jeito.
  //
  // Agora só fica aqui o que o primeiro quadro realmente exige, com guarda
  // e prazo. O resto corre depois, sem segurar a tela.

  // O NotificationProvider liga no Firestore já no construtor, e ele é
  // criado junto com a árvore — por isso o Firebase não dá para adiar. Com
  // prazo: sem rede, o app abre do mesmo jeito e tenta de novo depois.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('[INIT] Firebase não subiu no startup: $e');
  }

  // Local, rápido, sem rede. Mas se falhar, qualquer DateFormat com locale
  // quebra — então é guardado e não derruba a abertura.
  try {
    await initializeDateFormatting();
  } catch (e) {
    debugPrint('[INIT] initializeDateFormatting falhou: $e');
  }

  // A cascata da Início espera o convite do Face ID/digital fechar.
  EntradaInicio.aguardar = entradaEmAndamento;

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

  // Daqui para baixo nada bloqueia a tela.
  unawaited(_prepararServicos());
}

/// Tudo que o app precisa, mas que o primeiro quadro não espera.
///
/// Cada passo é independente e guardado: um que falhe não impede os
/// seguintes, e nenhum deles derruba o app.
Future<void> _prepararServicos() async {
  Future<void> passo(String nome, Future<void> Function() corpo) async {
    try {
      await corpo();
    } catch (e) {
      debugPrint('[INIT] $nome falhou: $e');
    }
  }

  // Primeiro, para registrar a abertura e o que vier depois.
  await passo('log do app', () async {
    await iniciarLog(api: ApiClient(), matricula: () => Sessao.matriculaAtual);
  });

  // Só no iOS: no Android a captura já é barrada pelo FLAG_SECURE nas telas
  // protegidas, e o detector do pacote derrubava o app no Android 16 a cada
  // captura de tela (consulta a content://media/external, que o sistema
  // passou a recusar; o app fechava sozinho).
  if (Platform.isIOS) {
    await passo('detector de captura', () async {
      await ScreenshotRecordingDetector.initialize();
    });
  }

  await passo('canal de notificação', () async {
    const canal = AndroidNotificationChannel(
      'default_channel',
      'Notificações',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canal);
  });

  await passo('notificações locais', () async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    // As três permissões saem em `false` de propósito. Em `true`, o plugin
    // abre a caixa do sistema no instante da inicialização — era a segunda
    // caixa a aparecer sobre a tela vazia. Quem pede é
    // `_checkNotificationPermission`, depois do primeiro quadro e com uma
    // explicação antes.
    const initIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: initAndroid, iOS: initIOS),
      onDidReceiveNotificationResponse: (resp) {
        debugPrint(
            '[DEBUG] Notificação local clicada – payload: ${resp.payload}');
        tratarPayloadLocal(resp.payload);
      },
    );
  });

  await passo('handler de background FCM', () async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  });

  // Em foreground o banner é exibido pelo stream do Firestore, não pelo FCM,
  // para não duplicar com o banner nativo do SO.
  await passo('apresentação em foreground', () async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  });

  // Sem `requestPermission` aqui. Pedir permissão não é tarefa de
  // inicialização: `_checkNotificationPermission` já faz isso depois do
  // primeiro quadro, mostrando antes um diálogo do app que explica por quê.

  await passo('listener de token', () async {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        final userData = await Store.getMap('userData');
        final matricula = userData['matricula'];
        if (matricula != null && matricula.toString().isNotEmpty &&
            !modoVitrine) {
          await FirebaseFirestore.instance
              .collection('militares')
              .doc(matricula.toString())
              .set({'fcmToken': token}, SetOptions(merge: true));
          debugPrint('[FCM] ✅ Token renovado salvo → militares/$matricula');
          await DispositivoApi().registrar(
              token: token,
              matricula: matricula.toString(),
              senhaMd5: md5.convert(utf8.encode(await Sessao.instancia.senha() ?? '')).toString());
        }
      } catch (e) {
        debugPrint('[FCM] ❌ ERRO ao salvar token renovado: $e');
      }
    });
  });

  // O token pode demorar: no simulador o getToken lança até o AppDelegate
  // gravar o token nativo. Esperar por isso está certo **aqui**, fora do
  // caminho do primeiro quadro — antes, esse laço segurava a abertura por
  // até três segundos.
  await passo('token inicial', () async {
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken() falhou: $e');
    }
    if (token == null || token.isEmpty) {
      for (var i = 0; i < 6 && (token == null || token.isEmpty); i++) {
        token = await Store.getString('native_fcm_token');
        if (token.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    debugPrint(token != null && token.isNotEmpty
        ? '[FCM] ✅ Token inicial obtido'
        : '[FCM] ⚠️ Token não obtido no startup');
  });

  await passo('inscrição em tópicos', () async {
    await FirebaseMessaging.instance.subscribeToTopic('todos_militares');
    await FirebaseMessaging.instance.subscribeToTopic('pmrr_usuarios');
    debugPrint('[FCM] ✅ Inscrito nos tópicos');
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

/// Aviso de evento vindo por push com o app aberto, no padrão de avisos do
/// app (avisoRapido), com a cor e o ícone do evento.
void mostrarToastEvento(String mensagem, Color cor, {IconData? icone}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final ctx = navigatorKey.currentContext;
  avisoRapidoGlobal(
    messenger,
    ctx != null ? Theme.of(ctx) : ThemeData(),
    titulo: mensagem,
    tipo: TipoAviso.info,
    icone: icone ?? Icons.notifications_rounded,
    cor: cor,
  );
}

/// Aviso curto com a cor do `tipo_evento`, quando o push chega com o app
/// aberto. O toque não passa por aqui: vai para [tratarToqueNotificacao], que
/// abre a tela do aviso.
void tratarTipoEvento(Map<String, dynamic> data) {
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
      break;

    case 'removido':
      // Alerta laranja; removido da lista.
      mostrarToastEvento('Você foi removido de uma escala.', laranja,
          icone: Icons.person_remove_rounded);
      break;

    case 'escalado':
      // Badge verde; abrir escala ao tocar.
      mostrarToastEvento('Você foi escalado para um serviço.', verde,
          icone: Icons.assignment_turned_in_rounded);
      break;

    case 'svi_inscrito':
      // Confirmação; navegar para "Meus Voluntários".
      mostrarToastEvento('Inscrição no SVI confirmada.', verde,
          icone: Icons.more_time_rounded);
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

const kPrefixoPayloadAviso = 'aviso:';

/// Último push tratado: o `getInitialMessage` devolve a mesma mensagem a cada
/// volta do app ao primeiro plano, e o aviso não pode reabrir sozinho.
String? _ultimoPushTratado;

/// Toque num push (app fechado, em segundo plano ou aberto). Aviso do SIGE
/// (com `notificacao_id` ou `tipo_evento`) abre a tela do aviso; o resto segue
/// a `route`, como sempre.
void tratarToqueNotificacao(RemoteMessage message) {
  final id = message.messageId;
  if (id != null && id == _ultimoPushTratado) return;
  _ultimoPushTratado = id;
  final data = message.data;
  // "Aberto" no histórico de envios do painel (§9.2); a API marca pelo id.
  registrar('push.abrir', dados: {
    if (data['notificacao_soupm'] != null) 'notificacao_soupm': '${data['notificacao_soupm']}',
    if (data['route'] != null) 'rota': '${data['route']}',
    if (data['tipo_evento'] != null) 'tipo_evento': '${data['tipo_evento']}',
  });
  if (AvisoAberto.ehDoSige(data)) {
    abrirAviso(AvisoAberto.doPush(
      data,
      tituloSistema: message.notification?.title,
      corpoSistema: message.notification?.body,
    ));
    return;
  }
  navegarPorNotificacao(data['route']?.toString());
}

/// Toque no banner local (app aberto).
void tratarPayloadLocal(String? payload) {
  if (payload != null && payload.startsWith(kPrefixoPayloadAviso)) {
    try {
      final data = jsonDecode(payload.substring(kPrefixoPayloadAviso.length))
          as Map<String, dynamic>;
      abrirAviso(AvisoAberto.doPush(data));
      return;
    } catch (e) {
      debugPrint('[AVISO] payload local inválido: $e');
      return;
    }
  }
  navegarPorNotificacao(payload);
}

/// Abre a tela do aviso do SIGE.
///
/// Com o app fechado, o `getInitialMessage` responde antes de o MaterialApp
/// existir, e o aviso se perdia (conferido no simulador em 21/10/2026). Por
/// isso espera o Navigator por até 10 s antes de desistir.
void abrirAviso(AvisoAberto aviso, {int tentativa = 0}) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    if (tentativa < 40) {
      Future.delayed(const Duration(milliseconds: 250),
          () => abrirAviso(aviso, tentativa: tentativa + 1));
    } else {
      debugPrint('[AVISO] AV-NAV Navigator indisponível em 10 s — '
          'aviso ${aviso.notificacaoId} não aberto.');
    }
    return;
  }
  nav.pushNamed(AppRoutes.AVISO, arguments: aviso);
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

/// A rota que uma notificação pode abrir, ou nula. Aceita (2.2):
/// - as rotas antigas da lista acima (pushes das 2.1.x);
/// - a rota de qualquer módulo do registro (`/com/central`, `/rh/carreira`);
/// - a chave da função ou o nome antigo dela (`rh.contracheques`,
///   `contracheques`, `/contracheques`), que é o que o painel manda.
/// Antes só valia a lista fixa: as rotas novas eram ignoradas e o "Abrir"
/// do aviso não fazia nada (teste de 25/10/2026). A rota passa pela guarda
/// de função (`protegerRotas`): função bloqueada mostra o motivo, não a tela.
String? rotaDaNotificacao(String? rota) {
  if (rota == null || rota.trim().isEmpty) return null;
  final r = rota.trim();
  if (kRotasNotificacaoPermitidas.contains(r)) return r;
  final chave = r.startsWith('/') ? r.substring(1) : r;
  final m = registroModulos.porRota(r) ?? registroModulos.porChave(chave);
  // Rota que precisa de argumentos (análise salarial) não abre por push.
  if (m == null || m.rota == null || m.chave == 'rh.contracheques.grafico') return null;
  return m.rota;
}

/// Navega para a rota indicada por uma notificação, de forma segura.
/// Ignora rotas vazias, desconhecidas ou que exijam argumentos.
void navegarPorNotificacao(String? rota) {
  final r = rotaDaNotificacao(rota);
  if (r == null) {
    if (rota != null && rota.trim().isNotEmpty) {
      print('[NOTIF] Rota "${rota.trim()}" desconhecida — navegação ignorada.');
    }
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
    if (Platform.isIOS) ScreenshotRecordingDetector.detectionStream.listen((DetectionEvent event) {
      if (!mounted) return;
      // Fora de uma tela protegida não há o que esconder nem o que avisar.
      if (!ProtecaoTela.ativa.value) return;
      if (Platform.isAndroid) return;
      if (Platform.isIOS) {
        if (event.type == CaptureType.screenshot) {
          setState(() => _needBlur = true);
          mostrarToastEvento(
            ProtecaoTela.aviso,
            Colors.orange.shade800,
            icone: Icons.no_photography_rounded,
          );
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _needBlur = false);
          });
          return;
        }
        final recording = event.isRecording ?? false;
        if (recording) {
          mostrarToastEvento(
            ProtecaoTela.aviso,
            Colors.orange.shade800,
            icone: Icons.no_photography_rounded,
          );
        }
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
            aviso: notif.dadosAviso,
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
        tratarToqueNotificacao(message);
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
      // Push silencioso de configuração (§4.6): o painel publicou algo;
      // relê o app_config sem mostrar nada.
      if (message.data['tipo'] == 'config') {
        if (mounted) {
          final auth = Provider.of<Auth>(context, listen: false);
          await carregarAppConfig(api: ApiClient(), matricula: auth.matricula, senha: auth.password);
        }
        return;
      }
      registrar('push.receber', dados: {
        if (message.data['notificacao_soupm'] != null) 'notificacao_soupm': '${message.data['notificacao_soupm']}',
        if (message.data['tipo_evento'] != null) 'tipo_evento': '${message.data['tipo_evento']}',
      });
      // Toast colorido em foreground conforme o tipo_evento do payload.
      tratarTipoEvento(message.data);
      print('[DEBUG] ===== FOREGROUND MESSAGE PROCESSADO =====');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[DEBUG] ===== onMessageOpenedApp INICIADO =====');
      print('[DEBUG] App aberto pelo toque na notificação: ${message.data}');
      // App em background e foi trazido ao foreground pelo toque.
      tratarToqueNotificacao(message);
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
          tratarToqueNotificacao(message);
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

    // O militar já respondeu à pergunta do sistema (recusou): perguntar de
    // novo com a janela do app logo depois era repetido. Dá para ligar em
    // Perfil › Notificações.
    // No Android, "denied" é também o estado antes de perguntar: lá vale só
    // a resposta guardada logo abaixo.
    if (Platform.isIOS && settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Quem já respondeu "Cancelar" não é perguntado de novo a cada volta ao
    // app (antes o pedido voltava sempre que o app saía do fundo); dá para
    // ligar em Perfil › Notificações.
    // A resposta fica numa chave própria: o login regrava o userData inteiro
    // e apagava a escolha (o pedido voltava logo depois de entrar).
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_chaveNotificacaoRecusada) == true) return;

    // Se não estiver autorizado, exibe o diálogo
    _showPermissionDialog();
  }

  bool _pedindoPermissao = false;
  static const _chaveNotificacaoRecusada = 'notificacao_pedido_recusado';

  void _showPermissionDialog() {
    // Usa a chave do Navigator para obter um contexto apropriado
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;

    // iOS e Android caíam em dois blocos idênticos de alerta; o que muda é
    // só o que acontece ao confirmar.
    if (_pedindoPermissao) return;
    _pedindoPermissao = true;
    Future.delayed(Duration.zero, () async {
      // Não abre por cima do login em andamento, do convite do Face ID nem do
      // comunicado de abertura: espera até 1 min a tela ficar livre.
      for (var i = 0; i < 200 && (entradaEmAndamento.value || aberturaEmAndamento.value); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (!dialogContext.mounted) {
        _pedindoPermissao = false;
        return;
      }
      final querAtivar = await dialogoConfirmacao(
        dialogContext,
        titulo: 'Permissão para Notificações',
        mensagem: 'Para continuar recebendo atualizações, permita o envio de '
            'notificações.',
        textoConfirmar: 'Ativar',
        icone: Icons.notifications_active_rounded,
      );

      _pedindoPermissao = false;
      if (querAtivar) {
        // Agora sim o pedido do sistema (no Android 13+ também). Se o sistema
        // não perguntar mais (recusado antes), leva aos ajustes do app.
        final r = await FirebaseMessaging.instance.requestPermission();
        if (r.authorizationStatus == AuthorizationStatus.denied) {
          AppSettings.openAppSettings();
        }
        return;
      }

      var userData = await Store.getMap('userData');
      userData['notificationsChoice'] = 'denied';
      await Store.saveMap('userData', userData);
      try {
        (await SharedPreferences.getInstance()).setBool(_chaveNotificacaoRecusada, true);
      } catch (_) {/* sem preferências, pergunta de novo na próxima vez */}
      if (!dialogContext.mounted) return;
      avisoInfo(dialogContext, 'Notificações desativadas',
          texto: 'Você pode ativar nas configurações.');
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
          navigatorObservers: [TitulosRota.novo()],
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'SouPMRR',
          // Sem estes delegates, qualquer showDatePicker com locale pt_BR
          // lança exceção por falta de MaterialLocalizations.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
          theme: theme,
          darkTheme: AppTheme.build(isDark: true, isSuperUser: isSuperUser),
          themeMode: themeProvider.themeMode,
          // O fundo do app é pintado aqui, uma única vez: cor base do tema
          // mais manchas suaves. Como as telas têm Scaffold transparente, as
          // superfícies translúcidas deixam esse fundo transparecer.
          builder: (context, child) => Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                ),
                child: FundoSuave(child: child!),
              ),
              if (_needBlur) const BlurOverlay(),
            ],
          ),
          home: const AuthOrHome(),
          routes: protegerRotas({
            AppRoutes.AUTH_PAGE: (_) => const AuthPage(),
            AppRoutes.BIOMETRIC_AUTH_PAGE: (_) => const BiometricAuthPage(),
            AppRoutes.PAGE_MILITAR: (_) => const PageMilitar(),
            AppRoutes.CONFIGURACOES: (_) => const Configuracoes(),
            AppRoutes.CONTA_EMAIL: (_) => const ConfirmEmailScreen(),
            AppRoutes.CONTA_SENHA: (_) => const AlterarSenhaPage(),
            AppRoutes.BIOMETRIA: (_) => const BiometriaPage(),
            AppRoutes.NOTIF_PREFERENCIAS: (_) => const NotificacoesPreferenciasPage(),
            AppRoutes.APARENCIA: (_) => const AparenciaPage(),
            AppRoutes.PLANODEFERIAS: (_) => const PlanoDeFerias(),
            AppRoutes.HOME_PAGE: (_) => MainShell(),
            AppRoutes.PLANTAO: (_) => PlantaoPage(),
            AppRoutes.ESCALAS: (_) => const EscalasPage(),
            AppRoutes.ESCALA_DETALHE: (_) => const EscalaDetalhePage(),
            AppRoutes.AVISO: (ctx) => AvisoDetalhePage(
                  aviso: ModalRoute.of(ctx)!.settings.arguments as AvisoAberto,
                ),
            AppRoutes.SVI_ESCALAS: (_) => const SviEscalasPage(),
            AppRoutes.SVI_MEUS_VOLUNTARIOS: (_) =>
                const SviMeusVoluntariosPage(),
            AppRoutes.NOTIFICATIONS_PAGE: (_) => NotificationsPage(),
            // 2.2: o "Preciso de ajuda" guiado substitui a página antiga
            // (WhatsApp e e-mail saíram: suporte é por chamado, §8).
            AppRoutes.AJUDA_PAGE: (_) => const PrecisoDeAjudaPage(),
            AppRoutes.FEEDBACK: (_) => const SugestoesPage(),
            AppRoutes.CHAMADOS: (_) => const MeusChamadosPage(),
            AppRoutes.CARREIRA: (_) => const CarreiraPage(),
            AppRoutes.DOCUMENTOS: (_) => const DocumentosPage(),
            AppRoutes.VALIDAR: (_) => const ValidarDocumentoPage(),
            AppRoutes.COMUNICADOS: (_) => const CentralComunicadosPage(),
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
            AppRoutes.CALCULO_INATIVIDADE_PAGE: (_) =>
                const CalculoInatividadePage(),
          }),
        );
      },
    );
  }
}
