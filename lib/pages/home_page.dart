import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projetonovo/utils/notification_provider.dart';
import 'package:projetonovo/widgets/HomeContrachequeCard.dart';
import 'package:projetonovo/widgets/HomePlanoFeriasCard.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:projetonovo/widgets/carouselSlider.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:projetonovo/widgets/drawer_personalizado.dart';
import 'package:projetonovo/widgets/grid_menu.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controlador para páginas (se necessário)
  final PageController controller = PageController();

  @override
  void initState() {
    super.initState();
    // Garante que o carregamento ocorra após a criação do contexto
    Future.microtask(() {
      Provider.of<NotificationProvider>(context, listen: false)
          .loadNotifications();
    });
    getPermissions();
  }

  /// Pede as permissões de armazenamento (Android) de forma segura,
  /// tratando a possibilidade de `sdkInt` ser null.
  Future<bool> getPermissions() async {
    bool gotPermissions = false;

    // Se for Android, tratamos o fluxo de permissões de armazenamento.
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      try {
        final androidInfo = await deviceInfo.androidInfo;
        // `sdkInt` pode ser null em algumas ROMs/emuladores:
        final sdkInt = androidInfo.version.sdkInt;

        // Checamos a permissão de "storage" primeiro
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
          // Atualiza o status
          storageStatus = await Permission.storage.status;
        }

        // Se sdkInt não é null e >= 30, precisamos da permissão "manageExternalStorage"
        if (sdkInt != null && sdkInt >= 30) {
          var storageExternalStatus =
              await Permission.manageExternalStorage.status;
          if (!storageExternalStatus.isGranted) {
            await Permission.manageExternalStorage.request();
            storageExternalStatus =
                await Permission.manageExternalStorage.status;
          }

          // Se ambas permissões forem concedidas, marcamos `gotPermissions = true`.
          if (storageExternalStatus.isGranted && storageStatus.isGranted) {
            gotPermissions = true;
          }
        } else {
          // Se sdkInt é null ou menor que 30, confiamos apenas em "storage"
          if (storageStatus.isGranted) {
            gotPermissions = true;
          }
        }
      } catch (e) {
        // Se der erro ao obter info do device, evitamos crash
        debugPrint('Erro ao obter info do device: $e');
        // gotPermissions permanece false ou você pode assumir true se preferir
      }
    } else {
      // iOS ou outra plataforma: se não precisar de nada, pode marcar como true diretamente
      gotPermissions = true;
    }

    return gotPermissions;
  }

  @override
  Widget build(BuildContext context) {
    // Pegamos as dimensões da tela
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final auth = Provider.of<Auth>(context);

    return Scaffold(
      appBar: CustomAppBar(title: 'Olá, ${auth.nomeMilitar}'),
      drawer: DrawerPersonalizado(),
      body: Column(
        children: [
          // Área principal rolável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carousel – ajuste a altura para não ficar exagerado
                  SizedBox(
                    height: screenHeight * 0.34,
                    child: WidgetCarouselSlider(),
                  ),

                  // Card de Tempo de Serviço centralizado
                  SizedBox(
                    height: screenHeight * 0.15,
                    child: CardTempoServico(),
                  ),

                  // Contracheque Card (fixado com altura definida)
                  SizedBox(
                    height: screenHeight * 0.14,
                    child: const HomeContrachequeCard(),
                  ),

                  // Plano de Férias resumo (baixo do contracheque)
                  SizedBox(
                    height: screenHeight * 0.24,
                    child: const HomePlanoFeriasCard(),
                  ),

                  // Menu Horizontal
                  HorizontalMenu(),
                  // Caso queira adicionar outro widget, adicione abaixo...
                ],
              ),
            ),
          ),

          // Rodapé com imagem
          SizedBox(
            width: screenWidth,
            height: screenHeight * 0.07, // ajuste conforme desejar
            child: Image.asset(
              'assets/imagens/dti.jpeg',
              fit: BoxFit.fitWidth,
            ),
          ),
        ],
      ),
    );
  }
}
