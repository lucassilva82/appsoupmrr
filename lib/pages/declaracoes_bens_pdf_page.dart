import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';

/// Função para converter o status numérico para o nome correspondente
String statusText(int status) {
  switch (status) {
    case 1:
      return 'Declarado';
    case 2:
      return 'Recebido';
    case 3:
      return 'Retificado';
    case 4:
      return 'Retificaçao Atual';
    default:
      return 'Desconhecido';
  }
}

/// Modelo para representar cada declaração retornada da API
class DeclaracaoEntry {
  final String nome;
  final DateTime dataEnvio;
  final String status; // status recebido da API, após conversão para nome.
  final String pdfBase64;

  DeclaracaoEntry({
    required this.nome,
    required this.dataEnvio,
    required this.status,
    required this.pdfBase64,
  });
}

class DeclaracaoBensPdfPage extends StatefulWidget {
  final String ano;

  const DeclaracaoBensPdfPage({Key? key, required this.ano}) : super(key: key);

  @override
  State<DeclaracaoBensPdfPage> createState() => _DeclaracaoBensPdfPageState();
}

class _DeclaracaoBensPdfPageState extends State<DeclaracaoBensPdfPage> {
  File? selectedFile;
  bool isLoading = true;

  // Lista de declarações obtidas da API
  List<DeclaracaoEntry> _listaDeclaracoes = [];

  // Controla se o painel de envio (retificação) deve ser exibido
  bool _showUploadSection = false;

  // Estilo de botão unificado
  final ButtonStyle _defaultButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.blue, // Cor de fundo padrão
    textStyle: const TextStyle(
      color: Colors.white, // Cor do texto
      fontSize: 16, // Tamanho de fonte padrão
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 12,
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkPdfExists();
  }

  /// Busca as declarações (PDFs) para o CPF e ano informado.
  Future<void> _checkPdfExists() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscapdfirpf.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Resposta da API: $data"); // Para debug

