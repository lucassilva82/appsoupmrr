import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:projetonovo/models/auth_model.dart';

class DeclaracaoParentescoPage extends StatefulWidget {
  final String ano;

  const DeclaracaoParentescoPage({Key? key, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoParentescoPage> createState() =>
      _DeclaracaoParentescoPageState();
}

class _DeclaracaoParentescoPageState extends State<DeclaracaoParentescoPage> {
  bool? possuiParentesco;
  List<dynamic> parentes = [];
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cargoController = TextEditingController();
  String? parentescoId;
  bool isLoading = true;

  final Map<String, String> grausParentesco = {
    '1': 'Cônjuge',
    '2': 'Filho(a)',
    '3': 'Pai',
    '4': 'Mãe',
    '5': 'Irmão/Irmã',
    '6': 'Avô/Avó',
    '7': 'Neto(a)',
    '8': 'Tio(a)',
    '9': 'Sobrinho(a)',
    '10': 'Primo(a)',
    '11': 'Outro',
  };

  @override
  void initState() {
    super.initState();
    _fetchParentescos();
  }

  Future<void> _fetchParentescos() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscaparentescos.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          setState(() {
            parentes = data['parentescos'] ?? [];
            if (parentes.length == 1 &&
                parentes[0]['nome_parente'] == null &&
                parentes[0]['parentesco_id'] == null &&
                parentes[0]['cargo'] == null) {
              possuiParentesco = false; // Escolha "NÃO" automaticamente
            } else {
              possuiParentesco = parentes.isNotEmpty;
            }
          });
        } else {
          setState(() {
            parentes = [];
            possuiParentesco = null;
          });
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Erro',
          text: 'Erro ao buscar parentescos: ${response.statusCode}',
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

  Future<void> _inserirParentesco(String cpf, bool temParentesco) async {
    if (temParentesco) {
      if (nomeController.text.isEmpty ||
          cargoController.text.isEmpty ||
          parentescoId == null) {
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

    final Map<String, String> params = {
      'cpf': cpf,
      'ano': widget.ano,
      'dataEnvio': DateTime.now().toIso8601String(),
    };

    if (temParentesco) {
      params['nome'] = nomeController.text;
      params['idParentesco'] = parentescoId!;
      params['cargo'] = cargoController.text;
    }

    final uri =
        Uri.https('pmrr.net', '/flutter/sigrh/insereparentesco.php', params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Sucesso',
            text: temParentesco
                ? 'Parentesco adicionado com sucesso!'
                : 'Declarou: "não possuo parentesco na administracao pública" registrado!',
          );
          // Atualizar apenas a lista de parentescos
          await _fetchParentescos();
          if (temParentesco) {
            setState(() {
              nomeController.clear();
              cargoController.clear();
              parentescoId = null;
            });
          }
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Erro',
            text: data['message'] ?? 'Erro ao inserir parentesco.',
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

  Future<void> _excluirParentesco(int id) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Excluir Parentesco',
      text: 'Deseja realmente excluir este parentesco?',
      confirmBtnText: 'Sim',
      cancelBtnText: 'Não',
      onConfirmBtnTap: () async {
        Navigator.of(context).pop(); // Fecha o QuickAlert de confirmação

        final url =
            'https://pmrr.net/flutter/sigrh/excluiparentesco.php?id=$id';

        QuickAlert.show(
          context: context,
          type: QuickAlertType.loading,
          title: 'Excluindo...',
        );

        try {
          final response = await http.get(Uri.parse(url));

          Navigator.of(context).pop(); // Fecha o indicador de carregamento

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['code'] == 1) {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.success,
                title: 'Sucesso',
                text: 'Parentesco excluído com sucesso!',
              );
              setState(() {
                parentes.removeWhere((parente) => parente['id'] == id);
                if (parentes.isEmpty) {
                  possuiParentesco = null;
                }
              });
            } else {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                title: 'Erro',
                text: data['message'] ?? 'Erro ao excluir parentesco.',
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
          Navigator.of(context)
              .pop(); // Fecha o indicador de carregamento em caso de erro
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

  void _onNaoClicked() async {
    final auth = Provider.of<Auth>(context, listen: false);
    await _inserirParentesco(auth.cpf!, false);
    setState(() {
      possuiParentesco = false;
    });
  }

  void _onSimClicked() {
    setState(() {
      possuiParentesco = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
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
        ),
        title: const Text(
          'Declaração de Parentesco',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : possuiParentesco == null
              ? Container(
                  padding: EdgeInsets.only(top: 15),
                  child: Column(
                    children: [
                      Container(
                        alignment: Alignment.center,
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
                        height: MediaQuery.of(context).size.height * 0.11,
                        child: const Text(
                          'É cônjuge, companheiro ou parente em linha reta, colateral ou por afinidade até o terceiro grau...\n(Súmula Vinculante nº 13 - STF)',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.03),
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.lightBlue,
                              const Color.fromARGB(255, 25, 161, 13),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                        height: MediaQuery.of(context).size.height * 0.07,
                        child: const Text(
                          'Possui algum familiar até o terceiro grau na Administração Pública Estadual?',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.01),
                      ElevatedButton(
                        onPressed: _onNaoClicked,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Nao.'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _onSimClicked,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Sim, possuo vínculo familiar'),
                      ),
                    ],
                  ),
                )
              : possuiParentesco == false
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Container(
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
                              children: [
                                const Text(
                                  'Declaração Enviada: Não possuo parentesco.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      color:
                                          Color.fromARGB(255, 157, 254, 160)),
                                ),
                                Icon(
                                  Icons.check,
                                  color: Colors.green,
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (parentes.isNotEmpty)
                          ElevatedButton(
                            onPressed: () =>
                                _excluirParentesco(parentes.first['id']),
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
                  : Column(
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        Container(
                          alignment: Alignment.center,
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height * 0.05,
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
                          child: Text(
                            'Preencha com os dados do seu familiar.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        TextField(
                          controller: nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do familiar',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: cargoController,
                          decoration: const InputDecoration(
                            labelText: 'Cargo que ele ocupa',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: parentescoId,
                          onChanged: (value) {
                            setState(() {
                              parentescoId = value;
                            });
                          },
                          items: grausParentesco.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          decoration: const InputDecoration(
                            labelText: 'Grau de Parentesco',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _inserirParentesco(auth.cpf!, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Adicionar Parentesco',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: parentes.length,
                            itemBuilder: (context, index) {
                              final parente = parentes[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                      parente['nome_parente'] ?? 'Sem Nome'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Grau: ${grausParentesco[parente['parentesco_id']?.toString()] ?? "Desconhecido"}',
                                      ),
                                      Text(
                                        'Cargo: ${parente['cargo'] ?? 'Desconhecido'}',
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _excluirParentesco(parente['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
