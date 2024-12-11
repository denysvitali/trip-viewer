import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

void displayError(BuildContext ctx, e) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text('Error: $e'),
    ),
  );
}

class GenericBlock extends StatelessWidget {
  final PlaceBlock block;
  final Widget child;
  const GenericBlock({
    super.key,
    required this.block,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () async {
          if (block.place.url == null) {
            return;
          }
          Uri url = Uri.parse(block.place.url!);
          try {
            await launchUrl(
              url,
              webOnlyWindowName: '_blank',
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            if (context.mounted) {
              displayError(context, e);
            }
            log("unable to launch URL", error: e);
          }
        },
        child: child,
      ),
    );
  }
}
