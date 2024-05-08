import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  initializeDateFormatting().then((_) => runApp(const MyApp()));
  // runApp(const MyApp());
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
    // checkNotifications();
  }

  // checkNotifications() async {
  //   await Provider.of<Auth>(context, listen: false)
  //       .notificationService
  //       .checkForNotifications;
  // }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Cria uma escala de servico com uma data
      create: (_) => Auth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SouPMRR',
        // theme: ThemeData(
        //   primarySwatch: Colors.blue,
        // ),
        theme: ThemeData(
            textTheme: const TextTheme(
          headline1: TextStyle(
            fontSize: 20,
            color: MyColors.mainTextColor,
            fontWeight: FontWeight.w500,
          ),
          headline2: TextStyle(
            fontSize: 80,
            color: MyColors.mainTextColor,
            fontWeight: FontWeight.bold,
          ),
          headline3: TextStyle(
            fontSize: 27,
            color: MyColors.mainTextColor,
            fontWeight: FontWeight.bold,
          ),
          headline4: TextStyle(
            fontSize: 18,
            color: MyColors.mainSubTitileColor,
            fontWeight: FontWeight.w400,
          ),
          headline5: TextStyle(
            color: Colors.white,
            fontSize: 19,
          ),
        )),
        //home: HomePage(),
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

          // ROTA COM DADOS
          AppRoutes.ENDERECO_PAGE: (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Militar;

            return EdicaoEnderecoPage(
              militar: args,
            );
          },

          // ROTA COM DADOS
          AppRoutes.PAGE_VIEW_CONTRACHEQUE: (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments as MesesContracheque;

            return PageContracheque(
              mesSelecionado: args,
            );
          },
        },
      ),
    );
  }
}
