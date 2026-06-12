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
          child: Row(
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
              if (comandante != null && sub != null) const SizedBox(width: 10),
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
    );
  }
}

// ── _ComandanteCard ───────────────────────────────────────────────────────────
class _ComandanteCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = (data['img'] ?? '') as String;
    final title = (data['title'] ?? '') as String;
    final subtitle = (data['subtitle'] ?? '') as String;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Foto ─────────────────────────────────────────────────────────
          SizedBox(
            height: 130,
            width: double.infinity,
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

          // ── Rodapé do card ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: iconColor),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
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
