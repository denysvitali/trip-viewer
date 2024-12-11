import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

String getImageUrl(Block block) {
  return 'https://itin-dev.sfo2.cdn.digitaloceanspaces.com/freeImage/${block.imageKeys[0]}';
}

class PlaceImage extends StatelessWidget {
  final Block block;

  PlaceImage({
    super.key,
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    if (block.imageKeys.isNotEmpty) {
      return Image(
        fit: BoxFit.fitWidth,
        image: CachedNetworkImageProvider(
          getImageUrl(block),
        ),
      );
    }
    return const SizedBox();
  }
}
