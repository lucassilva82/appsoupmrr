// =================  lib/pages/mapadaforca_page.dart  =================
import 'package:flutter/material.dart';
import 'package:projetonovo/models/map_busca_detalhes_model.dart';
import 'package:projetonovo/pages/detalhes_mapa_forca_page.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import '../widgets/widget_graficos.dart';
import '../widgets/widget_mapa_geral.dart';
import '../widgets/widget_grandes_comandos.dart';

enum Modo { graficos, mapaGeral, grandesComandos }

class MapadaforcaPage extends StatefulWidget {
  const MapadaforcaPage({super.key});

  @override
  State<MapadaforcaPage> createState() => _MapadaforcaPageState();
}

class _MapadaforcaPageState extends State<MapadaforcaPage> {
  Modo _modo = Modo.mapaGeral;

  @override
  Widget build(BuildContext context) {
    const primary = Colors.lightBlue;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Mapa da Força'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 5),

            // ---------- BANNER ----------
            _bannerTotal(context),

            // ---------- NOVO CAMPO DE BUSCA ----------
            const SizedBox(height: 8),
            _campoBusca(context),

            const SizedBox(height: 12),

            // ---------- BOTÕES ----------
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.04,
              child: Row(
                children: [
                  _botao('Gráficos', Modo.graficos, primary),
                  _botao('Mapa Geral', Modo.mapaGeral, primary),
                  _botao('Grandes Comandos', Modo.grandesComandos, primary),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---------- CONTEÚDO DINÂMICO ----------
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: _body(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // WIDGET – CAMPO DE BUSCA
  // ------------------------------------------------------------------
  Widget _campoBusca(BuildContext ctx) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.042,
      child: TextFormField(
        readOnly: true, // impede digitação e aciona apenas o onTap
        onTap: () {
          // TODO: redirecionar para a sua página de pesquisa
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => DetalhesMapaForcaPage(
                    dadosBusca: MapBuscaDetalhesModel(
                        idSituacao: "",
                        descricao: "- Busca Geral",
                        postoGraduacao: [],
                        quantidade: ""))),
          );
        },
        decoration: InputDecoration(
          hintText: 'Pesquisar militar por nome...',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.grey.shade200,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // RESTO DA SUA LÓGICA MANTIDA
  // ------------------------------------------------------------------
  Widget _body() {
    switch (_modo) {
      case Modo.graficos:
        return const WidgetGraficos();
      case Modo.mapaGeral:
        return const WidgetMapaGeral();
      case Modo.grandesComandos:
        return const WidgetGrandesComandos();
    }
  }

  Expanded _botao(String t, Modo m, Color c) {
    final ativo = _modo == m;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ativo ? c : Colors.grey.shade300,
            foregroundColor: ativo ? Colors.white : Colors.black87,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () => setState(() => _modo = m),
          child: Text(t,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _bannerTotal(BuildContext ctx) => Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.042,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [Colors.lightBlue, Colors.blue.shade900]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Efetivo Total Previsto: 3500 Militares',
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
      );
}
