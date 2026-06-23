import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:projetonovo/widgets/HomeContrachequeCard.dart';
import 'package:projetonovo/widgets/HomePlanoFeriasCard.dart';
import 'package:projetonovo/widgets/card_tempo_servico.dart';
import 'package:projetonovo/widgets/carouselSlider.dart';
import 'package:projetonovo/widgets/grid_menu.dart';
import 'package:projetonovo/widgets/widget_dicas_app.dart';

// ── HomeBody ─────────────────────────────────────────────────────────────────
// Conteúdo da aba "Início" dentro do MainShell.
// Não tem Scaffold — o appBar e o bottomNavBar são do MainShell.
class HomeBody extends StatefulWidget {
  const HomeBody({Key? key}) : super(key: key);

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // preserva estado ao trocar de aba

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      await Permission.storage.request();
      if (sdkInt >= 30) {
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      debugPrint('getPermissions error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Comandante / Sub-Comandante ──────────────────────────────────
          WidgetCarouselSlider(),

          const SizedBox(height: 8),

          // ── Balão de dicas / avisos ──────────────────────────────────────
          WidgetDicasApp(),

          const SizedBox(height: 10),

          // ── Widgets de resumo ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                CardTempoServico(),
                const SizedBox(height: 10),
                const HomeContrachequeCard(),
                const SizedBox(height: 10),
                const HomePlanoFeriasCard(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Menu de funcionalidades (grid 3 colunas) ─────────────────────
          HorizontalMenu(),

          const SizedBox(height: 20),

          // ── Rodapé DTI ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/imagens/dti.jpeg',
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HomePage ──────────────────────────────────────────────────────────────────
// Mantida por compatibilidade com rotas existentes.
// Redireciona para o MainShell (que contém o HomeBody na aba 0).
class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HomeBody();
  }
}
