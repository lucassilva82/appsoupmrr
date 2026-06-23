import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';

// ── WidgetCarouselSlider ──────────────────────────────────────────────────────
// Exibe dois cards lado a lado: Comandante (índice 0) e Sub-Comandante (índice 1)
// Os dados ainda vêm da coleção 'stores' do Firestore.
class WidgetCarouselSlider extends StatelessWidget {
  WidgetCarouselSlider({Key? key}) : super(key: key);

  final Stream<List<Map<String, dynamic>>> _slides = FirebaseFirestore.instance
      .collection('stores')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _slides,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 170,
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const SizedBox(height: 8);
        }

        final list = snap.data!;
        final comandante = list.isNotEmpty ? list[0] : null;
        final sub = list.length > 1 ? list[1] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Altura responsiva: ~65% da largura disponível, clampada entre 200 e 280
              final cardHeight =
                  (constraints.maxWidth * 0.65).clamp(200.0, 280.0);
              return SizedBox(
                height: cardHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (comandante != null)
                      Expanded(
                        child: _ComandanteCard(
                          data: comandante,
                          label: 'Comandante',
                          icon: Icons.star_rounded,
                          iconColor: AppColors.gold,
                        ),
                      ),
                    if (comandante != null && sub != null)
                      const SizedBox(width: 10),
                    if (sub != null)
                      Expanded(
                        child: _ComandanteCard(
                          data: sub,
                          label: 'Sub-Comandante',
                          icon: Icons.shield_rounded,
                          iconColor: AppColors.lightBlue,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── _ComandanteCard ───────────────────────────────────────────────────────────
class _ComandanteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _ComandanteCard({
    Key? key,
    required this.data,
    required this.label,
    required this.icon,
    required this.iconColor,
  }) : super(key: key);

  @override
  State<_ComandanteCard> createState() => _ComandanteCardState();
}

class _ComandanteCardState extends State<_ComandanteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _elevation = Tween<double>(begin: 3.0, end: 14.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.reverse();
    });
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = (widget.data['img'] ?? '') as String;
    final title = (widget.data['title'] ?? '') as String;
    final subtitle = (widget.data['subtitle'] ?? '') as String;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Card(
            elevation: _elevation.value,
            shadowColor: theme.colorScheme.primary.withOpacity(0.35),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Foto ─────────────────────────────────────────────────────────
            Expanded(
              child: imageUrl.isNotEmpty &&
                      (imageUrl.startsWith('http://') ||
                          imageUrl.startsWith('https://'))
                  ? CachedImageFromPrefs(imageUrl: imageUrl)
                  : Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(Icons.person_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.4)),
                    ),
            ),

            // ── Rodapé do card (altura fixa para alinhar os dois cards) ───────
            SizedBox(
              height: 78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, size: 11, color: widget.iconColor),
                        const SizedBox(width: 3),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.iconColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    if (subtitle.isNotEmpty)
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que utiliza SharedPreferences para armazenar a imagem em cache (base64)
class CachedImageFromPrefs extends StatefulWidget {
  final String imageUrl;
  const CachedImageFromPrefs({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  _CachedImageFromPrefsState createState() => _CachedImageFromPrefsState();
}

class _CachedImageFromPrefsState extends State<CachedImageFromPrefs> {
  Widget? _cachedImageWidget;

  @override
  void initState() {
    super.initState();
    _loadImage().then((w) {
      if (mounted) setState(() => _cachedImageWidget = w);
    });
  }

  Future<Widget> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = "cached_image_${widget.imageUrl.hashCode}";
    if (prefs.containsKey(key)) {
      final bytes = base64Decode(prefs.getString(key)!);
      return Image.memory(bytes,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: double.infinity,
          height: double.infinity);
    }
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await prefs.setString(key, base64Encode(bytes));
        return Image.memory(bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            width: double.infinity,
            height: double.infinity);
      }
    } catch (e) {
      debugPrint("CachedImageFromPrefs error: $e");
    }
    return const Icon(Icons.broken_image_rounded, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return _cachedImageWidget ??
        Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        );
  }
}
