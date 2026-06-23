import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:projetonovo/models/auth_model.dart';
import 'package:projetonovo/utils/app_theme.dart';
import 'package:provider/provider.dart';

String statusText(int status) {
  switch (status) {
    case 1:
      return 'Declarado';
    case 2:
      return 'Recebido';
    case 3:
      return 'Retificado';
    case 4:
      return 'Retificação Atual';
    default:
      return 'Desconhecido';
  }
}

class DeclaracaoEntry {
  final String nome;
  final DateTime dataEnvio;
  final String status;
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
  List<DeclaracaoEntry> _listaDeclaracoes = [];
  bool _showUploadSection = false;

  ButtonStyle _compactActionStyle() => const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(Size(0, 34)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      );

  @override
  void initState() {
    super.initState();
    _checkPdfExists();
  }

  Future<void> _checkPdfExists() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final url =
        'https://pmrr.net/flutter/sigrh/buscapdfirpf.php?cpf=${auth.cpf}&ano=${widget.ano}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 1) {
          if (data['declaracoes'] is List &&
              (data['declaracoes'] as List).isNotEmpty) {
            final listData = data['declaracoes'] as List<dynamic>;
            _listaDeclaracoes = listData.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return DeclaracaoEntry(
                nome: 'Documento ${index + 1}',
                dataEnvio: DateTime.tryParse(item['data_envio'] ?? '') ??
                    DateTime.now(),
                status: statusText(item['status']),
                pdfBase64: item['pdf'] ?? '',
              );
            }).toList();
          } else if (data['pdf'] != null) {
            _listaDeclaracoes = [
              DeclaracaoEntry(
                nome: 'Documento 1',
                dataEnvio: DateTime.tryParse(data['data_envio'] ?? '') ??
                    DateTime.now(),
                status: statusText(data['status']),
                pdfBase64: data['pdf'] as String,
              ),
            ];
          } else {
            _listaDeclaracoes = [];
          }
        } else {
          _listaDeclaracoes = [];
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao buscar declarações (${response.statusCode}).',
          isError: true,
        );
      }
    } catch (e) {
      await _showNotice(
        title: 'Erro',
        message: 'Erro inesperado: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          if (_listaDeclaracoes.isNotEmpty) _showUploadSection = false;
        });
      }
    }
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      if (result.files.single.size > 5 * 1024 * 1024) {
        await _showNotice(
          title: 'Tamanho excedido',
          message: 'O PDF deve ter no máximo 5MB.',
          isError: true,
        );
        return;
      }

      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    } else {
      await _showNotice(
        title: 'Atenção',
        message: 'Nenhum arquivo foi selecionado.',
        isError: true,
      );
    }
  }

  Future<void> _uploadPdfFile(String cpf) async {
    if (selectedFile == null) {
      await _showNotice(
        title: 'Arquivo ausente',
        message: 'Selecione um PDF antes de enviar.',
        isError: true,
      );
      return;
    }

    const url = 'https://pmrr.net/flutter/sigrh/enviapdfirpf.php';
    _showBusyDialog('Enviando PDF...');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['cpf'] = cpf
        ..fields['ano'] = widget.ano
        ..files
            .add(await http.MultipartFile.fromPath('pdf', selectedFile!.path));

      final response = await request.send();
      _dismissDialogIfOpen();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = Map<String, dynamic>.from(json.decode(responseData));

        if (data['code'] == 1) {
          await _showNotice(
            title: 'Sucesso',
            message: 'PDF enviado com sucesso.',
            isError: false,
          );
          setState(() {
            selectedFile = null;
            _showUploadSection = false;
          });
          _checkPdfExists();
        } else {
          await _showNotice(
            title: 'Erro',
            message: data['message'] ?? 'Erro ao enviar PDF.',
            isError: true,
          );
        }
      } else {
        await _showNotice(
          title: 'Erro',
          message: 'Erro ao conectar ao servidor (${response.statusCode}).',
          isError: true,
        );
      }
    } catch (e) {
      _dismissDialogIfOpen();
      await _showNotice(
        title: 'Erro',
        message: 'Erro inesperado: $e',
        isError: true,
      );
    }
  }

  Future<void> _openPdf(DeclaracaoEntry entry) async {
    try {
      final bytes = base64Decode(entry.pdfBase64);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${entry.nome}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(filePath: filePath, title: entry.nome),
        ),
      );
    } catch (e) {
      await _showNotice(
        title: 'Erro',
        message: 'Erro ao abrir o PDF: $e',
        isError: true,
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Widget _buildListaDeclaracoes(ThemeData theme) {
    if (_listaDeclaracoes.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Nenhuma declaração enviada.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _listaDeclaracoes.length,
      itemBuilder: (context, index) {
        final entry = _listaDeclaracoes[index];
        final color = entry.status == 'Recebido'
            ? Colors.green.shade700
            : Colors.blueGrey.shade700;
        final delay = (index * 45).clamp(0, 240);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + delay),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
            ),
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.red, size: 17),
              ),
              title: Text(entry.nome,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Enviado em ${_formatDateTime(entry.dataEnvio)}',
                  style: theme.textTheme.bodySmall),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      entry.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 17,
                    icon: const Icon(Icons.visibility_rounded),
                    onPressed: () => _openPdf(entry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadSection(String cpf, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Envie o PDF com até 5MB',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (selectedFile == null) ...[
          FilledButton.icon(
            style: _compactActionStyle(),
            onPressed: _pickPdfFile,
            icon: const Icon(Icons.upload_file_rounded, size: 15),
            label: const Text('Selecionar PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: _compactActionStyle(),
            onPressed: () {
              setState(() {
                _showUploadSection = false;
                selectedFile = null;
              });
            },
            child: const Text('Cancelar'),
          ),
        ] else ...[
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
                color: isDark
                    ? theme.colorScheme.surface.withValues(alpha: 0.65)
                    : Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PDFView(
                  filePath: selectedFile!.path,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  onError: (error) {
                    _showNotice(
                      title: 'Erro',
                      message: 'Erro ao carregar o PDF: $error',
                      isError: true,
                    );
                  },
                ),
              ),
            ),
          ),
          FilledButton.icon(
            style: _compactActionStyle(),
            onPressed: () => _uploadPdfFile(cpf),
            icon: const Icon(Icons.send_rounded, size: 15),
            label: const Text('Enviar PDF'),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            style: _compactActionStyle(),
            onPressed: () {
              setState(() {
                _showUploadSection = false;
                selectedFile = null;
              });
            },
            child: const Text('Cancelar'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Declaração de Bens (PDF)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.blue],
              begin: Alignment.centerLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF0E1B2E) : const Color(0xFFEAF2FF),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : SizedBox.expand(
                child: _showUploadSection
                    ? _buildUploadSection(auth.cpf!, theme)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Declaração de Bens (IRPF)',
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Seus documentos enviados',
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: _buildListaDeclaracoes(theme),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                            child: FilledButton.icon(
                              style: _compactActionStyle(),
                              onPressed: () {
                                setState(() {
                                  _showUploadSection = true;
                                  selectedFile = null;
                                });
                              },
                              icon: const Icon(Icons.upload_rounded, size: 15),
                              label: const Text('Enviar outra declaração'),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Future<void> _showNotice({
    required String title,
    required String message,
    required bool isError,
  }) async {
    final color = isError ? Colors.red.shade700 : Colors.green.shade700;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showBusyDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dismissDialogIfOpen() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class PdfViewerPage extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({Key? key, required this.filePath, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.blue],
              begin: Alignment.centerLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: true,
      ),
    );
  }
}
