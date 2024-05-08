import 'package:flutter/material.dart';

import 'package:table_calendar/table_calendar.dart';

import '../models/events_model.dart';
import '../models/plantao_model.dart';

// ignore: must_be_immutable
class CalendarWidget extends StatefulWidget {
  PlantaoModel plantao;
  Function alteraDiaSel;
  EventsModel eventos;

  CalendarWidget(
      {required this.plantao,
      required Function this.alteraDiaSel,
      required this.eventos});

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime dataFoco = DateTime.now();
  DateTime? diaSelecionado;

  final _turno = ['1º Turno', '2º Turno', '24 Horas'];
  String? _turnoSelecionado;

  @override
  Widget build(BuildContext context) {
    double hieght = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.height;

    return Column(
      children: [
        SizedBox(
          // color: Colors.grey,
          height: hieght * 0.54,
          child: Column(
            children: [
              TableCalendar(
                selectedDayPredicate: (day) {
                  return isSameDay(diaSelecionado, day);
                },
                eventLoader: ((day) {
                  List<Text> list = [];
                  return widget.eventos.events[day]?.toList() ?? list;
                }),
                calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                        color: Color.fromARGB(255, 100, 132, 245),
                        shape: BoxShape.circle)),
                onDaySelected: ((selectedDay, focusedDay) {
                  if (widget.plantao.escalaServico.length > 2) {
                    setState(() {
                      diaSelecionado = selectedDay;
                      dataFoco = focusedDay;
                    });
                  }

                  widget.alteraDiaSel(selectedDay);
                }),
                focusedDay: dataFoco,
                onPageChanged: (focusedDay) {
                  mudaDataFoco(focusedDay);
                },
                locale: 'pt_BR',
                headerStyle: const HeaderStyle(titleCentered: true),
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                firstDay: DateTime.utc(1950, 01, 01),
                lastDay: DateTime.utc(2050, 01, 01),
                calendarBuilders: CalendarBuilders(
                  todayBuilder: (context, day, focusedDay) {
                    if (day.month != dataFoco.month) {
                      return Container(color: Colors.transparent);
                    }
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return null;
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    return Center(child: Text(day.day.toString()));
                  },
                  markerBuilder: (context, day, events) {
                    bool mesmoMes = day.month == dataFoco.month ? true : false;
                    if (widget.plantao.plantaoConfigurado == false) return null;
                    Color cor = Colors.red;

                    if (widget.plantao.escalaServico.containsKey(day)) {
                      cor = escolheCor(
                          widget.plantao.escalaServico[day] ?? Turno.diario,
                          mesmoMes);
                    }

                    return widget.plantao.escalaServico.containsKey(day)
                        ? Container(
                            width: width * 0.032,
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 2,
                                color: cor,
                              ),
                              shape: BoxShape.circle,
                            ),
                          )
                        : null;
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: hieght * 0.05),
        diaSelecionado != null &&
                widget.plantao.escalaServico.containsKey(diaSelecionado) ==
                    false
            ? Container(
                padding: EdgeInsets.all(2),
                height: hieght * 0.10,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.eventos.events.containsKey(diaSelecionado) == false
                        ? Container(
                            height: hieght * 0.05,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Dia Selecionado: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                SizedBox(width: width * 0.01),
                                Text(
                                  '${diaSelecionado!.day}/${diaSelecionado!.month}/${diaSelecionado!.year}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          )
                        : Container(),
                    widget.eventos.events.containsKey(diaSelecionado)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                                Text(
                                  'Serviço voluntário: ${widget.eventos.events[diaSelecionado!]!.first}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(width: width * 0.15),
                                Container(
                                  width: width * 0.09,
                                  height: hieght * 0.04,
                                  child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor:
                                            Color.fromARGB(255, 59, 101, 255),
                                      ),
                                      onPressed: removerSvi,
                                      child: Text(
                                        'Excluir',
                                        style: TextStyle(fontSize: 10),
                                      )),
                                ),
                                SizedBox(height: hieght * 0.01)
                              ])
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: width * 0.09,
                                height: hieght * 0.04,
                                child: ElevatedButton(
                                  style: ButtonStyle(
                                    padding: MaterialStateProperty.resolveWith(
                                        (states) {
                                      return EdgeInsets.all(2);
                                    }),
                                    backgroundColor:
                                        MaterialStateProperty.resolveWith(
                                            (states) {
                                      return Color.fromARGB(255, 59, 101, 255);
                                    }),
                                    textStyle:
                                        MaterialStateProperty.resolveWith(
                                            (states) {
                                      return TextStyle(fontSize: 12);
                                    }),
                                  ),
                                  onPressed: adicionarSvi,
                                  child: Text('Novo SVI'),
                                ),
                              ),
                            ],
                          )
                  ],
                ),
              )
            : Container(
                height: hieght * 0.14,
              ),
      ],
    );
  }

  adicionarSvi() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: ((context, setState) {
          return AlertDialog(
            content: Container(
              width: MediaQuery.of(context).size.height * 0.70,
              height: MediaQuery.of(context).size.height * 0.25,
              child: Column(
                children: [
                  Text(
                    'Selecione o turno do SVI',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Dia: ${diaSelecionado!.day}/${diaSelecionado!.month}/${diaSelecionado!.year}',
                    // style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  DropdownButton<String>(
                      hint: const Text("Selecione o turno"),
                      style: const TextStyle(color: Colors.blue),
                      alignment: AlignmentDirectional.center,
                      items: _turno.map((String dropDownStringItem) {
                        return DropdownMenuItem<String>(
                          alignment: AlignmentDirectional.center,
                          value: dropDownStringItem,
                          child: Text(dropDownStringItem),
                        );
                      }).toList(),
                      onChanged: ((novoTurnoSelecionado) {
                        _dropDownTurnoSelected(novoTurnoSelecionado!);

                        setState(() {
                          _turnoSelecionado = novoTurnoSelecionado;
                        });
                      }),
                      value: _turnoSelecionado),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: Colors.red, minimumSize: Size(10, 10)),
                onPressed: () {
                  _turnoSelecionado = null;
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
                  onPressed: _turnoSelecionado != null
                      ? () async {
                          await salvaSvi();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(
                    'Salvar',
                    style: TextStyle(color: Colors.white),
                  ))
            ],
          );
        }));
      },
    );
  }

  salvaSvi() async {
    await widget.eventos.savePrefs();
    setState(() {
      widget.eventos.events[diaSelecionado!] = [_turnoSelecionado!];
    });
    await widget.eventos.savePrefs();
    _turnoSelecionado = null;
  }

  void _dropDownTurnoSelected(String novoItem) {
    setState(() {
      _turnoSelecionado = novoItem;
    });
  }

  removerSvi() async {
    setState(() {
      widget.eventos.events.remove(diaSelecionado!);
    });
    await widget.eventos.savePrefs();
  }

  mudaDataFoco(DateTime d) {
    dataFoco = d;
    setState(() {});
  }

  Color escolheCor(Turno t, bool m) {
    if (m == false) return Colors.transparent;
    if (t == Turno.diurno) return Colors.blue;
    if (t == Turno.noturno) return Colors.purple.shade900;
    if (t == Turno.diario) return Colors.purple;
    if (t == Turno.giro) return Colors.blue;

    return Colors.grey;
  }
}
