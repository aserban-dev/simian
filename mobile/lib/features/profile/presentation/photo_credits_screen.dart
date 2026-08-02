/// Photo credits (T121).
///
/// FR-075 and the constitution's image-licensing rule: assets are re-hosted from sources whose
/// terms permit it (Pexels, Pixabay, Burst), and those terms require attribution. Capturing the
/// photographer at ingest is only half of complying — this screen is the other half.
///
/// It is reachable from the profile rather than buried, and it lists every distinct credit once
/// rather than per image, because the same photographer usually supplies several.
library;

import 'package:flutter/material.dart';

import '../../catalogue/domain/catalogue_models.dart';

class PhotoCreditsScreen extends StatelessWidget {
  const PhotoCreditsScreen({
    required this.images,
    this.onOpenSource,
    super.key,
  });

  /// Every image whose licence requires a credit. Images without attribution are simply absent.
  final List<ProductImage> images;

  final void Function(String url)? onOpenSource;

  static const String title = 'Photo credits';
  static const String intro =
      'Product photography is used under licence from the sources below. Thank you to the '
      'photographers who made their work available.';
  static const String emptyBody = 'No photo credits to show yet.';

  /// One entry per photographer-and-source pair, in a stable order.
  List<({String photographer, String source, String? url})> get credits {
    final seen = <String>{};
    final out = <({String photographer, String source, String? url})>[];
    for (final ProductImage image in images) {
      final String? photographer = image.photographer;
      final String? source = image.source;
      if (photographer == null || photographer.isEmpty || source == null || source.isEmpty) {
        continue;
      }
      final String key = '$photographer|$source';
      if (seen.add(key)) {
        out.add((photographer: photographer, source: source, url: image.sourceUrl));
      }
    }
    out.sort((a, b) => a.photographer.toLowerCase().compareTo(b.photographer.toLowerCase()));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<({String photographer, String source, String? url})> entries = credits;

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(intro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text(emptyBody, style: theme.textTheme.bodyMedium)
            else
              for (final ({String photographer, String source, String? url}) credit in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(credit.photographer, style: theme.textTheme.titleSmall),
                      Text(credit.source, style: theme.textTheme.bodySmall),
                      if (credit.url != null && onOpenSource != null)
                        TextButton(
                          onPressed: () => onOpenSource!(credit.url!),
                          child: const Text('View source'),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
