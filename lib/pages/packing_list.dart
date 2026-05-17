import 'package:flutter/material.dart';
import 'package:trip_viewer/models/trip_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PackingItem {
  final String id;
  final String name;
  final String category;
  bool packed;

  PackingItem({
    required this.id,
    required this.name,
    required this.category,
    this.packed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'packed': packed,
      };

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        packed: json['packed'] ?? false,
      );
}

class PackingListPage extends StatefulWidget {
  final TripPlan tripPlan;
  final String? tripId;

  const PackingListPage({super.key, required this.tripPlan, this.tripId});

  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  final List<PackingItem> _items = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Essentials',
    'Clothing',
    'Toiletries',
    'Electronics',
    'Documents',
    'Other'
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String get _storageKey =>
      'packing_list_${widget.tripId ?? widget.tripPlan.title.replaceAll(' ', '_')}';

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString(_storageKey);

      if (itemsJson != null) {
        final List<dynamic> decodedItems = jsonDecode(itemsJson);
        final loadedItems =
            decodedItems.map((item) => PackingItem.fromJson(item)).toList();

        setState(() {
          _items.clear();
          _items.addAll(loadedItems);
        });
      } else {
        // If no items found, add some defaults based on trip data
        _addDefaultItems();
      }
    } catch (e) {
      _showErrorSnackBar('Error loading packing list: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addDefaultItems() {
    // Add some default items based on trip
    final defaultItems = [
      PackingItem(id: _generateId(), name: 'Passport', category: 'Documents'),
      PackingItem(
          id: _generateId(), name: 'Phone Charger', category: 'Electronics'),
      PackingItem(
          id: _generateId(), name: 'Toothbrush', category: 'Toiletries'),
      PackingItem(
          id: _generateId(), name: 'Medications', category: 'Essentials'),
    ];

    setState(() {
      _items.addAll(defaultItems);
    });

    _saveItems();
  }

  Future<void> _saveItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson =
          jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString(_storageKey, itemsJson);
    } catch (e) {
      _showErrorSnackBar('Error saving packing list: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _addItem(String name, String category) {
    if (name.trim().isEmpty) return;

    final newItem = PackingItem(
      id: _generateId(),
      name: name,
      category: category.isEmpty ? 'Other' : category,
    );

    setState(() {
      _items.add(newItem);
    });

    _saveItems();
  }

  void _toggleItemStatus(String id) {
    setState(() {
      final item = _items.firstWhere((item) => item.id == id);
      item.packed = !item.packed;
    });

    _saveItems();
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });

    _saveItems();
  }

  void _showAddItemDialog() {
    _nameController.clear();
    _categoryController.text = 'Other';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _categoryController.text,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: _categories.where((c) => c != 'All').map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _categoryController.text = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _addItem(_nameController.text, _categoryController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  List<PackingItem> _getFilteredItems() {
    if (_selectedCategory == 'All') {
      return _items;
    } else {
      return _items
          .where((item) => item.category == _selectedCategory)
          .toList();
    }
  }

  int _getCompletedItemsCount() {
    return _items.where((item) => item.packed).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final packedItems = filteredItems.where((item) => item.packed).toList();
    final unpackedItems = filteredItems.where((item) => !item.packed).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Packing List - ${widget.tripPlan.title}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${_getCompletedItemsCount()}/${_items.length} items packed',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _items.isEmpty
                            ? 0
                            : _getCompletedItemsCount() / _items.length,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                // Category filter
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Items list
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.backpack_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedCategory == 'All'
                                    ? 'No items in your packing list'
                                    : 'No ${_selectedCategory.toLowerCase()} items',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showAddItemDialog,
                                child: const Text('Add Item'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          children: [
                            if (unpackedItems.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  'To Pack',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ...unpackedItems.map(_buildPackingListItem),
                            ],
                            if (packedItems.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Packed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${packedItems.length})',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...packedItems.map(_buildPackingListItem),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPackingListItem(PackingItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _deleteItem(item.id),
      child: CheckboxListTile(
        value: item.packed,
        onChanged: (_) => _toggleItemStatus(item.id),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.packed ? TextDecoration.lineThrough : null,
            color: item.packed ? Colors.grey : null,
          ),
        ),
        subtitle: Text(item.category),
        secondary: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            _getCategoryIcon(item.category),
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Essentials':
        return Icons.star;
      case 'Clothing':
        return Icons.checkroom;
      case 'Toiletries':
        return Icons.bathroom;
      case 'Electronics':
        return Icons.devices;
      case 'Documents':
        return Icons.description;
      default:
        return Icons.category;
    }
  }
}
