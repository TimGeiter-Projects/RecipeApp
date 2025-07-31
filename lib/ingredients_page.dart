import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'data/ingredients.dart';
import '../services/scanner.dart';
import '../data/IngriedientEntry.dart';
import '../services/inventory_service.dart';

// Define your standard units here
const List<String> kAppUnits = [
  'g',
  'kg',
  'ml',
  'l',
  'piece',
  'can',
  'pack',
];

class IngredientsPage extends StatefulWidget {
  const IngredientsPage({super.key});

  @override
  State<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'piece';

  late InventoryService _inventoryService;

  Map<String, List<IngredientEntry>> _ingredientCountVegetables = {};
  Map<String, List<IngredientEntry>> _ingredientCountMain = {};
  Map<String, List<IngredientEntry>> _ingredientCountSpices = {};
  Map<String, List<IngredientEntry>> _ingredientCountOthers = {};
  Map<String, Map<String, dynamic>> _lastUsedUnits = {};


  final Map<String, bool> _expandedIngredients = {};
  bool _deleteMode = false;
  final Key _visibilityDetectorKey = const Key('ingredients_page_visibility_detector');

  TextEditingController _autocompleteController = TextEditingController();


  @override
  void initState() {
    super.initState();
    print("IngredientsPage: initState called");
    WidgetsBinding.instance.addObserver(this);
    _inventoryService = InventoryService();
    _loadAllData();
    _controller.addListener(_onIngredientTextChanged);
    _autocompleteController.text = _controller.text;
  }

  @override
  void dispose() {
    print("IngredientsPage: dispose called");
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onIngredientTextChanged);
    _controller.dispose();
    _quantityController.dispose();
    _autocompleteController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    print("IngredientsPage: _loadAllData called.");
    try {
      await _inventoryService.loadInventory();
      await _inventoryService.loadLastUsedUnits();

      if (mounted) {
        setState(() {
          _ingredientCountVegetables = _inventoryService.ingredientCountVegetables;
          _ingredientCountMain = _inventoryService.ingredientCountMain;
          _ingredientCountSpices = _inventoryService.ingredientCountSpices;
          _ingredientCountOthers = _inventoryService.ingredientCountOthers;
          _lastUsedUnits = _inventoryService.lastUsedUnits;

          final Map<String, bool> newExpandedState = {};
          _inventoryService.ingredientCountVegetables.keys.forEach((key) => newExpandedState[key] = _expandedIngredients[key] ?? false);
          _inventoryService.ingredientCountMain.keys.forEach((key) => newExpandedState[key] = _expandedIngredients[key] ?? false);
          _inventoryService.ingredientCountSpices.keys.forEach((key) => newExpandedState[key] = _expandedIngredients[key] ?? false);
          _inventoryService.ingredientCountOthers.keys.forEach((key) => newExpandedState[key] = _expandedIngredients[key] ?? false);
          _expandedIngredients.clear();
          _expandedIngredients.addAll(newExpandedState);

          print("IngredientsPage: Data loaded and state updated successfully.");
        });
      }
    } catch (e) {
      print("IngredientsPage: Error loading data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("IngredientsPage: App came to foreground (resumed). Reloading inventory.");
      _loadAllData();
    }
  }

  void _onIngredientTextChanged() {
    final String ingredient = _controller.text.trim().toLowerCase();
    if (ingredient.isNotEmpty) {
      _proposeDefaultUnit(ingredient);
    } else {
      setState(() {
        _selectedUnit = 'piece';
        _quantityController.text = '1';
      });
    }
    if (_autocompleteController.text != _controller.text) {
      _autocompleteController.text = _controller.text;
    }
  }

