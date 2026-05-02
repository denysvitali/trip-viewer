import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_viewer/models/trip_plan.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (block.place.url == null) return;
          try {
            await launchUrl(
              Uri.parse(block.place.url!),
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
