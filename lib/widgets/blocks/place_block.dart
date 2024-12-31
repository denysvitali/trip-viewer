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
                height: 250,
                width: double.infinity,
                child: PlaceImage(block: placeBlock, metadata: metadata),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                _body(context),
                if (placeBlock.price != null)
                  Text(
                    '${placeBlock.price!.amount} ${placeBlock.price!.currencyCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    List<Widget> children = [];
    children.add(
      Expanded(
          child: Text(
        placeBlock.place.name,
        style: Theme.of(context).textTheme.titleMedium,
      )),
    );

    String startEndTime = "";
    if (placeBlock.startTime != null) {
      startEndTime += placeBlock.startTime!;
    }
    if (placeBlock.endTime != null) {
      startEndTime += " - ";
      startEndTime += placeBlock.endTime!;
    }
    if (startEndTime != "") {
      children.addAll(
        [
          const Icon(
            Icons.access_time,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            startEndTime,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        ],
      );
    }
    return Row(children: children);
  }

  String formatNumber(int number) {
    if (number > 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  Widget _body(BuildContext context) {
    List<Widget> children = [];
    if (metadata == null) {
      return Container();
    }
    if (metadata!.rating != null) {
      children.addAll([
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.star,
              size: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              "${metadata!.rating} (${formatNumber(metadata!.numRatings!)})",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
      ]);
    }
    if (metadata!.description != null ||
        metadata!.generatedDescription != null) {
      children.add(
        ConstrainedBox(
          constraints:
              const BoxConstraints(maxHeight: 100, minWidth: double.infinity),
          child: Text(
            metadata!.description ?? metadata!.generatedDescription ?? '',
          ),
        ),
      );
    }
    return Column(children: children);
  }
}
