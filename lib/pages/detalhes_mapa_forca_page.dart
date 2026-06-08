// =================  lib/pages/detalhes_mapa_forca_page.dart  =================
// Busca avançada SEM pacote externo: ignora acentos, ç/ñ, símbolos e faz AND.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/map_busca_detalhes_model.dart';
import '../models/militar_detalhe_model.dart';
import '../models/auth_model.dart';
import '../pages/militar_detalhe_full_page.dart';
import '../widgets/custom_appbar.dart';

class DetalhesMapaForcaPage extends StatefulWidget {
  final MapBuscaDetalhesModel dadosBusca;
  const DetalhesMapaForcaPage({Key? key, required this.dadosBusca})
      : super(key: key);

  @override
  State<DetalhesMapaForcaPage> createState() => _DetalhesMapaForcaPageState();
}

class _DetalhesMapaForcaPageState extends State<DetalhesMapaForcaPage> {
  late Future<List<MilitarDetalheModel>> _future;
  List<MilitarDetalheModel> _todos = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _ip = '...';
  final String _dateTimeStr =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _fetchIp();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ---------------- API ---------------- */
  Future<List<MilitarDetalheModel>> _fetch() async {
    final buffer = StringBuffer(
        'https://pmrr.net/flutter/sigrh/mapadaforca/listarsituacaodetalhes.php');

    if (widget.dadosBusca.idSituacao.isNotEmpty) {
      buffer.write('?id_situacao=${widget.dadosBusca.idSituacao}');
    }

    final siglas = widget.dadosBusca.postoGraduacao;
    if (siglas.isNotEmpty && !(siglas.length == 1 && siglas.first == 'TODOS')) {
      buffer.write(buffer.toString().contains('?') ? '&' : '?');
      buffer.write(
        siglas.map((p) => 'posto[]=${Uri.encodeQueryComponent(p)}').join('&'),
      );
    }

    final resp = await http.get(Uri.parse(buffer.toString()));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final lista = (data['result'] as List)
        .map((e) => MilitarDetalheModel.fromJson(e))
        .toList();

    _todos = data['code'] == 0 ? [] : lista;
    return _todos;
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
    } catch (_) {}
  }

  /* ---------- Normalização ---------- */
  final Map<int, String> _accentMap = const {
    225: 'a', 224: 'a', 226: 'a', 227: 'a', 228: 'a', 229: 'a', // á à â ã ä å
    231: 'c', // ç
    233: 'e', 232: 'e', 234: 'e', 235: 'e', // é è ê ë
    237: 'i', 236: 'i', 238: 'i', 239: 'i', // í ì î ï
    241: 'n', // ñ
    243: 'o', 242: 'o', 244: 'o', 245: 'o', 246: 'o', // ó ò ô õ ö
    250: 'u', 249: 'u', 251: 'u', 252: 'u', // ú ù û ü
  };

  String _normalize(String s) {
    final sb = StringBuffer();
    for (final codeUnit in s.toLowerCase().codeUnits) {
      sb.write(_accentMap[codeUnit] ?? String.fromCharCode(codeUnit));
    }
    return sb.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  List<MilitarDetalheModel> _filtrados() {
    final q = _normalize(_searchCtrl.text.trim());
    if (q.isEmpty) return _todos;

    final terms = q.split(RegExp(r' +'))..removeWhere((e) => e.isEmpty);

    return _todos.where((m) {
      final nomeNorm = _normalize(m.nome);
      return terms.every((t) => nomeNorm.contains(t));
    }).toList(growable: false);
  }

  /* ---------------- BUILD ---------------- */
  @override
  Widget build(BuildContext context) {
    final primary = Colors.lightBlue;
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      appBar: CustomAppBar(
          title:
              '${widget.dadosBusca.descricao} - ${widget.dadosBusca.quantidade}'),
      body: FutureBuilder<List<MilitarDetalheModel>>(
        future: _future,
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(child: Text('Erro: ${s.error}'));
          }
          final dados = s.hasData ? _filtrados() : [];

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SearchBar(
                    controller: _searchCtrl,
                    hintText: 'Pesquisar por nome...',
                    leading: const Icon(Icons.search),
                    elevation: const MaterialStatePropertyAll(0),
                    onTap: () => _searchCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: _searchCtrl.text.length),
                  ),
                ),
                Expanded(
                  child: dados.isEmpty
                      ? const Center(child: Text('Não possui dados.'))
                      : ListView.builder(
                          key: ValueKey(_searchCtrl.text),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: dados.length,
                          itemBuilder: (_, index) =>
                              _itemCard(dados[index], auth, primary),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ----------------- Card ----------------- */
  Widget _itemCard(MilitarDetalheModel m, Auth auth, Color primary) {
    return InkWell(
      splashColor: primary.withOpacity(.15),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MilitarDetalheFullPage(matricula: m.matricula),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(8),
          height: 100,
          child: Row(
            children: [
              _fotoCarimbada(m, auth),
              const SizedBox(width: 8),
              _dadosTexto(m),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoCarimbada(MilitarDetalheModel m, Auth auth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: m.imagemUrl ?? '',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              memCacheWidth: 120,
              cacheManager: DefaultCacheManager(),
              placeholderFadeInDuration: const Duration(milliseconds: 300),
              placeholder: (_, __) => _placeholderImg(),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            IgnorePointer(
              child: Opacity(
                opacity: .14,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 40,
                  ),
                  itemBuilder: (_, __) => Text(
                    'Login: ${auth.matricula}\n'
                    'CPF: ${auth.cpf}\n'
                    'IP : $_ip\n'
                    '$_dateTimeStr',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9, height: 1.2, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );

  Widget _dadosTexto(MilitarDetalheModel m) => Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('Posto/Graduação: ${m.postoGraduacao}',
                style: const TextStyle(fontSize: 12)),
            Text('Unidade: ${m.comando} • ${m.unidade}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            Text('Subunidade: ${m.subunidade}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}

/* -------------------- MODEL -------------------- */
class MilitarDetalheModel {
  final String matricula;
  final String postoGraduacao;
  final String nome;
  final String comando;
  final String unidade;
  final String subunidade;
  final String? imagemUrl;

  MilitarDetalheModel({
    required this.matricula,
    required this.postoGraduacao,
    required this.nome,
    required this.comando,
    required this.unidade,
    required this.subunidade,
    this.imagemUrl,
  });

  factory MilitarDetalheModel.fromJson(Map<String, dynamic> j) =>
      MilitarDetalheModel(
        matricula: j['matricula'].toString(),
        postoGraduacao: j['posto_graduacao'] ?? '',
        nome: j['nome'] ?? '',
        comando: j['comando'] ?? '',
        unidade: j['unidade'] ?? '',
        subunidade: j['subunidade'] ?? '',
        imagemUrl: j['imagemurl'],
      );
}
