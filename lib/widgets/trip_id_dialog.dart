import 'package:flutter/material.dart';

class TripIdDialog extends StatefulWidget {
  const TripIdDialog({super.key});

  @override
  State<TripIdDialog> createState() => _TripIdDialogState();
}

class _TripIdDialogState extends State<TripIdDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Trip ID'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'e.g., 231238sdfkldf',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
