import 'package:flutter/material.dart';

import '../models/events_model.dart';
import '../models/plantao_model.dart';
import '../utils/app_routes.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/drawer_personalizado.dart';

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
    double width = MediaQuery.of(context).size.height;

    // late bool? carregouDados;

    // widget.plantao
    // .calculaEscalaRuaPadrao(DateTime.utc(2023, 03, 15), Turno.diurno);

    return FutureBuilder(
        future: widget.plantao.tryGetPlantao(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Text('Ocorreu um erro');
          } else {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Meu Plantao'),
              ),
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
                        ? Column(
                            children: [
                              Text(
                                '* Nenhuma escala configurada',
                                style: TextStyle(color: Colors.red),
                              ),
                              SizedBox(height: hieght * 0.03),
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.CONFIGURA_PLANTAO);
                                  },
                                  child: Text('Configurar Escala')),
                            ],
                          )
                        : Column(
                            children: [
                              Container(
                                height: hieght * 0.08,
                                padding: EdgeInsets.symmetric(horizontal: 15),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color.fromARGB(125, 87, 87, 224),
                                      Color.fromARGB(226, 14, 1, 246),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.topRight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Escala Configurada: ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                        SizedBox(width: width * 0.01),
                                        Text(
                                          widget.plantao.getTipoEscala(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: width * 0.09,
                                      height: hieght * 0.04,
                                      child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            primary: Color.fromARGB(
                                                255, 59, 101, 255),
                                          ),
                                          onPressed: () async {
                                            await openDialogExcluiEscala();
                                          },
                                          child: Text(
                                            'Excluir',
                                            style: TextStyle(fontSize: 11),
                                          )),
                                    )
                                  ],
                                ),
                              ),
                              SizedBox(height: hieght * 0.02),
                            ],
                          ),
                  ],
                ),
              ),
              drawer: Drawerpersonalizado(),
            );
          }
        });
  }

  alteraDiaSelecionado(DateTime dia) {
    diaSelecionado = dia;
  }

  openDialogExcluiEscala() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Deseja excluir a escala: ${widget.plantao.getTipoEscala()}?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red, minimumSize: Size(10, 10)),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.green, minimumSize: Size(10, 10)),
              onPressed: () async {
                await widget.plantao.excluiEscalaMemoria();
                await eventos.deletePrefs();
                Navigator.of(context).pushReplacementNamed(AppRoutes.PLANTAO);
              },
              child: Text(
                'Excluir',
                style: TextStyle(color: Colors.white),
              ))
        ],
      ),
    );
  }
}
