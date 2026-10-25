import 'package:flutter/material.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';

import '../models/events_model.dart';
import '../models/plantao_model.dart';
import '../utils/app_routes.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/vidro.dart';
import '../widgets/dialogo_confirmacao.dart';
import '../core/design/arte_cartao.dart';
import '../utils/app_theme.dart';
import '../core/erros/falha_de.dart';
import '../core/erros/estado_erro.dart';

// ignore: must_be_immutable
class PlantaoPage extends StatefulWidget {
  PlantaoModel plantao = PlantaoModel();
  PlantaoPage({Key? key}) : super(key: key);

  @override
  _PlantaoPageState createState() => _PlantaoPageState();
}

class _PlantaoPageState extends State<PlantaoPage> {
  DateTime dataFoco = DateTime.now();

  DateTime? diaSelecionado;
  EventsModel eventos = EventsModel();

  @override
  void initState() {
    carregaEventos();
    super.initState();
  }

  carregaEventos() async {
    await eventos.initPrefs();
  }

  @override
  Widget build(BuildContext context) {
    double hieght = MediaQuery.of(context).size.height;

    // late bool? carregouDados;

    // widget.plantao
    // .calculaEscalaRuaPadrao(DateTime.utc(2023, 03, 15), Turno.diurno);

    return FutureBuilder(
        future: widget.plantao.tryGetPlantao(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator.adaptive(),
            );
          } else if (snapshot.hasError) {
            return FundoSuave(
                child: Scaffold(
                    appBar: CustomAppBar(title: 'Meu Plantao'),
                    body: EstadoErro(
                        falha:
                            falhaDe('ES', snapshot.error, tela: 'op.plantao'),
                        tela: 'op.plantao')));
          } else {
            return FundoSuave(
                child: Scaffold(
              appBar: CustomAppBar(title: 'Meu Plantao'),
              body: Container(
                child: Column(
                  children: [
                    CalendarWidget(
                      plantao: widget.plantao,
                      alteraDiaSel: alteraDiaSelecionado,
                      eventos: eventos,
                    ),
                    SizedBox(height: hieght * 0.02),
                    widget.plantao.plantaoConfigurado == false
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: CartaoVidro(
                              arte: Arte.de('operacional'),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    Icon(Icons.event_busy_outlined,
                                        size: AppIconSize.md,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                        child:
                                            Text('Nenhuma escala configurada')),
                                  ]),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                            AppRoutes.CONFIGURA_PLANTAO);
                                      },
                                      child: const Text('Configurar Escala')),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: CartaoVidro(
                              arte: Arte.de('operacional'),
                              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(TextSpan(children: [
                                      const TextSpan(
                                          text: 'Escala configurada: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextSpan(
                                          text: widget.plantao.getTipoEscala()),
                                    ])),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.error,
                                      minimumSize: const Size(48, 44),
                                    ),
                                    onPressed: () async {
                                      await openDialogExcluiEscala();
                                    },
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: AppIconSize.sm),
                                    label: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              // drawer: Drawerpersonalizado(),
            ));
          }
        });
  }

  alteraDiaSelecionado(DateTime dia) {
    diaSelecionado = dia;
  }

  openDialogExcluiEscala() async {
    final ok = await dialogoConfirmacao(
      context,
      titulo: 'Excluir a escala?',
      mensagem:
          'A escala ${widget.plantao.getTipoEscala()} sai deste aparelho.',
      textoConfirmar: 'Excluir',
      icone: Icons.delete_outline_rounded,
      cor: Theme.of(context).colorScheme.error,
      arte: Arte.de('operacional'),
    );
    if (!ok) return;
    await widget.plantao.excluiEscalaMemoria();
    await eventos.deletePrefs();
    if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.PLANTAO);
  }
}
