import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderlog_alt/models/trip_plan.dart';

class TextContainerWidget extends StatelessWidget {
  final TextContainer textContainer;

  const TextContainerWidget({super.key, required this.textContainer});

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> textSpans = [];
    final defaultStyle = Theme.of(context).textTheme.bodyMedium;

    for (final op in textContainer.ops) {
      TextStyle style = defaultStyle ?? const TextStyle();
      GestureRecognizer? recognizer;

      if (op.attributes is Map<String, dynamic>) {
        final attrs = op.attributes as Map<String, dynamic>;
        bool isBold = attrs['bold'] == true;
        bool isItalic = attrs['italic'] == true;
        String? link = attrs['link'] as String?;

        style = style.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          color: link != null ? Colors.blue : null, // Style links
          decoration: link != null ? TextDecoration.underline : null,
        );

        if (link != null) {
          recognizer = TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(link);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                // Handle error: could not launch URL
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open link: $link')),
                );
              }
            };
        }
      }

      // Only add non-empty text spans
      if (op.insert.isNotEmpty) {
        textSpans.add(TextSpan(
          text: op.insert,
          style: style,
          recognizer: recognizer,
        ));
      }
    }

    if (textSpans.isEmpty) {
      return const SizedBox.shrink(); // Don't render if empty
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          children: textSpans,
          // Apply default style here if needed, though individual spans have styles
          // style: defaultStyle,
        ),
      ),
    );
  }
}