  void _proposeDefaultUnit(String ingredientName) {
    String proposedUnit = 'piece';
    double proposedQuantity = 1.0;

    if (_lastUsedUnits.containsKey(ingredientName)) {
      proposedUnit = _lastUsedUnits[ingredientName]!['unit'] as String;
      proposedQuantity = _lastUsedUnits[ingredientName]!['quantity'] as double;
    } else {
      final String category = getCategoryForIngredient(ingredientName);
      switch (category) {
        case "Spices":
          proposedUnit = 'g';
          break;
        case "Main Ingredients":
        case "Others":
        case "Vegetables":
        default:
          break;
      }
    }

    if (proposedUnit != _selectedUnit || proposedQuantity != (double.tryParse(_quantityController.text) ?? 1.0)) {
      setState(() {
        _selectedUnit = proposedUnit;
        if (double.tryParse(_quantityController.text) != proposedQuantity) {
          _quantityController.text = proposedQuantity.toString();
        }
      });
    }
  }

  void _addIngredient() async {
    print("IngredientsPage: _addIngredient called.");
    final String ingredient = _controller.text.trim();
    if (ingredient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select an ingredient.')),
      );
      return;
    }

    final String normalizedIngredient = ingredient.toLowerCase();
    final String category = getCategoryForIngredient(normalizedIngredient);

    final double? quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
      );
      return;
    }

    final IngredientEntry newEntry = IngredientEntry(
      name: normalizedIngredient,
      dateAdded: DateTime.now(),
      category: category,
      unit: _selectedUnit,
      quantity: quantity,
    );

    try {
      await _inventoryService.addIngredient(newEntry);
      print("IngredientsPage: Called _inventoryService.addIngredient for: ${newEntry.name} and awaited its completion.");

      await _loadAllData();

      if (mounted) {
        setState(() {
          _controller.clear();
          _autocompleteController.clear();
          _quantityController.text = '1';
          _selectedUnit = 'piece';
          FocusScope.of(context).unfocus();
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$ingredient" (${quantity} ${_selectedUnit}) added to "$category"!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      print("IngredientsPage: Error adding ingredient: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add "$ingredient". Error: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }

  Future<void> _showAddIngredientDialog(String ingredientName, String category, String initialUnit) async {
    final TextEditingController dialogQuantityController = TextEditingController(text: '1');
    String dialogSelectedUnit = initialUnit;

    final String normalizedIngredientName = ingredientName.toLowerCase().trim();
    if (_lastUsedUnits.containsKey(normalizedIngredientName)) {
      dialogQuantityController.text = (_lastUsedUnits[normalizedIngredientName]!['quantity'] as double).toStringAsFixed(1);
      dialogSelectedUnit = (_lastUsedUnits[normalizedIngredientName]!['unit'] as String);
    } else if (initialUnit == 'g') {
      dialogQuantityController.text = '100';
    }


    bool? confirmAdd = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add "$ingredientName"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dialogQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: dialogSelectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: kAppUnits.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          dialogSelectedUnit = newValue!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? quantity = double.tryParse(dialogQuantityController.text.trim());
                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid quantity.')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmAdd == true) {
      final double quantity = double.parse(dialogQuantityController.text.trim());
      await _addIngredientWithQuantityAndUnit(ingredientName, category, dialogSelectedUnit, quantity);
    }

    dialogQuantityController.dispose();
  }


  Future<void> _addIngredientWithQuantityAndUnit(String ingredientName, String category, String unit, double quantity) async {
    print("IngredientsPage: _addIngredientWithQuantityAndUnit called for $ingredientName (${quantity} ${unit}).");

    final IngredientEntry newEntry = IngredientEntry(
      name: ingredientName.toLowerCase(),
      dateAdded: DateTime.now(),
      category: category,
      unit: unit,
      quantity: quantity,
    );

    try {
      await _inventoryService.addIngredient(newEntry);
      print("IngredientsPage: Called _inventoryService.addIngredient for: ${newEntry.name} and awaited its completion.");

      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${quantity.toStringAsFixed(quantity.toInt() == quantity ? 0 : 1)} "${ingredientName}" (${unit}) added to "$category"!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[600],
        ));
      }
    } catch (e) {
      print("IngredientsPage: Error adding ingredient: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add "${ingredientName}". Error: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[600],
        ));
      }
    }
  }