        if (data['code'] == 1) {
          if (data.containsKey('declaracoes') &&
              data['declaracoes'] is List &&
              (data['declaracoes'] as List).isNotEmpty) {
            // A API retornou uma lista de declarações
            List<dynamic> listData = data['declaracoes'];
            _listaDeclaracoes = listData.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return DeclaracaoEntry(
                nome: "Documento ${index + 1}",
                dataEnvio: DateTime.tryParse(item['data_envio'] ?? "") ??
                    DateTime.now(),
                status: statusText(item['status']),
                pdfBase64: item['pdf'] ?? "",
              );
            }).toList();
          } else if (data['pdf'] != null) {
            // Modo antigo: apenas um PDF foi retornado; transforma em lista com 1 item
            final base64Pdf = data['pdf'] as String;
            _listaDeclaracoes = [
              DeclaracaoEntry(
                nome: "Documento 1",
                dataEnvio: DateTime.tryParse(data['data_envio'] ?? "") ??
                    DateTime.now(),
                status: statusText(data['status']),
                pdfBase64: base64Pdf,
              )
            ];
          } else {
            _listaDeclaracoes = [];
          }
        } else {
          _listaDeclaracoes = [];
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Erro',
          text: 'Erro ao buscar declarações. Código: ${response.statusCode}',
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
        if (_listaDeclaracoes.isNotEmpty) _showUploadSection = false;
      });
    }
  }

  /// Abre o seletor de arquivos para escolher um PDF.
  Future<void> _pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      // Verifica se o tamanho do arquivo é maior que 5MB (5 * 1024 * 1024 bytes)
      if (result.files.single.size > 5 * 1024 * 1024) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Tamanho Excedido',
          text:
              'O PDF deve ser de até 5MB, por favor dimua o tamanho e envie novamente.',
        );
        return;
      }

      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    } else {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'Atenção',
        text: 'Nenhum arquivo foi selecionado.',
      );
    }
  }

  /// Envia o PDF selecionado para o servidor.
  Future<void> _uploadPdfFile(String cpf) async {
    if (selectedFile == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'Erro',
        text: 'Selecione um arquivo PDF antes de enviar.',
      );
      return;
    }

    final url = 'https://pmrr.net/flutter/sigrh/enviapdfirpf.php';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['cpf'] = cpf
        ..fields['ano'] = widget.ano
        ..files.add(
          await http.MultipartFile.fromPath('pdf', selectedFile!.path),
        );

      final response = await request.send();
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = Map<String, dynamic>.from(json.decode(responseData));

        if (data['code'] == 1) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Sucesso',
            text: 'PDF enviado com sucesso!',
          );
          // Atualiza a lista após envio.
          setState(() {
            selectedFile = null;
            _showUploadSection = false;
          });
          _checkPdfExists();
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Erro',
            text: data['message'] ?? 'Erro ao enviar o PDF.',
          );
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Erro',
          text: 'Erro ao conectar ao servidor (${response.statusCode}).',
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
  }

  /// Abre o PDF de uma declaração em uma nova página.
  Future<void> _openPdf(DeclaracaoEntry entry) async {
    try {
      final bytes = base64Decode(entry.pdfBase64);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${entry.nome}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(filePath: filePath, title: entry.nome),
        ),
      );
    } catch (e) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro',
        text: 'Erro ao abrir o PDF: $e',
      );
    }
  }

  /// Formata a data como dd/mm/yyyy hh:mm
  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$day/$month/$year $hour:$minute";
  }

  /// Exibe a lista de declarações já enviadas
  Widget _buildListaDeclaracoes() {
    return _listaDeclaracoes.isNotEmpty
        ? ListView.builder(
            itemCount: _listaDeclaracoes.length,
            itemBuilder: (context, index) {
              final entry = _listaDeclaracoes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Icon(Icons.picture_as_pdf,
                          size: 40, color: Colors.red),
                    ),
                  ),
                  title: Text(entry.nome),
                  subtitle: Text(
                    "Data de envio: ${_formatDateTime(entry.dataEnvio)}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          // Mantém a cor verde apenas para status "Recebido", caso contrário branco
                          color: entry.status == 'Recebido'
                              ? Colors.green
                              : Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.status,
                          style: TextStyle(
                            color: entry.status == 'Recebido'
                                ? Colors.white
                                : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.remove_red_eye),
                        onPressed: () => _openPdf(entry),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        : const Center(child: Text("Nenhuma declaração enviada."));
  }

  /// Exibe a seção de upload de PDF em tela cheia
  Widget _buildUploadSection(String cpf) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Se ainda não selecionou arquivo, mostra o botão de seleção
          if (selectedFile == null) ...[
            ElevatedButton(
              style: _defaultButtonStyle,
              onPressed: _pickPdfFile,
              child: const Text(
                'Selecionar Arquivo PDF',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: _defaultButtonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.red),
              ),
              onPressed: () {
                // Cancela e volta para a lista
                setState(() {
                  _showUploadSection = false;
                  selectedFile = null;
                });
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ]
          // Se o arquivo foi selecionado, mostra a pré-visualização
          else ...[
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: PDFView(
                  filePath: selectedFile!.path,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  onError: (error) {
                    QuickAlert.show(
                      context: context,
                      type: QuickAlertType.error,
                      title: 'Erro',
                      text: 'Erro ao carregar o PDF: $error',
                    );
                  },
                ),
              ),
            ),
            ElevatedButton(
              style: _defaultButtonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.green),
              ),
              onPressed: () => _uploadPdfFile(cpf),
              child: const Text('Enviar PDF'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: _defaultButtonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.red),
              ),
              onPressed: () {
                // Cancela e volta para a lista
                setState(() {
                  _showUploadSection = false;
                  selectedFile = null;
                });
              },
              child: const Text('Cancelar'),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Declaração de Bens (PDF)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SizedBox.expand(
              child: _showUploadSection
                  // Caso esteja no modo de envio/retificação, mostra só a seção de upload
                  ? _buildUploadSection(auth.cpf!)
                  // Caso contrário, mostra a lista e um botão lá embaixo com espaço abaixo
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cabeçalho
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.lightBlue, Colors.blue.shade900],
                              begin: Alignment.centerLeft,
                              end: Alignment.topRight,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Suas declarações enviadas:',
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Lista de declarações (ocupa todo o resto da tela)
                        Expanded(child: _buildListaDeclaracoes()),
                        // Botão para enviar outra declaração + espaço abaixo
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ElevatedButton(
                            style: _defaultButtonStyle,
                            onPressed: () {
                              setState(() {
                                _showUploadSection = true;
                                selectedFile = null;
                              });
                            },
                            child: const Text(
                              'Enviar outra declaração',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        // Espaço extra no final da página
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
    );
  }
}

/// Página para visualização do PDF (em tela inteira).
class PdfViewerPage extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({Key? key, required this.filePath, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: true,
        onError: (error) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Erro',
            text: 'Erro ao carregar o PDF: $error',
          );
        },
      ),
    );
  }
}
