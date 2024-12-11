import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onTripIdChanged;

  const SettingsPage({
    super.key,
    required this.onTripIdChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tripIdController = TextEditingController();
  static const String tripIdKey = 'tripId';

  @override
  void initState() {
    super.initState();
    _loadTripId();
  }

  Future<void> _loadTripId() async {
    final prefs = await SharedPreferences.getInstance();
    final tripId = prefs.getString(tripIdKey) ?? '';
    setState(() {
      _tripIdController.text = tripId;
    });
  }

  Future<void> _saveTripId(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tripIdKey, tripId);
    widget.onTripIdChanged(tripId);
  }

  Future<void> _showTripIdDialog() async {
    final TextEditingController dialogController =
        TextEditingController(text: _tripIdController.text);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Trip ID'),
        content: TextField(
          controller: dialogController,
          decoration: const InputDecoration(
            labelText: 'Trip ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveTripId(dialogController.text);
              setState(() {
                _tripIdController.text = dialogController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Trip ID'),
              subtitle: Text(_tripIdController.text.isEmpty
                  ? 'Not set'
                  : _tripIdController.text),
              trailing: const Icon(Icons.edit),
              onTap: _showTripIdDialog,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tripIdController.dispose();
    super.dispose();
  }
}
