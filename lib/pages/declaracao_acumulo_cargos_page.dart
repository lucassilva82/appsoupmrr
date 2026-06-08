import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:projetonovo/models/auth_model.dart';

class DeclaracaoAcumuloCargosPage extends StatefulWidget {
  final String ano;
  const DeclaracaoAcumuloCargosPage({Key? key, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoAcumuloCargosPage> createState() =>
      _DeclaracaoAcumuloCargosPageState();
}

class _DeclaracaoAcumuloCargosPageState
    extends State<DeclaracaoAcumuloCargosPage> {
  bool? acumulaCargo;
  List<dynamic> cargos = [];
  final TextEditingController cargoController = TextEditingController();
  final TextEditingController orgaoController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCargos();
  }

  Future<void> _fetchCargos() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscaacumulocargos.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          setState(() {
            cargos = data['cargos'] ?? [];
            // Se só tiver 1 registro e for tudo nulo/vazio, entendemos que "NÃO" foi declarado
            if (cargos.length == 1 &&
                (cargos[0]['cargo'] == null || cargos[0]['cargo'] == '') &&
                (cargos[0]['orgao'] == null || cargos[0]['orgao'] == '')) {
              acumulaCargo = false;
            } else {
              // Se tiver registros válidos, exibe a tela de cargos
              acumulaCargo = cargos.isNotEmpty;
            }
          });
        } else {
          // Quando code != 1 ou não retornou dados
          setState(() {
            cargos = [];
            acumulaCargo = null;
          });
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Erro',
          text: 'Erro ao buscar cargos: ${response.statusCode}',
        );
      }
    } catch (e) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Erro inesperado: $e',
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _inserirCargo(String cpf, bool temAcumulo) async {
    // Se o usuário declara SIM, então cargo e orgao são obrigatórios
    if (temAcumulo) {
      if (cargoController.text.isEmpty || orgaoController.text.isEmpty) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.warning,
          title: 'Campos obrigatórios',
          text: 'Preencha todos os campos antes de enviar!',
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    final auth = Provider.of<Auth>(context, listen: false);
    final Map<String, String> params = {
      'cpf': cpf,
      'ano': widget.ano,
      'dataEnvio': DateTime.now().toIso8601String(),
    };

    if (temAcumulo) {
      params['cargo'] = cargoController.text;
      params['orgao'] = orgaoController.text;
    } else {
      params['cargo'] = '';
      params['orgao'] = '';
    }

    final uri =
        Uri.https('pmrr.net', '/flutter/sigrh/insereacumulocargos.php', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Sucesso',
            text: temAcumulo
                ? 'Cargo adicionado com sucesso!'
                : 'Declaração de NÃO ACÚMULO de cargos registrada!',
          );
          // Atualiza a lista
          await _fetchCargos();
          if (temAcumulo) {
            setState(() {
              cargoController.clear();
              orgaoController.clear();
            });
          } else {
            setState(() {
              acumulaCargo = false;
            });
          }
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Erro',
            text: data['message'] ?? 'Erro ao inserir declaração de cargos.',
          );
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Erro',
          text: 'Erro ao conectar ao servidor. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Erro inesperado: $e',
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _excluirCargo(int id) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Excluir Cargo',
      text: 'Deseja realmente excluir este cargo?',
      confirmBtnText: 'Sim',
      cancelBtnText: 'Não',
      onConfirmBtnTap: () async {
        Navigator.of(context).pop(); // Fecha o diálogo de confirmação

        final url =
            'https://pmrr.net/flutter/sigrh/excluiacumulocargos.php?id=$id';

        QuickAlert.show(
          context: context,
          type: QuickAlertType.loading,
          title: 'Excluindo...',
        );

        try {
          final response = await http.get(Uri.parse(url));

          Navigator.of(context).pop(); // Fecha o loading

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['code'] == 1) {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.success,
                title: 'Sucesso',
                text: 'Cargo excluído com sucesso!',
              );
              setState(() {
                cargos.removeWhere((cargo) => cargo['id'] == id);
                if (cargos.isEmpty) {
                  // Se não houver mais registros, volta para a tela de pergunta (acumulaCargo = null)
                  acumulaCargo = null;
                }
              });
            } else {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                title: 'Erro',
                text: data['message'] ?? 'Erro ao excluir cargo.',
              );
            }
          } else {
            QuickAlert.show(
              context: context,
              type: QuickAlertType.error,
              title: 'Erro',
              text: 'Erro ao conectar ao servidor.',
            );
          }
        } catch (e) {
          Navigator.of(context).pop();
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Erro',
            text: 'Erro inesperado: $e',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.lightBlue, Colors.blue.shade900],
              begin: Alignment.centerLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
        title: const Text(
          'Declaração de Acúmulo de Cargos',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : acumulaCargo == null
              // Pergunta Inicial
              ? Container(
                  padding: const EdgeInsets.only(top: 15),
                  child: Column(
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.lightBlue,
                              Colors.blue,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                        height: MediaQuery.of(context).size.height * 0.11,
                        child: const Text(
                          'Você acumula cargo público? Caso tenha mais de um vínculo público, declare aqui.',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.03),
                      ElevatedButton(
                        onPressed: () => _inserirCargo(auth.cpf!, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Não, não acumulo cargo público'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            acumulaCargo = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Sim, possuo vínculo público'),
                      ),
                    ],
                  ),
                )
              // Declarou que não acumula
              : acumulaCargo == false
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 20.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.lightBlue,
                                Colors.blue.shade900,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.topRight,
                            ),
                          ),
                          height: MediaQuery.of(context).size.height * 0.15,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Flexible(
                                child: Text(
                                  'Declaração Enviada: Não possuo acúmulo de cargo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color.fromARGB(255, 157, 254, 160),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.check,
                                color: Colors.green,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (cargos.isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              // Excluir a declaração (ou seja, excluir o registro inserido)
                              _excluirCargo(cargos.first['id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Excluir Declaração',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    )
                  // Declarou que acumula
                  : Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Column(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.07,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.lightBlue,
                                  Colors.blue.shade900,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.topRight,
                              ),
                            ),
                            child: const Text(
                              'Preencha com os dados do seu cargo público.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextField(
                              controller: cargoController,
                              decoration: const InputDecoration(
                                labelText: 'Cargo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextField(
                              controller: orgaoController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Órgão (Ex: Prefeitura, Estado, etc.)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _inserirCargo(auth.cpf!, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              'Adicionar Cargo',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: cargos.length,
                              itemBuilder: (context, index) {
                                final cargo = cargos[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(cargo['cargo'] ?? 'Sem Cargo'),
                                    subtitle: Text(
                                        'Órgão: ${cargo['orgao'] ?? 'Desconhecido'}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        _excluirCargo(cargo['id']);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
