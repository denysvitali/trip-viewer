import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';
import 'package:intl/intl.dart';

class StationInfo extends StatelessWidget {
  final DepartArrivePlace info;
  final bool isDeparture;

  const StationInfo({
    super.key,
    required this.info,
    this.isDeparture = true,
  });

  String _formatDate(String date) {
    final dt = DateTime.parse(date);
    return DateFormat('E, MMM d').format(dt);
  }

  String _formatTime(String time) {
    final dt = DateTime.parse('2024-01-01T$time');
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatDate(info.date),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
        if (info.time != null)
          Text(
            _formatTime(info.time!),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        const SizedBox(height: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                if (info.place.url != null) {
                  launchUrl(
                    Uri.parse(info.place.url!),
                    webOnlyWindowName: '_blank',
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      info.place.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.place.formattedAddress,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TransitFooter extends StatelessWidget {
  final TransitBlock transitBlock;
  final Expense? expense;

  const TransitFooter({super.key, required this.transitBlock, this.expense});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          transitBlock.carrier ?? '',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (transitBlock.confirmationNumber != null)
          Row(children: [
            Icon(
              Icons.confirmation_number,
              color: Theme.of(context).colorScheme.secondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              transitBlock.confirmationNumber ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ]),
        if (expense != null)
          Row(children: [
            Icon(
              Icons.attach_money,
              color: Theme.of(context).colorScheme.secondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '${expense!.amount} ${expense!.currencyCode}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ]),
      ]),
    );
  }
}

enum TransitType {
  bus,
  train,
  other,
}

class TransitBlockWidget extends StatefulWidget {
  final TransitBlock transitBlock;
  final bool initiallyExpanded;
  final TransitType transitType;
  final Expense? expense;

  const TransitBlockWidget({
    super.key,
    required this.transitBlock,
    required this.transitType,
    this.initiallyExpanded = true,
    this.expense,
  });

  @override
  State<TransitBlockWidget> createState() => _TransitBlockWidgetState();
}

class _TransitBlockWidgetState extends State<TransitBlockWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  IconData _getTransitTypeIcon() {
    switch (widget.transitType) {
      case TransitType.bus:
        return Icons.directions_bus;
      case TransitType.train:
        return Icons.train;
      default:
        return Icons.emoji_transportation;
    }
  }

  Widget _buildCompressedView(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _toggleExpanded,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _CompressedStationInfo(info: widget.transitBlock.depart),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    _getTransitTypeIcon(),
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.transitBlock.carrier ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
              Expanded(
                child: _CompressedStationInfo(info: widget.transitBlock.arrive),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StationInfo(
                      info: widget.transitBlock.depart,
                      isDeparture: true,
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 2,
                        height: 50,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      Icon(
                        _getTransitTypeIcon(),
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 2,
                        height: 50,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                  Expanded(
                    child: StationInfo(
                      info: widget.transitBlock.arrive,
                      isDeparture: false,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    _getTransitTypeIcon(),
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  TransitFooter(transitBlock: widget.transitBlock, expense: widget.expense),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isExpanded
        ? _buildExpandedView(context)
        : _buildCompressedView(context);
  }
}

class _CompressedStationInfo extends StatelessWidget {
  final DepartArrivePlace info;
  const _CompressedStationInfo({required this.info});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          info.place.name,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        if (info.time != null)
          Text(
            StationInfo(info: info)._formatTime(info.time!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        Text(
          StationInfo(info: info)._formatDate(info.date),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