// ... (Dein Code vor der Methode _showAdjustQuantityDialog) ...

  // FINAL KORRIGIERTE Methode: _showAdjustQuantityDialog
  Future<void> _showAdjustQuantityDialog(IngredientEntry entryToAdjust, String ingredientKey, String categoryMapKey) async {
    // Controller wird mit der AKTUELLE MENGE vorbefüllt.
    final TextEditingController dialogQuantityController = TextEditingController(
        text: entryToAdjust.quantity.toStringAsFixed(entryToAdjust.quantity.toInt() == entryToAdjust.quantity ? 0 : 1)
    );
    final String currentUnit = entryToAdjust.unit;

    bool? confirmAdjust = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Titel: "Menge abziehen" oder "Entfernen" passt hier am besten.
          title: Text('Remove / Deduct "${entryToAdjust.name}"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current amount: ${entryToAdjust.quantity.toStringAsFixed(entryToAdjust.quantity.toInt() == entryToAdjust.quantity ? 0 : 1)} ${entryToAdjust.unit} added on ${DateFormat('MM/dd/yyyy').format(entryToAdjust.dateAdded)}'),
                const SizedBox(height: 10),
                TextField(
                  controller: dialogQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    // Labeltext: "Menge zum Abziehen" ist hier der Kernpunkt.
                    labelText: 'Amount to deduct (${currentUnit})',
                    hintText: 'Enter amount to deduct', // Hinweis hinzufügen
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // HIER: Validierung der ABZUZIEHENDEN Menge
                final double? amountToDeduct = double.tryParse(dialogQuantityController.text.trim());

                if (amountToDeduct == null || amountToDeduct <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount to deduct (greater than 0).')),
                  );
                  return;
                }
                // HIER: Überprüfen, ob man nicht mehr abziehen will, als vorhanden ist.
                if (amountToDeduct > entryToAdjust.quantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cannot deduct ${amountToDeduct.toStringAsFixed(amountToDeduct.toInt() == amountToDeduct ? 0 : 1)} ${currentUnit}. Only ${entryToAdjust.quantity.toStringAsFixed(entryToAdjust.quantity.toInt() == entryToAdjust.quantity ? 0 : 1)} ${currentUnit} available.')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirm Deduct'), // Button-Text für Abzug
            ),
          ],
        );
      },
    );

    if (confirmAdjust == true) {
      // HIER: Die eingegebene Zahl ist die Menge, die ABGEZOGEN werden soll.
      final double amountToDeduct = double.parse(dialogQuantityController.text.trim());
      // Berechne die neue Restmenge.
      final double newQuantity = entryToAdjust.quantity - amountToDeduct;

      try {
        // Übergib die BERECHNETE NEUE GESAMTMENGE an den InventoryService.
        await _inventoryService.updateIngredientEntryQuantity(ingredientKey, categoryMapKey, entryToAdjust, newQuantity);
        await _loadAllData(); // UI aktualisieren

        if (mounted) {
          if (newQuantity <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Entry for "${entryToAdjust.name}" completely removed!'),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 2),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${amountToDeduct.toStringAsFixed(amountToDeduct.toInt() == amountToDeduct ? 0 : 1)} ${entryToAdjust.unit} of "${entryToAdjust.name}" deducted. Remaining: ${newQuantity.toStringAsFixed(newQuantity.toInt() == newQuantity ? 0 : 1)} ${entryToAdjust.unit}!'),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 2),
            ));
          }
        }
      } catch (e) {
        print("Error deducting ingredient quantity: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error deducting quantity: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }

    dialogQuantityController.dispose();
  }

// ... (Rest deines Codes) ...



  Future<void> _scanBarcode() async {
    String? barcode = await BarcodeScanner.scanBarcode(context);
    if (barcode != null && barcode.isNotEmpty) {
      String? productName = await BarcodeScanner.getProductNameFromBarcode(barcode);
      if (productName != null && productName.isNotEmpty) {
        String cleanName = productName.replaceAll(RegExp(r'^Product:\s*', caseSensitive: false), '');
        cleanName = cleanName.split('\n').first.trim();
        if (mounted) {
          setState(() {
            _controller.text = cleanName;
            _autocompleteController.text = cleanName;
            _proposeDefaultUnit(cleanName.toLowerCase());
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Barcode "$barcode" could not be matched to a product.'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange[800],
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("IngredientsPage: build called. _deleteMode: $_deleteMode");

    return VisibilityDetector(
      key: _visibilityDetectorKey,
      onVisibilityChanged: (visibilityInfo) {
        if (mounted && visibilityInfo.visibleFraction > 0.9) {
          print("IngredientsPage: Page became visible (VisibilityDetector). Loading inventory.");
          _loadAllData();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Inventory'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: const [],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final query = textEditingValue.text.toLowerCase();
                        if (query.isEmpty) {
                          return const Iterable<String>.empty();
                        }

                        final filteredIngredients = allIngredientsWithFrequency.where((ingredientMap) {
                          final String ingredientName = ingredientMap["name"] as String;
                          return ingredientName.toLowerCase().startsWith(query);
                        });

                        final sortedIngredients = filteredIngredients.toList()
                          ..sort((a, b) {
                            final int freqA = a["frequency"] as int;
                            final int freqB = b["frequency"] as int;
                            final int compareFreq = freqB.compareTo(freqA);
                            if (compareFreq != 0) {
                              return compareFreq;
                            }
                            final String nameA = a["name"] as String;
                            final String nameB = b["name"] as String;
                            return nameA.compareTo(nameB);
                          });

                        return sortedIngredients.map((ingredientMap) => ingredientMap["name"] as String);
                      },
                      onSelected: (selection) {
                        _controller.text = selection;
                        _autocompleteController.text = selection;
                        _proposeDefaultUnit(selection.toLowerCase());
                        FocusScope.of(context).unfocus();
                      },
                      fieldViewBuilder: (BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted) {
                        _autocompleteController = fieldTextEditingController;

                        return TextField(
                          controller: _autocompleteController,
                          focusNode: fieldFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Search / enter ingredient',
                            suffixIcon: (_autocompleteController.text.isNotEmpty)
                                ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                _autocompleteController.clear();
                                _quantityController.text = '1';
                                _selectedUnit = 'piece';
                                fieldFocusNode.requestFocus();
                              },
                            )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (text) {
                            _controller.text = text;
                            _onIngredientTextChanged();
                          },
                          onSubmitted: (_) {
                            _controller.text = _autocompleteController.text;
                            _addIngredient();
                          },
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                    tooltip: 'Scan barcode',
                  )
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addIngredient(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: kAppUnits.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedUnit = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Inventory'),
                onPressed: _addIngredient,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _inventoryService.areAllInventoriesEmpty()
                    ? const Center(child: Text(
                    'No ingredients in inventory.\nAdd some or scan a barcode!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : ListView(
                  children: [
                    _buildCategoryTile('Vegetables', _ingredientCountVegetables, 'Vegetables'),
                    _buildCategoryTile('Main ingredients', _ingredientCountMain, 'Main Ingredients'),
                    _buildCategoryTile('Spices', _ingredientCountSpices, 'Spices'),
                    _buildCategoryTile('Others', _ingredientCountOthers, 'Others'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildCategoryTile(String title, Map<String, List<IngredientEntry>> ingredientMap, String categoryKey) {
    List<String> sortedKeys = ingredientMap.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    String displayTitle = title.replaceAllMapped(
        RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').trim();

    return ExpansionTile(
      title: Text(displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      initiallyExpanded: ingredientMap.isNotEmpty,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      collapsedBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      trailing: null, // Entfernt den Standard-Pfeil der ExpansionTile, da wir eigene Icons verwenden
      children: sortedKeys.isEmpty
          ? [const ListTile(dense: true, title: Text('No ingredients in this category.'))]
          : sortedKeys.map((key) {
        String displayKey = key.length > 1 ? '${key[0].toUpperCase()}${key.substring(1)}' : key.toUpperCase();
        final List<IngredientEntry> entries = ingredientMap[key]!;

        // Aggregierte Mengen für die Übersichts-Ansicht berechnen
        final Map<String, double> aggregatedQuantities = {};
        String defaultUnitForAddButton = 'piece'; // Standardeinheit für den "Hinzufügen"-Button
        if (entries.isNotEmpty) {
          final Map<String, int> unitCounts = {};
          for (var entry in entries) {
            aggregatedQuantities.update(
              entry.unit,
                  (value) => value + entry.quantity,
              ifAbsent: () => entry.quantity,
            );
            unitCounts.update(entry.unit, (value) => value + 1, ifAbsent: () => 1);
          }
          // Die am häufigsten verwendete Einheit als Standard vorschlagen
          defaultUnitForAddButton = unitCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }

        // Formatierte Anzeige der aggregierten Mengen (z.B. "500g, 2 pieces")
        final String quantityDisplay = aggregatedQuantities.entries
            .map((e) {
          final String formattedQuantity = e.value == e.value.toInt()
              ? e.value.toInt().toString() // Wenn ganze Zahl, als ganze Zahl anzeigen
              : e.value.toStringAsFixed(1); // Sonst mit einer Dezimalstelle
          return '${formattedQuantity} ${e.key}';
        })
            .join(', ');

        // Zustand, ob die spezifischen Einträge dieser Zutat aufgeklappt sind
        final bool isExpanded = _expandedIngredients[key] ?? false;

        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicWidth( // Sorgt dafür, dass der Text nur den benötigten Platz einnimmt
                    child: Text(
                      displayKey,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded( // Nimmt den restlichen Platz ein
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible( // Ermöglicht das Kürzen des Textes bei Platzmangel
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 0.8),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              quantityDisplay,
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                              overflow: TextOverflow.ellipsis, // Text kürzen, wenn zu lang
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Zutat hinzufügen"-Knopf für die gesamte Zutat
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                    onPressed: () => _showAddIngredientDialog(key, categoryKey, defaultUnitForAddButton),
                    tooltip: 'Add ${displayKey}',
                  ),
                  // Der Pfeil-Knopf zum Auf- und Zuklappen der einzelnen Einträge
                  IconButton(
                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _expandedIngredients[key] = !isExpanded;
                      });
                    },
                    tooltip: isExpanded ? 'Collapse details' : 'Show all entries',
                  ),
                ],
              ),
              onTap: () { // Auch der Tap auf die ListTile selbst soll aufklappen
                setState(() {
                  _expandedIngredients[key] = !isExpanded;
                });
              },
              dense: true, // Macht die ListTile kompakter
            ),
            // Wenn die Zutat aufgeklappt ist, zeige die einzelnen Einträge an
            if (isExpanded)
              Column(
                children: [
                  ...entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 32.0), // Einrückung für Sub-Einträge
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IntrinsicWidth(
                              child: Text(
                                displayKey, // Hier den Zutaten-Namen anzeigen (könnte auch weggelassen werden, da oben schon genannt)
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey, width: 0.8),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        // Anzeige der spezifischen Menge und Einheit
                                        '${entry.quantity.toStringAsFixed(entry.quantity.toInt() == entry.quantity ? 0 : 1)} ${entry.unit}',
                                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey, width: 0.8),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        // Anzeige des Datums
                                        DateFormat('MM/dd/yyyy').format(entry.dateAdded),
                                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Der "Bearbeiten/Löschen"-Knopf für den spezifischen Eintrag
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, // Bleistift-Icon für Bearbeiten
                              color: Colors.orange.shade700, size: 20),
                          onPressed: () => _showAdjustQuantityDialog(
                              entry, key, categoryKey), // Aufruf des Anpassungs-Dialogs
                          tooltip: 'Adjust quantity or delete this entry',
                        ),
                        dense: true,
                      ),
                    );
                  }).toList(),
                ],
              ),
          ],
        );
      }).toList(),
    );
  }
}