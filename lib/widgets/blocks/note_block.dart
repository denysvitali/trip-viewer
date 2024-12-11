import 'package:flutter/material.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

class NoteBlockWidget extends StatelessWidget {
  final NoteBlock block;
  const NoteBlockWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.text.ops
            .map(
              (e) => Text(
                e.insert.trimRight(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
            .toList(),
      ),
    );
  }
}
