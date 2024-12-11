import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/widgets/blocks/generic_block.dart';
import 'package:wanderlog_alt/widgets/place_image.dart';

class PlaceBlockWidget extends StatelessWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;

  const PlaceBlockWidget({
    super.key,
    required this.placeBlock,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return GenericBlock(
      block: placeBlock,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placeBlock.imageKeys.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: PlaceImage(block: placeBlock),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeBlock.place.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (metadata != null)
                  Row(children: [
                    if (metadata!.description != null)
                      Text(metadata!.description!),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
