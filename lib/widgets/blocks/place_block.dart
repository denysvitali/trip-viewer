import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:wanderlog_alt/widgets/blocks/generic_block.dart';
import 'package:wanderlog_alt/widgets/place_image.dart';

class PlaceBlockWidget extends StatefulWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;
  final Expense? expense;

  const PlaceBlockWidget({
    super.key,
    required this.placeBlock,
    required this.metadata,
    this.expense,
  });

  @override
  State<PlaceBlockWidget> createState() => _PlaceBlockWidgetState();
}

class _PlaceBlockWidgetState extends State<PlaceBlockWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GenericBlock(
      block: widget.placeBlock,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use user-preferred image from block.imageKeys if available
          if (widget.placeBlock.imageKeys.isNotEmpty ||
              (widget.metadata != null && widget.metadata!.imageKeys.isNotEmpty))
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 250,
                width: double.infinity,
                child: PlaceImage(block: widget.placeBlock, metadata: widget.metadata),
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
                // Hotel information
                if (widget.placeBlock.hotel != null) ...[
                  const SizedBox(height: 8),
                  _hotelInfo(context),
                ],
                // Price information
                if (widget.placeBlock.price != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.placeBlock.price!.amount.amount} ${widget.placeBlock.price!.amount.currencyCode}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                if (widget.expense != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.receipt, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.expense!.amount.amount} ${widget.expense!.amount.currencyCode}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                // User's custom description
                if (widget.placeBlock.description != null) ...[
                  const SizedBox(height: 8),
                  _expandableDescription(context, widget.placeBlock.description!),
                ],
                // Place address
                if (widget.placeBlock.place.formattedAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.placeBlock.place.formattedAddress,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                // Google Maps link
                if (widget.placeBlock.place.url != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      // Could launch URL here with url_launcher package
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.map, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'View on Google Maps',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        widget.placeBlock.place.name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      )),
    );

    String startEndTime = "";
    if (widget.placeBlock.startTime != null) {
      startEndTime += widget.placeBlock.startTime!;
    }
    if (widget.placeBlock.endTime != null) {
      startEndTime += " - ";
      startEndTime += widget.placeBlock.endTime!;
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
    if (widget.metadata == null) {
      return Container();
    }
    if (widget.metadata!.rating != null) {
      children.addAll([
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.star,
              size: 16,
              color: Colors.amber,
            ),
            const SizedBox(width: 4),
            Text(
              "${widget.metadata!.rating} (${formatNumber(widget.metadata!.numRatings!)})",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
      ]);
    }
    // Show metadata description (from Google/generated) with expand/collapse
    if (widget.metadata!.description != null ||
        widget.metadata!.generatedDescription != null) {
      final description =
          widget.metadata!.description ?? widget.metadata!.generatedDescription ?? '';
      children.add(_expandableDescription(context, description));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _expandableDescription(BuildContext context, String description) {
    final isLong = description.length > 150;
    final displayText = _isExpanded || !isLong
        ? description
        : '${description.substring(0, 150)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (isLong)
          TextButton(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isExpanded ? 'Show less' : 'Show more',
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _hotelInfo(BuildContext context) {
    final hotel = widget.placeBlock.hotel!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel, size: 16),
              const SizedBox(width: 4),
              Text(
                'Hotel Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          if (hotel.checkIn != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.login, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Check-in: ${hotel.checkIn}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (hotel.checkOut != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.logout, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Check-out: ${hotel.checkOut}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (hotel.confirmationNumber != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.confirmation_number, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Confirmation: ${hotel.confirmationNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
