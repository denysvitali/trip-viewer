import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class _DateLabel extends StatelessWidget {
  final DateTime date;
  final BuildContext context;

  const _DateLabel({required this.date, required this.context});

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('E, MMM d').format(date),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _CheckInOutIcon extends StatelessWidget {
  final bool isCheckIn;

  const _CheckInOutIcon({required this.isCheckIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(isCheckIn ? Icons.login : Icons.logout, size: 20),
        const SizedBox(height: 14),
        Text(
          isCheckIn ? 'Check-in' : 'Check-out',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 2,
      height: 30,
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}

class StayDateInfo extends StatelessWidget {
  final DateTime date;
  final bool isCheckIn;

  const StayDateInfo({
    super.key,
    required this.date,
    this.isCheckIn = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DateLabel(date: date, context: context),
        const SizedBox(height: 14),
        _CheckInOutIcon(isCheckIn: isCheckIn),
      ],
    );
  }
}

class _HotelInfo extends StatelessWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;

  const _HotelInfo({required this.placeBlock, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        if (placeBlock.hotel?.confirmationNumber != null)
          _ConfirmationNumber(number: placeBlock.hotel!.confirmationNumber!),
      ],
    );
  }
}

class _ConfirmationNumber extends StatelessWidget {
  final String number;

  const _ConfirmationNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.confirmation_number,
          size: 18,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 8),
        Text(
          number,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class HotelBlock extends StatefulWidget {
  final PlaceBlock placeBlock;
  final PlaceMetadata? metadata;
  final bool initiallyExpanded;

  const HotelBlock({
    super.key,
    required this.placeBlock,
    required this.metadata,
    this.initiallyExpanded = true,
  });

  @override
  State<HotelBlock> createState() => _HotelBlockState();
}

class _HotelBlockState extends State<HotelBlock>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Widget _buildCompressedView() {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.placeBlock.place.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('MMM d').format(DateTime.parse(widget.placeBlock.hotel?.checkIn ?? ''))} - ${DateFormat('MMM d').format(DateTime.parse(widget.placeBlock.hotel?.checkOut ?? ''))}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleExpanded,
        onLongPress: () {
          if (widget.placeBlock.place.url != null) {
            launchUrl(
              Uri.parse(widget.placeBlock.place.url!),
              mode: LaunchMode.externalApplication,
            );
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              children: [
                _buildCompressedView(),
                ClipRect(
                  child: Align(
                    heightFactor: _heightFactor.value,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildDateSection(context),
                              const SizedBox(height: 16),
                              if (widget.metadata?.description != null ||
                                  widget.metadata?.generatedDescription != null)
                                Text(
                                  widget.metadata?.description ??
                                      widget.metadata?.generatedDescription ??
                                      '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              const Divider(height: 24),
                              _HotelInfo(
                                placeBlock: widget.placeBlock,
                                metadata: widget.metadata,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StayDateInfo(
            date: DateTime.parse(widget.placeBlock.hotel?.checkIn ?? ''),
            isCheckIn: true,
          ),
        ),
        Column(
          children: [
            const _DividerLine(),
            Icon(
              Icons.hotel,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const _DividerLine(),
          ],
        ),
        Expanded(
          child: StayDateInfo(
            date: DateTime.parse(widget.placeBlock.hotel?.checkOut ?? ''),
            isCheckIn: false,
          ),
        ),
      ],
    );
  }
}
