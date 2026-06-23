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

  ButtonStyle _compactActionStyle(ThemeData theme) => ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.primary),
        foregroundColor: WidgetStatePropertyAll(theme.colorScheme.onPrimary),
      );

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'POP'),
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        theme.cardColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 17,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Procedimentos Operacionais (POP)',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          '${_items.length}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: _compactActionStyle(theme),
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por texto (min. 3 caracteres)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    filled: true,
                    fillColor: isDark
                        ? theme.colorScheme.surface.withValues(alpha: 0.72)
                        : Colors.white,
                    prefixIcon: const Icon(Icons.search, size: 18),
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
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    filled: true,
                    fillColor: isDark
                        ? theme.colorScheme.surface.withValues(alpha: 0.72)
                        : Colors.white,
                  ),
                  dropdownColor: isDark
                      ? theme.colorScheme.surface
                      : theme.colorScheme.background,
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
              Expanded(child: _buildGallery(context, theme)),
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
      ),
    );
  }

  Widget _buildGallery(BuildContext context, ThemeData theme) {
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
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: _compactActionStyle(theme),
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
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Nenhum resultado para os filtros selecionados.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      controller: _scrollCtrl,
      itemCount: _items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _PopCard(
          index: i,
          item: _items[i],
          onOpen: () => _openPdf(_items[i]),
          theme: theme,
        ),
      ),
    );
  }
}

class _PopCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  final ThemeData theme;

  const _PopCard({
    required this.index,
    required this.item,
    required this.onOpen,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final id = _toInt(item['id']);
    final titulo = (item['titulo'] ?? '') as String;
    final numero = (item['numero'] ?? '') as String;
    final dataPub = (item['data_publicacao'] ?? '') as String;
    final tag = 'pop-$id';
    final delay = (index * 40).clamp(0, 220);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
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
      child: Hero(
        tag: tag,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (dataPub.isNotEmpty || numero.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (numero.isNotEmpty)
                                Text(
                                  'Nº $numero',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              if (numero.isNotEmpty && dataPub.isNotEmpty)
                                const SizedBox(width: 8),
                              if (dataPub.isNotEmpty)
                                Text(
                                  _br(dataPub),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    color: theme.colorScheme.primary,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
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
    final theme = Theme.of(context);
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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
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
