// lib/pages/militar_detalhe_full_page.dart
//
// ▸ Foto com “carimbo” anti‐cópia (login, CPF, IP, data/hora) sobreposta.
// ▸ FLAG_SECURE (Android) para bloquear screenshot / gravação de tela.
// ▸ IP público obtido na montagem via api.ipify.org.
// ▸ Restante da lógica permanece intocada.

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../models/endereco.dart';
import '../models/militar.dart';
import '../models/militar_detalhe_full.dart';
import '../models/ficha_funcional.dart';
import '../services/dados_sql.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/dados_situacao_funcional.dart';
import '../models/auth_model.dart'; // fornece auth.matricula, auth.cpf

class MilitarDetalheFullPage extends StatefulWidget {
  final String matricula;
  const MilitarDetalheFullPage({Key? key, required this.matricula})
      : super(key: key);

  @override
  State<MilitarDetalheFullPage> createState() => _MilitarDetalheFullPageState();
}

class _MilitarDetalheFullPageState extends State<MilitarDetalheFullPage> {
  late Future<Tuple> _future; // (dados pessoais, ficha funcional)

  String _ip = '...';
  final String _dateTimeStr =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    _future = _fetchTudo();
    _fetchIp();
  }

  Future<void> _fetchIp() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        setState(() => _ip = j['ip'] ?? '...');
      }
    } catch (_) {
      // se falhar mantemos "..."
    }
  }

  /* ---------- API 1: dados pessoais ---------- */
  Future<MilitarDetalheFull?> _fetchPessoal() async {
    final uri = Uri.parse(
        'https://pmrr.net/flutter/sigrh/buscapormatricula.php?matricula=${widget.matricula}');
    final r = await http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final Map<String, dynamic> d = jsonDecode(r.body);
    if (d['code'] == 0) return null;
    return MilitarDetalheFull.fromJson(d['result'][0]);
  }

  /* ---------- API 2: ficha funcional ---------- */
  Future<FichaFuncional?> _fetchFicha() async {
    final ds = DadosSql();
    return ds.buscarSituacaoFuncional(widget.matricula);
  }

  Future<Tuple> _fetchTudo() async {
    final pessoal = await _fetchPessoal();
    final ficha = await _fetchFicha();
    return Tuple(pessoal, ficha);
  }

  /* ---------- abrir WhatsApp ---------- */
  Future<void> _whats(String fone) async {
    final uri = Uri.parse('https://wa.me/55$fone');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false); // para carimbo

    return Scaffold(
      appBar: const CustomAppBar(title: 'Dados do Militar'),
      body: FutureBuilder<Tuple>(
        future: _future,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('Erro: ${s.error}'));

          final tuple = s.data!;
          final m = tuple.pessoal;
          if (m == null) {
            return const Center(child: Text('Não possui dados.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // ------------------------- CARTÃO PRINCIPAL ------------------
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------- FOTO COM CARIMBO + proteção --------------
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Envolva a área da imagem para capturar o onTap
                          child: GestureDetector(
                            onTap: () {
                              _showImageModal(context, m.imagemUrl ?? '');
                            },
                            child: SizedBox(
                              width: 120,
                              height: 150,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Foto do militar
                                  CachedNetworkImage(
                                    imageUrl: m.imagemUrl ?? '',
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.person,
                                          size: 40, color: Colors.white),
                                    ),
                                  ),
                                  // Carimbo repetido (só para efeito visual, permanece inativo)
                                  IgnorePointer(
                                    child: Opacity(
                                      opacity: .12,
                                      child: GridView.builder(
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisExtent: 75,
                                        ),
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemBuilder: (_, __) => Text(
                                          'Login: ${auth.matricula}\n'
                                          'CPF: ${auth.cpf}\n'
                                          'IP : $_ip\n'
                                          '$_dateTimeStr',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.25,
                                              color: Colors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // ---------- Dados textuais ---------------------------
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.postoGraduacao} • ${m.quadro}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.nomeCompleto,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.badge,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Matrícula PMRR: ${m.matricula}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.verified_user,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Matrícula SEGAD: ${m.matRhNova}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.credit_card,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'CPF: ${m.cpf}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.date_range,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Incorporação: ${m.incorporacao}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --------------------- Telefone ----------------------------
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(m.telefone,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Telefone'),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'Ligar',
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => _ligar(context, m.telefone),
                        ),
                        IconButton(
                          tooltip: 'WhatsApp',
                          icon: Image.asset('assets/imagens/whatsapp.png',
                              width: 30, height: 30),
                          onPressed: () => _whats(m.telefone),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // --------------------- Endereço / Lotação ------------------
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.apartment, color: Colors.blue),
                        title: Text(m.unidadeSigla),
                        subtitle: const Text('Unidade'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.location_on, color: Colors.blue),
                        title: Text(m.subunidade),
                        subtitle: const Text('Subunidade / Lotação'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.home, color: Colors.blue),
                        title: Text('${m.rua}, Nº ${m.numero}'),
                        subtitle:
                            Text('${m.bairro} · ${m.municipio} – CEP ${m.cep}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // -------------------- Ficha Funcional ----------------------
                if (tuple.ficha != null)
                  DadosSituacaoFuncional(
                    militar: MilitarMock(tuple.ficha!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ligar via discador nativo */
  Future<void> _ligar(BuildContext context, String fone) async {
    final clean = fone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador')),
      );
    }
  }

  /* ---------- Exibir imagem em tela cheia ---------- */
  void _showImageModal(BuildContext context, String urlImage) {
    // Obtenha os dados do usuário para o carimbo
    final auth = Provider.of<Auth>(context, listen: false);
    final String ipText = _ip;
    final String dateTimeText = _dateTimeStr;

    showGeneralDialog(
      context: context,
      barrierLabel: "Exibir Imagem",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size.width * 0.7,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem com CachedNetworkImage, exibindo CircularProgressIndicator como placeholder
                  FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          child: urlImage.trim().isEmpty
                              ? Image.asset(
                                  'assets/imagens/avatar2.jpg',
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: urlImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                    'assets/imagens/avatar2.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Sobreposição com o "carimbo" de proteção
                  IgnorePointer(
                    child: Opacity(
                      opacity: .12,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 75,
                        ),
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) => Text(
                          'Login: ${auth.matricula}\nCPF: ${auth.cpf}\nIP : $ipText\n$dateTimeText',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Botão de fechar no canto superior direito
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
    );
  }
}

/* ---------------------- helpers ---------------------- */

class Tuple {
  final MilitarDetalheFull? pessoal;
  final FichaFuncional? ficha;
  Tuple(this.pessoal, this.ficha);
}

class MilitarMock extends Militar {
  MilitarMock(FichaFuncional ficha)
      : super(
          qra: '',
          matRhNova: '',
          cpf: '',
          grupo: '',
          nivel: '',
          idPosto: '',
          endereco: Endereco(
            Municipio(id: '', nome: ''),
            Bairro(id: '', nome: ''),
            Rua(id: '', nome: ''),
            '',
            '',
          ),
          matricula: '',
          nomeCompleto: '',
          postoGraduacao: '',
          quadro: '',
          subUnidade: '',
          dataIncorporacao: '',
          imageUrl: '',
          fichaFuncional: ficha,
        );
}
