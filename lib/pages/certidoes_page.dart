import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:quickalert/quickalert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../models/certidao_model.dart';
import '../models/auth_model.dart';
import '../widgets/custom_appbar.dart';

class CertidoesPage extends StatefulWidget {
  const CertidoesPage({super.key});

  @override
  State<CertidoesPage> createState() => _CertidoesPageState();
}

class _CertidoesPageState extends State<CertidoesPage> {
  bool _loading = false;
  String? _error;
  List<CertidaoModel> _certidoes = [];
  final Set<int> _expanded = {}; // controla expansão por certidão

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCertidoes());
  }

  Future<void> _loadCertidoes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final matricula = auth.matricula;
      if (matricula == null || matricula.isEmpty) {
        setState(() {
          _error = 'Matrícula do usuário não disponível.';
          _certidoes = [];
        });
        return;
      }

      final uri = Uri.parse(
          'https://pmrr.net/flutter/sigrh/certidoes/buscacertidoes.php?matricula=$matricula');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        setState(() {
          _error = 'Erro ao consultar o servidor (${resp.statusCode}).';
          _certidoes = [];
        });
        return;
      }

      final Map<String, dynamic> body = jsonDecode(resp.body);
      if (body['code'] == 1 && body['result'] is List) {
        final list = CertidaoModel.listFromJson(body['result']);
        setState(() {
          _certidoes = list;
        });
      } else {
        setState(() {
          _certidoes = [];
          _error = body['message'] ?? 'Nenhuma certidão encontrada.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao buscar certidões: $e';
        _certidoes = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onSolicitar() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        int? selectedType =
            1; // 1 = tempo de serviço, 2 = ficha funcional, 3 = vínculo funcional
        String justificativa = '';
        bool submitting = false;
        bool needsJustification =
            false; // quando já existe uma solicitação ativa

        // estado do progressinho
        bool showProgress = false;
        double? netProgress; // null = sem content-length (indeterminado)
        double fakeProgress = 0.0; // fallback quando não há content-length
        Timer? fakeTimer;
        // controle de duração mínima (4s)
        DateTime? progressStart;
        double elapsedProgress = 0.0; // 0..1 baseado em minDurationMs
        Timer? elapsedTimer;
        int minDurationMs = 1200; // padrão mais rápido ~1.2s
        // sinalização da resposta
        bool requestDone = false;
        bool requestSuccess = false;
        String? requestErrorMessage;

        String tipoNome(int? t) {
          switch (t) {
            case 1:
              return 'Certidão de Tempo de Serviço';
            case 2:
              return 'Ficha Funcional';
            case 3:
              return 'Certidão de Vínculo Funcional';
            default:
              return '';
          }
        }

        return StatefulBuilder(builder: (c2, setStateModal) {
          // layout sem altura fixa para não ser coberto pelo teclado

          // Helpers de progresso precisam de c2 e setStateModal
          Future<void> maybeFinish() async {
            if (!requestDone) return;
            if (elapsedProgress < 1.0) return;
            // concluir animações e exibir resultado
            elapsedTimer?.cancel();
            elapsedTimer = null;
            fakeTimer?.cancel();
            fakeTimer = null;
            setStateModal(() {
              showProgress = false;
              netProgress = 1.0;
              fakeProgress = 1.0;
              submitting = false;
            });
            if (requestSuccess) {
              await QuickAlert.show(
                context: c2,
                type: QuickAlertType.success,
                title: 'Solicitação enviada',
                text: 'Seu pedido foi registrado com sucesso.',
                confirmBtnText: 'Ok',
              );
              Navigator.of(c2).pop(true);
              await _loadCertidoes();
            } else {
              await QuickAlert.show(
                context: c2,
                type: QuickAlertType.error,
                title: 'Erro',
                text: requestErrorMessage ?? 'Erro ao inserir certidão.',
                confirmBtnText: 'Ok',
              );
            }
          }

          void startElapsed() {
            progressStart = DateTime.now();
            elapsedProgress = 0.0;
            elapsedTimer?.cancel();
            elapsedTimer =
                Timer.periodic(const Duration(milliseconds: 50), (t) {
              final started = progressStart;
              if (started == null) return;
              final ms = DateTime.now().difference(started).inMilliseconds;
              final frac = (ms / minDurationMs).clamp(0.0, 1.0);
              setStateModal(() {
                elapsedProgress = frac;
              });
              if (elapsedProgress >= 1.0) {
                t.cancel();
                maybeFinish();
              }
            });
          }

          Future<void> _enviarSolicitacao() async {
            try {
              final auth = Provider.of<Auth>(context, listen: false);
              final matricula = auth.matricula;
              if (matricula == null || matricula.isEmpty) {
                await QuickAlert.show(
                  context: c2,
                  type: QuickAlertType.error,
                  title: 'Matrícula não disponível',
                  text: 'Não foi possível identificar sua matrícula.',
                  confirmBtnText: 'Ok',
                );
                Navigator.of(c2).pop(false);
                return;
              }

              // Verifica se já existe certidão ativa do mesmo tipo
              final uriCheck = Uri.parse(
                  'https://pmrr.net/flutter/sigrh/certidoes/buscacertidoes.php?matricula=$matricula');
              final respCheck =
                  await http.get(uriCheck).timeout(const Duration(seconds: 12));

              if (respCheck.statusCode != 200) {
                await QuickAlert.show(
                  context: c2,
                  type: QuickAlertType.error,
                  title: 'Erro ao verificar',
                  text:
                      'Falha ao verificar certidões existentes (${respCheck.statusCode}).',
                  confirmBtnText: 'Ok',
                );
                setStateModal(() {
                  submitting = false;
                });
                return;
              }

              final Map<String, dynamic> bodyCheck = jsonDecode(respCheck.body);
              bool exists = false;
              if (bodyCheck['code'] == 1 && bodyCheck['result'] is List) {
                final list = CertidaoModel.listFromJson(bodyCheck['result']);
                exists =
                    list.any((c) => (c.fkTiceCod == selectedType) && c.ativo);
              }

              // se já existe e justificativa vazia: mostrar carregamento por 2s e então exigir justificativa
              if (exists && justificativa.trim().isEmpty) {
                // iniciar progressinho curto (2s)
                setStateModal(() {
                  showProgress = true;
                  netProgress = 0.0;
                  fakeProgress = 0.0;
                  minDurationMs =
                      800; // reduz para ~0.8s na exigência de justificativa
                });
                startElapsed();
                fakeTimer?.cancel();
                fakeTimer =
                    Timer.periodic(const Duration(milliseconds: 50), (t) {
                  setStateModal(() {
                    fakeProgress = (fakeProgress + 0.09).clamp(0.0, 0.9);
                  });
                });
                // aguarda 2s mínimos
                await Future.delayed(Duration(milliseconds: minDurationMs));
                fakeTimer?.cancel();
                fakeTimer = null;
                setStateModal(() {
                  showProgress = false;
                  submitting = false;
                  needsJustification = true;
                  // reset para próxima tentativa
                  minDurationMs = 1200;
                  netProgress = 0.0;
                  fakeProgress = 0.0;
                });
                return;
              }

              // Iniciar progressinho e enviar com progresso real quando possível
              setStateModal(() {
                showProgress = true;
                netProgress = 0.0;
                fakeProgress = 0.0;
                requestDone = false;
                requestSuccess = false;
                requestErrorMessage = null;
              });
              startElapsed();

              final justificativaEncoded =
                  Uri.encodeQueryComponent(justificativa);
              final uriInsert = Uri.parse(
                  'https://pmrr.net/flutter/sigrh/certidoes/insertcertidao.php?fk_poli_mili_matricula=$matricula&fk_tice_cod=${selectedType}&soce_justificativa=$justificativaEncoded');

              final client = http.Client();
              try {
                final request = http.Request('GET', uriInsert);
                final streamed = await client.send(request);

                final total = streamed.contentLength ?? -1;
                if (total > 0) {
                  // content-length conhecido: atualiza preenchimento proporcional
                  int received = 0;
                  final bytes = <int>[];
                  await for (final chunk in streamed.stream) {
                    bytes.addAll(chunk);
                    received += chunk.length;
                    setStateModal(() {
                      netProgress = (received / total).clamp(0.0, 1.0);
                    });
                  }
                  final respBody = utf8.decode(bytes);
                  final parsed = jsonDecode(respBody) as Map<String, dynamic>;

                  // marcar conclusão, mas só finalizar após 4s
                  requestDone = true;
                  requestSuccess = parsed['code'] == 1;
                  requestErrorMessage = parsed['message'];
                  // garante 100% antes de finalizar
                  setStateModal(() {
                    netProgress = 1.0;
                  });
                  await maybeFinish();
                } else {
                  // sem content-length: animação de preenchimento indeterminada
                  fakeTimer?.cancel();
                  fakeTimer =
                      Timer.periodic(const Duration(milliseconds: 50), (t) {
                    setStateModal(() {
                      // cresce até 90% enquanto aguarda resposta
                      fakeProgress = (fakeProgress + 0.06).clamp(0.0, 0.9);
                    });
                  });

                  final bodyBytes = await streamed.stream.toBytes();
                  fakeTimer?.cancel();
                  fakeTimer = null;

                  final respBody = utf8.decode(bodyBytes);
                  final parsed = jsonDecode(respBody) as Map<String, dynamic>;

                  // marcar conclusão e avançar para 100%
                  requestDone = true;
                  requestSuccess = parsed['code'] == 1;
                  requestErrorMessage = parsed['message'];
                  setStateModal(() {
                    fakeProgress = 1.0;
                  });
                  await maybeFinish();
                }
              } catch (e) {
                // erro inesperado: também respeitar 4s
                requestDone = true;
                requestSuccess = false;
                requestErrorMessage = '$e';
                await maybeFinish();
              } finally {
                client.close();
              }
            } catch (e) {
              setStateModal(() {
                showProgress = false;
                submitting = false;
              });
              await QuickAlert.show(
                context: c2,
                type: QuickAlertType.error,
                title: 'Erro inesperado',
                text: '$e',
                confirmBtnText: 'Ok',
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(c2).viewInsets.bottom + 12,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Solicitar nova certidão',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await QuickAlert.show(
                            context: c2,
                            type: QuickAlertType.error,
                            title: 'Solicitação cancelada',
                            text: 'Você fechou a janela sem enviar.',
                            confirmBtnText: 'Ok',
                          );
                          Navigator.of(c2).pop(false);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escolha o tipo de certidão e informe uma justificativa (opcional).',
                  ),
                  const SizedBox(height: 12),

                  if (needsJustification)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        "Você já possui uma certidão '${tipoNome(selectedType)}' ativa. Justifique para solicitar outra.",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // opções e justificativa
                  RadioListTile<int>(
                    activeColor: Colors.blue.shade900,
                    title: const Text('Certidão de Tempo de Serviço'),
                    value: 1,
                    groupValue: selectedType,
                    onChanged: (v) {
                      setStateModal(() {
                        selectedType = v;
                        needsJustification = false;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    activeColor: Colors.blue.shade900,
                    title: const Text('Ficha Funcional'),
                    value: 2,
                    groupValue: selectedType,
                    onChanged: (v) {
                      setStateModal(() {
                        selectedType = v;
                        needsJustification = false;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    activeColor: Colors.blue.shade900,
                    title: const Text('Certidão de Vínculo Funcional'),
                    value: 3,
                    groupValue: selectedType,
                    onChanged: (v) {
                      setStateModal(() {
                        selectedType = v;
                        needsJustification = false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 4,
                    onChanged: (v) {
                      justificativa = v;
                      if (needsJustification &&
                          justificativa.trim().isNotEmpty) {
                        setStateModal(() {
                          needsJustification = false;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Justificativa (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botão customizado azul/branco com progressinho
                  LayoutBuilder(builder: (ctxBtn, constraints) {
                    final btnWidth = constraints.maxWidth;
                    final double rawFill =
                        (netProgress ?? fakeProgress).clamp(0.0, 1.0);
                    final double displayFill = showProgress
                        ? (rawFill > elapsedProgress
                            ? rawFill
                            : elapsedProgress)
                        : 0.0;
                    final double barWidth = showProgress
                        ? btnWidth * (displayFill > 0.0 ? displayFill : 0.06)
                        : 0.0; // largura mínima 6% quando iniciando
                    return GestureDetector(
                      onTap: submitting
                          ? null
                          : () async {
                              setStateModal(() {
                                submitting = true;
                              });
                              await _enviarSolicitacao();
                            },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.blue.shade900.withOpacity(0.12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade900.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            if (showProgress)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 70),
                                width: barWidth,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blue.shade400, // azul mais fraco
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.send_outlined,
                                    color: Colors.blue
                                        .shade900, // mantém azul escuro sempre
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    showProgress
                                        ? 'Enviando solicitação...'
                                        : 'Solicitar',
                                    style: TextStyle(
                                      color: Colors.blue
                                          .shade900, // mantém azul escuro sempre
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );

    if (result == true) {
      // já recarregado após sucesso dentro do fluxo
    }
  }

  Color _statusColor(int? fkStceCod) {
    switch (fkStceCod) {
      case 1:
        return Colors.orange.shade700; // Solicitada
      case 2:
        return Colors.blue.shade900; // Certificada agora azul
      case 3:
        return Colors.green.shade700; // Homologada agora verde
      default:
        return Colors.grey.shade700;
    }
  }

  String _statusLabel(int? fkStceCod) {
    switch (fkStceCod) {
      case 1:
        return 'Solicitada';
      case 2:
        return 'Certificada';
      case 3:
        return 'Homologada';
      default:
        return 'Desconhecido';
    }
  }

  String _statusMessage(int? fkStceCod) {
    switch (fkStceCod) {
      case 1:
        return 'Aguardando certificação da chefia imediata...';
      case 2:
        return 'Aguardando homologação do DRH para liberação da certidão...';
      case 3:
        return 'Pronta! Você pode abrir sua certidão.';
      default:
        return '';
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  // Nome exibido na listagem e no viewer: força o nome do tipo 3
  String _tipoNomeListagem(CertidaoModel c) {
    if (c.fkTiceCod == 3) return 'Certidão de Vínculo Funcional';
    final nome = c.nomeTipoCertidao;
    return nome.trim().isEmpty ? 'Certidão' : nome;
  }

  // Prepara o PDF da certidão: busca os bytes (base64 ou URL), salva no cache e retorna o caminho
  Future<String?> _prepareCertidaoPdf(CertidaoModel c) async {
    try {
      Uint8List? bytes;

      // Preferir base64 vindo da API
      final b64 = c.soceArquivoBase64; // campo do model
      if (b64 != null && b64.isNotEmpty) {
        try {
          bytes = base64Decode(b64);
        } catch (_) {
          bytes = null;
        }
      }

      // Se não houver base64, tentar baixar via URL se disponível
      if (bytes == null && c.soceArquivo != null && c.soceArquivo!.isNotEmpty) {
        final src = c.soceArquivo!;
        if (src.startsWith('http')) {
          final resp = await http
              .get(Uri.parse(src))
              .timeout(const Duration(seconds: 20));
          if (resp.statusCode == 200) {
            bytes = resp.bodyBytes;
          }
        } else {
          // Caso seja um caminho local
          try {
            final file = File(src);
            if (await file.exists()) {
              bytes = await file.readAsBytes();
            }
          } catch (_) {}
        }
      }

      if (bytes == null) {
        await QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Arquivo indisponível',
          text: 'Não foi possível localizar o PDF desta certidão.',
          confirmBtnText: 'Ok',
        );
        return null;
      }

      final dir = await getTemporaryDirectory();
      final filePath = p.join(dir.path, 'certidao_${c.soceCod}.pdf');
      final f = File(filePath);
      await f.writeAsBytes(bytes, flush: true);
      return filePath;
    } catch (e) {
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Erro ao abrir',
        text: '$e',
        confirmBtnText: 'Ok',
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade900,
      letterSpacing: 0.1,
    );
    final sectionStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.blue.shade900,
      letterSpacing: 0.1,
      height: 1.1,
    );
    final smallStyle = TextStyle(fontSize: 13, color: Colors.grey.shade700);

    final gradientApp = LinearGradient(
      colors: [Colors.lightBlue, Colors.blue.shade900],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      appBar: CustomAppBar(title: 'Certidões'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.how_to_reg_outlined,
                            color: Colors.blue.shade900, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Solicitar nova certidão',
                                style: titleStyle.copyWith(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Abra um pedido para emissão de certidão.',
                                style: smallStyle),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: gradientApp,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade900.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _onSolicitar,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: const [
                                  Icon(Icons.add,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Solicitar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Minhas Certidões',
                      style: sectionStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (!_loading && _certidoes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_certidoes.length}',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCertidoes,
                  child: Builder(builder: (context) {
                    if (_loading && _certidoes.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 120,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.blue.shade900,
                              ),
                            ),
                          )
                        ],
                      );
                    }

                    if (_error != null && _certidoes.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8),
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Você ainda não solicitou nenhuma certidão.\nPara solicitar, clique no botão 'Solicitar' acima.",
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemCount: _certidoes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = _certidoes[index];
                        return _buildCard(
                            c, titleStyle, smallStyle, Colors.blue.shade900);
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusStepper(int currentStatus, Color activeColor) {
    Widget step(String label, bool active) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: active ? 28 : 22,
            height: active ? 28 : 22,
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.white,
              border: Border.all(
                  color: active ? activeColor : Colors.grey.shade300),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                Icons.check,
                size: active ? 16 : 14,
                color: active ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final bool s1 = currentStatus >= 1;
    final bool s2 = currentStatus >= 2;
    final bool s3 = currentStatus >= 3;

    return SizedBox(
      height: 70,
      child: Row(
        children: [
          Flexible(flex: 2, child: step('Solicitada', s1)),
          Expanded(
            flex: 3,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 3,
                color: s2 ? activeColor : Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          Flexible(flex: 2, child: step('Certificada', s2)),
          Expanded(
            flex: 3,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 3,
                color: s3 ? activeColor : Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          Flexible(flex: 2, child: step('Homologada', s3)),
        ],
      ),
    );
  }

  Widget _buildCard(
    CertidaoModel c,
    TextStyle titleStyle,
    TextStyle smallStyle,
    Color primary,
  ) {
    final borderRadius = BorderRadius.circular(12);
    final statusColor = _statusColor(c.fkStceCod);
    final isExpanded = _expanded.contains(c.soceCod);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 1.5,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ExpansionTile(
          onExpansionChanged: (v) {
            setState(() {
              if (v) {
                _expanded.add(c.soceCod);
              } else {
                _expanded.remove(c.soceCod);
              }
            });
          },
          initiallyExpanded: isExpanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: statusColor.withOpacity(0.12),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tipoNomeListagem(c),
                style: smallStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.12)),
                    ),
                    child: Text(
                      _statusLabel(c.fkStceCod),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Data Solicitação: ${_formatDate(c.soceData)}',
                          style: smallStyle),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event_note,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                          'Data Vencimento: ${_formatDate(c.soceDataVencimento)}',
                          style: smallStyle),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusStepper(c.fkStceCod ?? 0, statusColor),
                  const SizedBox(height: 6),
                  Text(
                    _statusMessage(c.fkStceCod),
                    style: smallStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
            if (c.soceArquivo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Arquivo: ${c.soceArquivo}')),
                  ],
                ),
              ),
            if (c.soceObs != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Obs: ${c.soceObs}')),
                  ],
                ),
              ),
            if (c.soceJustificativa != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.history_edu, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Justificativa: ${c.soceJustificativa}'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (c.fkStceCod == 3)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final path = await _prepareCertidaoPdf(c);
                      if (path == null) return;
                      // Abre o visualizador com opção de compartilhar
                      // ignore: use_build_context_synchronously
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            filePath: path,
                            title: _tipoNomeListagem(c),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_outlined, size: 18),
                    label: const Text('Abrir Certidão'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.green.shade700, // Homologada: botão verde
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Tela simples de visualização de PDF com opção de compartilhar
class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String? title;

  const PdfViewerScreen({super.key, required this.filePath, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: title ?? 'Certidão'),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false, // rolagem vertical (de cima para baixo)
        autoSpacing: true,
        pageFling: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.share_outlined),
        label: const Text(
          'Compartilhar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () async {
          try {
            await Share.shareXFiles(
              [XFile(filePath)],
              text: title ?? 'Certidão',
            );
          } catch (e) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao compartilhar: $e')),
            );
          }
        },
      ),
    );
  }
}
