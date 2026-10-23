import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/log/registro_log.dart';
import '../../models/auth_model.dart';
import '../../pages/certidoes_page.dart';
import '../../pages/pdf_view_page.dart';
import '../../services/certidao_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/aviso_rapido.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/dialogo_confirmacao.dart';
import '../../widgets/vidro.dart';
import 'documentos_locais.dart';

const _chave = 'rh.documentos';

String _data(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : para[i]);
  }
  return b.toString().toLowerCase();
}

/// Um item da Central: certidão ou contracheque, com o que a tela precisa.
class ItemDocumento {
  const ItemDocumento({required this.titulo, required this.detalhe, required this.data, required this.tipo, this.certidao, this.contracheque});
  final String titulo;
  final String detalhe;
  final DateTime data;
  final String tipo; // certidao | contracheque
  final CertidaoGuardada? certidao;
  final ContrachequeGuardado? contracheque;
}

/// Filtra pelo texto digitado, sem acento e sem caixa, em qualquer palavra.
List<ItemDocumento> filtrarDocumentos(List<ItemDocumento> itens, String busca) {
  final termos = _semAcento(busca).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (termos.isEmpty) return itens;
  return [
    for (final i in itens)
      if (termos.every(_semAcento('${i.titulo} ${i.detalhe}').contains)) i,
  ];
}

/// Central de documentos (P4): as certidões e os contracheques em PDF que
/// estão no aparelho, num só lugar, com busca. Declarações entram quando
/// os comprovantes forem gerados pela API (§12.3).
class DocumentosPage extends StatefulWidget {
  const DocumentosPage({super.key, this.carregar});

  /// Trocável nos testes.
  final Future<List<ItemDocumento>> Function(String matricula)? carregar;

  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  List<ItemDocumento>? _itens;
  String _busca = '';
  late final String _matricula = context.read<Auth>().matricula ?? '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static Future<List<ItemDocumento>> _padrao(String matricula) async {
    final certidoes = await CertidaoService.guardadas(matricula);
    final cc = await DocumentosLocais().contracheques(matricula);
    return [
      for (final c in certidoes)
        ItemDocumento(
          titulo: c.tituloCurto ?? c.titulo,
          detalhe: c.valida ? 'Certidão · válida até ${_data(c.validoAte)}' : 'Certidão · vencida em ${_data(c.validoAte)}',
          data: c.geradoEm,
          tipo: 'certidao',
          certidao: c,
        ),
      for (final c in cc)
        ItemDocumento(
            titulo: c.titulo, detalhe: 'Contracheque · guardado em ${_data(c.guardadoEm)}', data: c.guardadoEm, tipo: 'contracheque', contracheque: c),
    ]..sort((a, b) => b.data.compareTo(a.data));
  }

  Future<void> _carregar() async {
    final itens = await (widget.carregar ?? _padrao)(_matricula);
    registrar('documentos.ver', chave: _chave, dados: {'total': itens.length});
    if (mounted) setState(() => _itens = itens);
  }

  Future<void> _abrir(ItemDocumento i) async {
    registrar('documentos.abrir', chave: _chave, dados: {'tipo': i.tipo});
    if (i.certidao != null) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CertidaoVisualizarPage(certidao: i.certidao!, tituloBarra: i.certidao!.tituloCurto)));
      return _carregar();
    }
    final c = i.contracheque!;
    if (!await File(c.caminho).exists()) {
      if (mounted) avisoAtencao(context, 'Arquivo não encontrado', texto: 'Abra o contracheque de novo para baixar. Código DO-ARQUIVO.');
      return _carregar();
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewPage(path: c.caminho)));
  }

  Future<void> _compartilhar(ContrachequeGuardado c) async {
    registrar('documentos.compartilhar', chave: _chave, dados: {'tipo': 'contracheque'});
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles([XFile(c.caminho, mimeType: 'application/pdf', name: '${c.id}.pdf')],
        subject: c.titulo, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
  }

  Future<void> _remover(ContrachequeGuardado c) async {
    final ok = await dialogoConfirmacao(context,
        titulo: 'Remover do aparelho?',
        mensagem: 'O PDF de ${c.titulo} sai só deste aparelho. Você pode baixar de novo em Contracheques.',
        textoConfirmar: 'Remover',
        icone: Icons.delete_outline_rounded,
        cor: Theme.of(context).colorScheme.error);
    if (!ok) return;
    await DocumentosLocais().remover(_matricula, c.id);
    registrar('documentos.remover', chave: _chave, dados: {'tipo': 'contracheque'});
    if (mounted) avisoSucesso(context, 'Removido do aparelho');
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itens = _itens;
    final lista = itens == null ? const <ItemDocumento>[] : filtrarDocumentos(itens, _busca);
    return FundoSuave(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Documentos'),
        body: itens == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text('Certidões e contracheques guardados neste aparelho.', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar documento',
                        prefixIcon: Icon(Icons.search_rounded, size: AppIconSize.sm),
                      ),
                      onChanged: (v) => setState(() => _busca = v),
                    ),
                    const SizedBox(height: 12),
                    if (itens.isEmpty)
                      CartaoVidro(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Nenhum documento guardado ainda.', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('As certidões que você emitir e os contracheques que abrir em PDF aparecem aqui.',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton(
                                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.CERTIDOES_PAGE),
                                child: const Text('Ir para Certidões')),
                            OutlinedButton(
                                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.CONTRACHEQUE_PAGE),
                                child: const Text('Ir para Contracheques')),
                          ]),
                        ]),
                      )
                    else if (lista.isEmpty)
                      CartaoVidro(child: Text('Nenhum documento com "$_busca".'))
                    else
                      CartaoVidro(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          for (final (n, i) in lista.indexed) ...[
                            if (n > 0) const Divider(height: 1, indent: 52),
                            ListTile(
                              minVerticalPadding: 10,
                              leading: Icon(i.tipo == 'certidao' ? Icons.edit_document : Icons.request_quote_outlined,
                                  size: AppIconSize.md, color: theme.colorScheme.primary),
                              title: Text(i.titulo, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text(i.detalhe, style: theme.textTheme.bodySmall),
                              onTap: () => _abrir(i),
                              trailing: i.contracheque == null
                                  ? const Icon(Icons.chevron_right_rounded, size: AppIconSize.sm)
                                  : PopupMenuButton<String>(
                                      tooltip: 'Mais ações',
                                      onSelected: (v) =>
                                          v == 'compartilhar' ? _compartilhar(i.contracheque!) : _remover(i.contracheque!),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'compartilhar', child: Text('Compartilhar')),
                                        PopupMenuItem(value: 'remover', child: Text('Remover do aparelho')),
                                      ],
                                    ),
                            ),
                          ],
                        ]),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
