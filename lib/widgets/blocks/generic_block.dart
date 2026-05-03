import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:url_launcher/url_launcher.dart';

class GenericBlock extends StatelessWidget {
  final PlaceBlock block;
  final Widget child;
  final Color? accentColor;

  const GenericBlock({
    super.key,
    required this.block,
    required this.child,
    this.accentColor,
  });

  Uri? _mapsUri() {
    final url = block.place.url;
    if (url != null && url.isNotEmpty) {
      return Uri.tryParse(url);
    }

    final placeId = block.place.placeId;
    if (placeId.isEmpty) return null;

    return Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': block.place.name,
        'query_place_id': placeId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final uri = _mapsUri();
          if (uri == null) return;
          try {
            await launchUrl(
              uri,
              webOnlyWindowName: '_blank',
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
            log("unable to launch URL", error: e);
          }
        },
        child: accentColor != null
            ? IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              )
            : child,
      ),
    );
  }
}
