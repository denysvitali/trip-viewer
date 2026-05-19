import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/theme/app_theme.dart';
import 'package:trip_viewer/widgets/blocks/generic_block.dart';
import 'package:trip_viewer/widgets/place_image.dart';
import 'package:trip_viewer/widgets/text_container_widget.dart';

class PlaceBlockWidget extends StatefulWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;
  final Expense? expense;
  final bool compact;

  const PlaceBlockWidget({
    super.key,
    required this.placeBlock,
    required this.metadata,
    this.expense,
    this.compact = false,
  });

  @override
  State<PlaceBlockWidget> createState() => _PlaceBlockWidgetState();
}

class _PlaceBlockWidgetState extends State<PlaceBlockWidget> {
  static const double _compactHeight = 112;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return SizedBox(
        height: _compactHeight,
        child: GenericBlock(
          block: widget.placeBlock,
          accentColor: AppTheme.placeColor,
          child: _buildCompactRow(theme),
        ),
      );
    }

    return GenericBlock(
      block: widget.placeBlock,
      accentColor: AppTheme.placeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.placeBlock.imageKeys.isNotEmpty ||
              (widget.metadata != null &&
                  widget.metadata!.imageKeys.isNotEmpty))
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: PlaceImage(
                    block: widget.placeBlock, metadata: widget.metadata),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                if (widget.metadata?.rating != null) ...[
                  const SizedBox(height: 6),
                  _buildRating(theme),
                ],
                // User's rich text note (TextContainer)
                if (_hasPlaceText()) ...[
                  const SizedBox(height: 8),
                  _buildPlaceText(theme),
                ],
                // Fallback: plain description string
                if (!_hasPlaceText() &&
                    widget.placeBlock.description != null) ...[
                  const SizedBox(height: 8),
                  _buildExpandableDescription(
                      theme, widget.placeBlock.description!),
                ],
                // Metadata description (from Google/generated)
                if (widget.metadata?.description != null ||
                    widget.metadata?.generatedDescription != null) ...[
                  const SizedBox(height: 8),
                  _buildExpandableDescription(
                    theme,
                    widget.metadata!.description ??
                        widget.metadata!.generatedDescription ??
                        '',
                  ),
                ],
                if (widget.placeBlock.hotel != null) ...[
                  const SizedBox(height: 10),
                  _buildHotelInfo(theme),
                ],
                if (widget.expense != null) ...[
                  const SizedBox(height: 8),
                  _buildExpenseRow(theme),
                ],
                if (widget.placeBlock.place.formattedAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.placeBlock.place.formattedAddress,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(ThemeData theme) {
    final details = _compactDetails();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactLeading(theme),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.placeBlock.place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.placeBlock.startTime != null) ...[
                      const SizedBox(width: 8),
                      _buildCompactTime(theme),
                    ],
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.metadata?.rating != null) ...[
                            _buildCompactMeta(
                              theme,
                              Icons.star_rounded,
                              '${widget.metadata!.rating}',
                              iconColor: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (widget.expense != null) ...[
                            _buildCompactMeta(
                              theme,
                              Icons.receipt_outlined,
                              widget.expense!.amount.format(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (widget
                              .placeBlock.place.formattedAddress.isNotEmpty)
                            _buildCompactMeta(
                              theme,
                              Icons.location_on_outlined,
                              widget.placeBlock.place.formattedAddress,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLeading(ThemeData theme) {
    final hasImage = widget.placeBlock.imageKeys.isNotEmpty ||
        (widget.metadata != null && widget.metadata!.imageKeys.isNotEmpty);

    return SizedBox(
      width: 88,
      child: hasImage
          ? PlaceImage(block: widget.placeBlock, metadata: widget.metadata)
          : ColoredBox(
              color: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.place,
                size: 22,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
    );
  }

  Widget _buildCompactTime(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule,
            size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          [
            widget.placeBlock.startTime,
            if (widget.placeBlock.endTime != null) widget.placeBlock.endTime
          ].join(' - '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMeta(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactDetails() {
    final placeText = _plainPlaceText();
    if (placeText.isNotEmpty) return placeText;
    final description = widget.placeBlock.description;
    if (description != null && description.trim().isNotEmpty) {
      return description.trim();
    }
    final metadataDescription =
        widget.metadata?.description ?? widget.metadata?.generatedDescription;
    if (metadataDescription != null && metadataDescription.trim().isNotEmpty) {
      return metadataDescription.trim();
    }
    final hotel = widget.placeBlock.hotel;
    if (hotel == null) return '';
    return [
      if (hotel.checkIn != null) 'Check-in ${hotel.checkIn}',
      if (hotel.checkOut != null) 'Check-out ${hotel.checkOut}',
      if (hotel.confirmationNumber != null)
        'Confirmation ${hotel.confirmationNumber}',
    ].join(', ');
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.placeBlock.place.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.placeBlock.startTime != null) ...[
          Icon(Icons.schedule,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            [
              widget.placeBlock.startTime,
              if (widget.placeBlock.endTime != null) widget.placeBlock.endTime
            ].join(' - '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  bool _hasPlaceText() {
    final text = widget.placeBlock.text;
    if (text == null) return false;
    final content = text.ops.map((op) => op.insert).join().trim();
    return content.isNotEmpty;
  }

  String _plainPlaceText() {
    final text = widget.placeBlock.text;
    if (text == null) return '';
    return text.ops.map((op) => op.insert).join().trim();
  }

  Widget _buildPlaceText(ThemeData theme) {
    return TextContainerWidget(textContainer: widget.placeBlock.text!);
  }

  Widget _buildRating(ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '${widget.metadata!.rating}',
          style:
              theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (widget.metadata!.numRatings != null) ...[
          const SizedBox(width: 4),
          Text(
            '(${_formatNumber(widget.metadata!.numRatings!)})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpenseRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_outlined,
              size: 14, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            widget.expense!.amount.format(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDescription(ThemeData theme, String description) {
    final isLong = description.length > 150;
    final displayText = _isExpanded || !isLong
        ? description
        : '${description.substring(0, 150)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'Show less' : 'Show more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHotelInfo(ThemeData theme) {
    final hotel = widget.placeBlock.hotel!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hotel,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Hotel Information',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (hotel.checkIn != null) ...[
            const SizedBox(height: 6),
            _infoRow(theme, Icons.login, 'Check-in: ${hotel.checkIn}'),
          ],
          if (hotel.checkOut != null) ...[
            const SizedBox(height: 4),
            _infoRow(theme, Icons.logout, 'Check-out: ${hotel.checkOut}'),
          ],
          if (hotel.confirmationNumber != null) ...[
            const SizedBox(height: 4),
            _infoRow(theme, Icons.confirmation_number,
                'Confirmation: ${hotel.confirmationNumber}'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}k';
    return number.toString();
  }
}
