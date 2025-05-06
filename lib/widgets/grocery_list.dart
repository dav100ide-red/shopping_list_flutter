import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/widgets/new_item.dart';
import 'package:http/http.dart' as http;

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _list = [];
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    final url = Uri.https(
      'flutterprep-6da46-default-rtdb.europe-west1.firebasedatabase.app',
      'shopping-list.json',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode >= 400) {
        setState(() {
          _error = 'http error, status code: ${response.statusCode}';
        });
      }

      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];
      for (final item in listData.entries) {
        final category =
            categories.entries
                .firstWhere(
                  (catItem) =>
                      catItem.value.description == item.value['category'],
                )
                .value;

        loadedItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }

      setState(() {
        _list = loadedItems;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'generic error';
      });
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(
      context,
    ).push<GroceryItem>(MaterialPageRoute(builder: (ctx) => const NewItem()));

    if (newItem == null) {
      return;
    }

    setState(() {
      _list.add(newItem);
    });
  }

  void _removeItem(GroceryItem item) async {
    final itemIndex = _list.indexOf(item);

    setState(() {
      _list.remove(item);
    });

    final url = Uri.https(
      'flutterprep-6da46-default-rtdb.europe-west1.firebasedatabase.app',
      'shopping-list/${item.id}.json',
    );

    final response = await http.delete(url);

    if (response.statusCode >= 400) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: const Text('BE error'),
        ),
      );
      setState(() {
        _list.insert(itemIndex, item);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent = const Center(child: Text('No items added yet'));

    if (_isLoading) {
      mainContent = const Center(child: CircularProgressIndicator());
    }

    if (_list.isNotEmpty) {
      mainContent = ListView.builder(
        itemCount: _list.length,
        itemBuilder:
            (ctx, index) => Dismissible(
              key: ValueKey(_list[index].id),
              onDismissed: (direction) {
                _removeItem(_list[index]);
              },
              child: ListTile(
                title: Text(_list[index].name),
                leading: Container(
                  width: 24,
                  height: 24,
                  color: _list[index].category.color,
                ),
                trailing: Text(_list[index].quantity.toString()),
              ),
            ),
      );
    }

    if (_error != null) {
      mainContent = Center(child: Text(_error!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your groceries"),
        actions: [IconButton(onPressed: _addItem, icon: const Icon(Icons.add))],
      ),
      body: mainContent,
    );
  }
}
