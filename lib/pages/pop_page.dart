import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:projetonovo/utils/api_services.dart';
import 'package:projetonovo/widgets/custom_appbar.dart';
import 'package:share_plus/share_plus.dart';

class PopPage extends StatefulWidget {
  const PopPage({Key? key}) : super(key: key);

  @override
  State<PopPage> createState() => _PopPageState();
}

class _PopPageState extends State<PopPage> {
  final _searchCtrl = TextEditingController();
  String _orderBy = 'data_publicacao';
  String _orderDir = 'DESC';
  String _orderSelection = 'data';

  int _page = 1;
  int _perPage = 12;
  bool _loading = false;
  bool _hasMore = true;
  String? _errorMsg;

  final List<Map<String, dynamic>> _items = [];
  Timer? _debounce;
  final ScrollController _scrollCtrl = ScrollController();

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true);

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() async {
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });
    try {
      final res = await ApiServices.listarLegislacoes(
        page: _page,
        perPage: _perPage,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        tipoNome: 'POP',
        orderBy: _orderBy,
        orderDir: _orderDir,
      ).timeout(const Duration(seconds: 8));
      final data = (res['data'] as List?) ?? [];
      final meta = (res['meta'] as Map?) ?? {};
      setState(() {
        _items.addAll(data.cast<Map<String, dynamic>>());
        final totalPages = _toInt(meta['total_pages'], 1);
        _hasMore = _page < totalPages;
        _applyLocalSort();
      });
    } on TimeoutException {
      setState(() {
        _errorMsg =
            'Sistema de Legislações fora do ar. Tente novamente mais tarde';
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Falha ao carregar: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _page++);
    await _load();
  }

  void _applyLocalSort() {
    if (_orderSelection == 'titulo') {
      _items.sort((a, b) {
        final at = (a['titulo'] ?? '') as String;
        final bt = (b['titulo'] ?? '') as String;
        return at.toLowerCase().compareTo(bt.toLowerCase());
      });
    } else {
      DateTime? parseDate(String? value) {
        if (value == null || value.isEmpty) return null;
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }

      _items.sort((a, b) {
        final ad = parseDate(a['data_publicacao'] as String?);
        final bd = parseDate(b['data_publicacao'] as String?);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    }
  }

  Future<void> _openPdf(Map<String, dynamic> item) async {
    String? filePath;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 12),
                Text('Abrindo PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final id = _toInt(item['id']);
      final url = item['pdf_api_url'] as String?;
      filePath = await ApiServices.baixarLegislacaoPdf(id: id, pdfApiUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao abrir PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted || filePath == null) return;

    final id = _toInt(item['id']);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PdfViewerPop(
          filePath: filePath!,
          title: (item['titulo'] ?? '') as String,
          heroTag: 'pop-$id',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'POP'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por texto (min. 3 caracteres)',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.lightBlue.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.blue.shade900, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    final q = _searchCtrl.text.trim();
                    if (q.isEmpty || q.length >= 3) {
                      _applyFilters();
                    }
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: DropdownButtonFormField<String>(
                value: _orderSelection,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'data',
                    child: Text('Data (recentes)'),
                  ),
                  DropdownMenuItem(
                    value: 'titulo',
                    child: Text('Título (A–Z)'),
                  ),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.lightBlue.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.blue.shade900, width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _orderSelection = value;
                    if (value == 'titulo') {
                      _orderBy = 'titulo';
                      _orderDir = 'ASC';
                    } else {
                      _orderBy = 'data_publicacao';
                      _orderDir = 'DESC';
                    }
                  });
                  _applyFilters();
                },
              ),
            ),
            Expanded(child: _buildGallery(context)),
            if (_loading && _items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (w < 500) {
      crossAxisCount = 1;
    } else if (w < 900) {
      crossAxisCount = 2;
    } else if (w < 1200) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    if (_items.isEmpty) {
      if (_errorMsg != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 36, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  _errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _applyFilters(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        );
      }
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      controller: _scrollCtrl,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 2.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) => _PopCard(
        item: _items[i],
        onOpen: () => _openPdf(_items[i]),
      ),
    );
  }
}

class _PopCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onOpen;

  const _PopCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final id = _toInt(item['id']);
    final titulo = (item['titulo'] ?? '') as String;
    final numero = (item['numero'] ?? '') as String;
    final dataPub = (item['data_publicacao'] ?? '') as String;
    final tag = 'pop-$id';

    return Hero(
      tag: tag,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.lightBlue.shade200, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dataPub.isNotEmpty ? 'Publicação: ${_br(dataPub)}' : '',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                    ),
                    Text(
                      numero.isNotEmpty ? 'Nº $numero' : '',
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String _br(String ymd) {
    try {
      final d = DateTime.parse(ymd);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return ymd;
    }
  }
}

class _PdfViewerPop extends StatelessWidget {
  final String filePath;
  final String title;
  final String heroTag;

  const _PdfViewerPop({
    required this.filePath,
    required this.title,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final rawTitle = title.isEmpty ? 'POP' : title;
    final compactTitle = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shownTitle = compactTitle.length > 48
        ? compactTitle.substring(0, 48) + '…'
        : compactTitle;
    return Scaffold(
      appBar: CustomAppBar(title: shownTitle),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.share_outlined),
        label: const Text('Compartilhar'),
        onPressed: () async {
          try {
            await Share.shareXFiles([XFile(filePath)], text: title);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao compartilhar: $e')),
            );
          }
        },
      ),
    );
  }
}
