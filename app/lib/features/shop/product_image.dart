import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/tokens.dart';

/// A product photo. Merchants upload either a link or the image itself (base64).
class ProductImage extends StatelessWidget {
  const ProductImage(this.source, {super.key, this.size, this.large = false});

  /// A big placeholder icon, for the product page.
  final bool large;
  final String source;
  final double? size;

  static final _cache = <String, Uint8List?>{};

  static Uint8List? _bytes(String s) {
    if (_cache.length > 60) _cache.clear(); // decoded photos are big; keep only a page's worth
    return _cache.putIfAbsent(s, () {
      try {
        return base64Decode(s.split(',').last.trim());
      } on FormatException {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = source.trim();
    // The prototype's .img / .hero: a soft navy gradient with an outline icon
    Widget placeholder() => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Tp.navySoft, Tp.surface2]),
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.package, color: Tp.navy2, size: large ? 72 : 40),
    );
    Widget img;
    if (s.isEmpty) {
      img = placeholder();
    } else if (s.startsWith('https://')) {
      img = Image.network(s, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder());
    } else {
      final bytes = _bytes(s);
      img = bytes == null ? placeholder() : Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder());
    }
    return SizedBox(
      width: size,
      height: size,
      child: ExcludeSemantics(child: img),
    );
  }
}
