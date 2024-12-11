import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

String getImageUrlById(String id) {
  return 'https://itin-dev.sfo2.cdn.digitaloceanspaces.com/freeImage/$id';
}

String? getImageUrl(Block block, PlaceMetadata? metadata) {
  if (block.imageKeys.isNotEmpty) {
    return getImageUrlById(block.imageKeys.first);
  } else if (metadata != null && metadata.imageKeys.isNotEmpty) {
    return getImageUrlById(metadata.imageKeys.first);
  } else {
    return null;
  }
}

class PlaceImage extends StatelessWidget {
  final Block block;
  final PlaceMetadata? metadata;

  const PlaceImage({
    super.key,
    required this.block,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    String? imageUrl = getImageUrl(block, metadata);
    if (imageUrl == null) {
      return Container();
    } else {
      return ConstrainedBox(
          constraints: const BoxConstraints.expand(height: 300),
          child: Image(
            fit: BoxFit.fitWidth,
            image: CachedNetworkImageProvider(imageUrl),
          ));
    }
  }
}
