import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projetonovo/utils/app_routes.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:supercharged/supercharged.dart';

class DeclaracaoWidget extends StatefulWidget {
  final String cpf;
  final String ano;

  const DeclaracaoWidget({Key? key, required this.cpf, required this.ano})
      : super(key: key);

  @override
  State<DeclaracaoWidget> createState() => _DeclaracaoWidgetState();
}

class _DeclaracaoWidgetState extends State<DeclaracaoWidget> {
  // Armazena se estamos carregando a primeira vez
  bool _isLoading = true;
  // Armazena mensagem de erro (se existir)
  String? _errorMessage;
  // Lista de declarações retornadas da API
  List<dynamic> _declaracoes = [];

  // Timer para atualizações periódicas
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchDeclaracoes(firstLoad: true);

    // Dispara atualizações a cada 2 segundos, sem exibir loader novamente
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Atualiza em segundo plano
      _fetchDeclaracoes(firstLoad: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Faz a busca dos dados na API.
  /// [firstLoad] define se é a primeira vez que chamamos (pra exibir loader).
  Future<void> _fetchDeclaracoes({bool firstLoad = false}) async {
    if (firstLoad) {
      setState(() => _isLoading = true);
    }
    _errorMessage = null; // Zera o erro antes de fazer nova requisição

    final url =
        'https://pmrr.net/flutter/sigrh/buscastatusdeclaracoes.php?cpf=${widget.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          final list = data['result'] as List<dynamic>;
          setState(() {
            _declaracoes = list;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Erro ao carregar dados.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Erro ao carregar dados. Código: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro inesperado: $e';
      });
    } finally {
      if (firstLoad) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Exclui a declaração (usando QuickAlert + GET).
  Future<void> _excluirDeclaracao(
    String cpf,
    int ano,
    String title,
    String id,
  ) async {
    // Mostrar alerta de confirmação usando QuickAlert
    bool confirmar = false;
    await QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Confirmação',
      text: 'Deseja realmente excluir toda a $title?',
      confirmBtnText: 'Sim',
      cancelBtnText: 'Não',
      showCancelBtn: true,
      onConfirmBtnTap: () {
        confirmar = true;
        Navigator.of(context).pop();
      },
      onCancelBtnTap: () {
        confirmar = false;
        Navigator.of(context).pop();
      },
    );

    if (!confirmar) return;

    String url = '';
    // URL para a exclusão
    if (id == '1') {
      url = 'https://pmrr.net/flutter/sigrh/excluibens.php?cpf=$cpf&ano=$ano';
    } else if (id == '2') {
      url =
          'https://pmrr.net/flutter/sigrh/excluipdfirpf.php?cpf=$cpf&ano=$ano';
    } else if (id == '3') {
      url =
          'https://pmrr.net/flutter/sigrh/excluitodosparentescos.php?cpf=$cpf&ano=$ano';
    } else if (id == '4') {
      url =
          'https://pmrr.net/flutter/sigrh/excluiacumulotodoscargos.php?cpf=$cpf&ano=$ano';
    }

    // Exibe um carregamento para a exclusão
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator.adaptive());
      },
    );

    try {
      final response = await http.get(Uri.parse(url));
      Navigator.of(context).pop(); // Fecha o loading

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 1) {
          QuickAlert.show(
            context: context,
            title: 'Sucesso',
            confirmBtnText: 'OK',
            type: QuickAlertType.success,
            text: 'Sua $title foi excluída com sucesso.',
            onConfirmBtnTap: () {
              Navigator.of(context).pop();
              // Dispara nova busca
              _fetchDeclaracoes();
            },
          );
        } else {
          QuickAlert.show(
            context: context,
            title: 'Erro',
            confirmBtnText: 'OK',
            type: QuickAlertType.error,
            text: data['message'] ?? 'Erro ao excluir a $title.',
          );
        }
      } else {
        QuickAlert.show(
          context: context,
          title: 'Erro',
          confirmBtnText: 'OK',
          type: QuickAlertType.error,
          text: 'Erro na exclusão da $title. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      QuickAlert.show(
        context: context,
        title: 'Erro',
        confirmBtnText: 'OK',
        type: QuickAlertType.error,
        text: 'Erro inesperado: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) Se o ano não for 2024
    if (widget.ano != '2024') {
      return const Center(
        child: Text('Ainda não é necessário enviar declarações desse ano!'),
      );
    }

    // 2) Se estamos carregando pela primeira vez
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // 3) Se deu erro
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    // 4) Se não há dados
    if (_declaracoes.isEmpty) {
      return const Center(child: Text('Nenhum dado encontrado.'));
    }

    // 5) Retorna a lista de declarações
    return _buildDeclaracoesList(_declaracoes);
  }

  Widget _buildDeclaracoesList(List<dynamic> declaracoes) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: ListView.builder(
        itemCount: declaracoes.length,
        itemBuilder: (context, index) {
          final declaracao = declaracoes[index];
          return Column(
            children: [
              _buildDeclaracaoRow(
                context,
                id: '1',
                title: 'Declaração de Bens',
                status: _mapStatus(declaracao['declaracao_bens']),
              ),
              _buildDeclaracaoRow(
                context,
                id: '2',
                title: 'Declaração de Bens (IRPF)',
                status: _mapStatus(declaracao['declaracao_bens_pdf']),
              ),
              _buildDeclaracaoRow(
                context,
                id: '3',
                title: 'Declaração de Parentesco',
                status: _mapStatus(declaracao['declaracao_parentesco']),
              ),
              _buildDeclaracaoRow(
                context,
                id: '4',
                title: 'Declaração de Acúmulo de Cargos',
                status: _mapStatus(declaracao['acumulo_cargos']),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeclaracaoRow(
    BuildContext context, {
    required String id,
    required String title,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Exemplo de "bolinha" com o ano, e título
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 25,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${widget.ano}",
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Exibe o status
          Expanded(
            flex: 1,
            child: Text(
              status.isNotEmpty
                  ? status == 'Homologado'
                      ? 'Recebido'
                      : status
                  : 'Pendente',
              style: TextStyle(
                fontSize: 12,
                color: status == 'Homologado'
                    ? Colors.green
                    : (status == 'Declarado' ? Colors.blue : Colors.red),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Renderiza botões ou ícones de acordo com o status
          if (status == 'Homologado')
            Row(
              children: [
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.remove_red_eye),
                  onPressed: () {
                    // Lógica para abrir a tela "Visualizar"
                    if (id == '1') {
                      Navigator.of(context)
                          .pushNamed(AppRoutes.DECLARACAODEBENS,
                              arguments: widget.ano)
                          .then((_) => _fetchDeclaracoes(firstLoad: false));
                    } else if (id == '2') {
                      Navigator.of(context)
                          .pushNamed(AppRoutes.DECLARACAO_BENS_PDF_PAGE,
                              arguments: widget.ano)
                          .then((_) => _fetchDeclaracoes(firstLoad: false));
                    } else if (id == '3') {
                      Navigator.of(context)
                          .pushNamed(AppRoutes.DECLARACAO_PARENTESCO_PAGE,
                              arguments: widget.ano)
                          .then((_) => _fetchDeclaracoes(firstLoad: false));
                    } else if (id == '4') {
                      Navigator.of(context)
                          .pushNamed(AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE,
                              arguments: widget.ano)
                          .then((_) => _fetchDeclaracoes(firstLoad: false));
                    }
                  },
                ),
              ],
            )
          else if (status == 'Pendente')
            ElevatedButton(
              onPressed: () {
                // Lógica para abrir a tela "Enviar"
                if (id == '1') {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.DECLARACAODEBENS,
                          arguments: widget.ano)
                      .then((_) => _fetchDeclaracoes(firstLoad: false));
                } else if (id == '2') {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.DECLARACAO_BENS_PDF_PAGE,
                          arguments: widget.ano)
                      .then((_) => _fetchDeclaracoes(firstLoad: false));
                } else if (id == '3') {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.DECLARACAO_PARENTESCO_PAGE,
                          arguments: widget.ano)
                      .then((_) => _fetchDeclaracoes(firstLoad: false));
                } else if (id == '4') {
                  Navigator.of(context)
                      .pushNamed(AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE,
                          arguments: widget.ano)
                      .then((_) => _fetchDeclaracoes(firstLoad: false));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade300,
                foregroundColor: const Color.fromARGB(255, 14, 8, 8),
                iconSize: 20,
                minimumSize: Size(50, 30),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text(
                'Enviar',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            )
          else if (status == 'Declarado')
            id == '2'
                ? Row(
                    children: [
                      IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.remove_red_eye),
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.DECLARACAO_BENS_PDF_PAGE,
                                  arguments: widget.ano)
                              .then((_) => _fetchDeclaracoes(firstLoad: false));
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Botão para excluir a declaração
                      IconButton(
                        onPressed: () {
                          _excluirDeclaracao(
                            widget.cpf,
                            int.parse(widget.ano),
                            title,
                            id,
                          );
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                      const SizedBox(width: 10),
                      // Botão de edição
                      IconButton(
                        onPressed: () {
                          if (id == '1') {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.DECLARACAODEBENS,
                                    arguments: widget.ano)
                                .then(
                                    (_) => _fetchDeclaracoes(firstLoad: false));
                          } else if (id == '2') {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.DECLARACAO_BENS_PDF_PAGE,
                                    arguments: widget.ano)
                                .then(
                                    (_) => _fetchDeclaracoes(firstLoad: false));
                          } else if (id == '3') {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.DECLARACAO_PARENTESCO_PAGE,
                                    arguments: widget.ano)
                                .then(
                                    (_) => _fetchDeclaracoes(firstLoad: false));
                          } else if (id == '4') {
                            Navigator.of(context)
                                .pushNamed(
                                    AppRoutes.DECLARACAO_ACUMULO_CARGOS_PAGE,
                                    arguments: widget.ano)
                                .then(
                                    (_) => _fetchDeclaracoes(firstLoad: false));
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.grey),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }

  // Converte o campo da API para o texto de status
  String _mapStatus(String? status) {
    switch (status) {
      case 'Não Declarado':
        return 'Pendente';
      case 'Declarado':
        return 'Declarado';
      case 'Homologado':
        return 'Homologado';
      default:
        return 'Pendente';
    }
  }
}
