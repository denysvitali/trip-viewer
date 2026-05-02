import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:trip_viewer/theme/app_theme.dart';
import 'package:trip_viewer/widgets/text_container_widget.dart';

class NoteBlockWidget extends StatelessWidget {
  final NoteBlock block;
  const NoteBlockWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.noteColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Note',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextContainerWidget(textContainer: block.text),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
