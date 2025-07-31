import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/recipe.dart';
import 'services/recipe_service.dart';
import 'RecipeeditPage.dart';
import 'dart:developer';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class IngredientEntry {
  final String name;
  final DateTime dateAdded;
  final String unit;
  double quantity;

  IngredientEntry({
    required this.name,
    required this.dateAdded,
    required this.unit,
    required this.quantity,
  });


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateAdded': dateAdded.toIso8601String(),
      'unit': unit,
      'quantity': quantity,
    };
  }


  factory IngredientEntry.fromJson(Map<String, dynamic> json) {
    return IngredientEntry(
      name: json['name'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      unit: json['unit'] as String? ?? 'piece',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() {
    return 'IngredientEntry(name: $name, dateAdded: ${dateAdded.toIso8601String()}, unit: $unit, quantity: $quantity)';
  }
}

class InventoryIngredientEntry {
  final String name;
  final DateTime dateAdded;
  final String unit;
  double quantity;

  InventoryIngredientEntry({
    required this.name,
    required this.dateAdded,
    required this.unit,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateAdded': dateAdded.toIso8601String(),
      'unit': unit,
      'quantity': quantity,
    };
  }

  factory InventoryIngredientEntry.fromJson(Map<String, dynamic> json) {
    return InventoryIngredientEntry(
      name: json['name'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      unit: json['unit'] as String? ?? 'piece',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}


class SavedRecipesPage extends StatefulWidget {
  const SavedRecipesPage({super.key});

  @override
  State<SavedRecipesPage> createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> with WidgetsBindingObserver {
  final RecipeService _recipeService = RecipeService();
  late Future<List<Recipe>> _savedRecipesFuture;
  final Map<String, bool> _expandedStates = {};

  Map<String, List<InventoryIngredientEntry>> _vegetablesMap = {};
  Map<String, List<InventoryIngredientEntry>> _mainIngredientsMap = {};
  Map<String, List<InventoryIngredientEntry>> _spicesMap = {};
  Map<String, List<InventoryIngredientEntry>> _othersMap = {};


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log('SavedRecipesPage: App resumed, reloading recipes and inventory.');
      _loadInventory();
      _loadSavedRecipes();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log('SavedRecipesPage: didChangeDependencies called, reloading recipes and inventory.');
    _loadInventory();
    _loadSavedRecipes();
  }

  Future<void> _editRecipe(Recipe recipe) async {
    final Recipe? editedRecipe = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeEditPage(recipe: recipe),
      ),
    );

    if (editedRecipe != null) {
      try {
        await _recipeService.saveRecipeLocally(editedRecipe);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe "${editedRecipe.title}" updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadSavedRecipes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving the recipe: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    Map<String, List<InventoryIngredientEntry>> _decodeMap(String? jsonString) {
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
          return decodedMap.map((key, value) {
            final List<dynamic> entryListJson = value as List<dynamic>;
            final List<InventoryIngredientEntry> entries = entryListJson
                .map((entryJson) => InventoryIngredientEntry.fromJson(entryJson as Map<String, dynamic>))
                .toList();
            return MapEntry(key, entries);
          });
        } catch (e) {
          log('SavedRecipesPage: Error decoding map for inventory: $e, json: $jsonString');
          return {};
        }
      }
      return {};
    }

    if (!mounted) {
      log('SavedRecipesPage: _loadInventory - Widget not mounted, returning.');
      return;
    }

    setState(() {
      _vegetablesMap = _decodeMap(prefs.getString('Vegetables'));
      _mainIngredientsMap = _decodeMap(prefs.getString('Main Ingredients'));
      _spicesMap = _decodeMap(prefs.getString('Spices'));
      _othersMap = _decodeMap(prefs.getString('Others'));
      log('SavedRecipesPage: Inventory loaded: $_vegetablesMap, $_mainIngredientsMap, $_spicesMap, $_othersMap');
    });
  }

  void _loadSavedRecipes() {
    setState(() {
      _savedRecipesFuture = _recipeService.getSavedRecipesLocally();
    });
  }

  List<String> _getMissingIngredientsForRecipe(Recipe recipe) {
    if (recipe.usedIngredients.isEmpty) {
      return [];
    }

    final Set<String> recipeRequiredIngredientsNormalized = Set<String>.from(
      recipe.usedIngredients.map((i) => i.toLowerCase().trim()),
    );

    final Set<String> allAvailableInventoryIngredientsNormalized = {
      ..._vegetablesMap.keys.where((k) => (_vegetablesMap[k]?.isNotEmpty ?? false)).map((k) => k.toLowerCase().trim()),
      ..._mainIngredientsMap.keys.where((k) => (_mainIngredientsMap[k]?.isNotEmpty ?? false)).map((k) => k.toLowerCase().trim()),
      ..._spicesMap.keys.where((k) => (_spicesMap[k]?.isNotEmpty ?? false)).map((k) => k.toLowerCase().trim()),
      ..._othersMap.keys.where((k) => (_othersMap[k]?.isNotEmpty ?? false)).map((k) => k.toLowerCase().trim()),
    };

    final List<String> missing = [];
    for (String ingredient in recipeRequiredIngredientsNormalized) {
      if (!allAvailableInventoryIngredientsNormalized.contains(ingredient)) {
        if (ingredient.isNotEmpty) {
          String? originalIngredient = recipe.usedIngredients.firstWhereOrNull(
                (element) => element.toLowerCase().trim() == ingredient,
          );
          missing.add(originalIngredient ?? ingredient);
        }
      }
    }
    log('SavedRecipesPage: Missing ingredients for "${recipe.title}" (based on used ingredients): $missing');
    return missing;
  }

  Future<void> _showDeleteConfirmationDialog(String recipeId, String recipeTitle) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete recipe'),
          content: Text('Are you sure you want to delete "$recipeTitle"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await _deleteRecipe(recipeId, recipeTitle);
    }
  }

  Future<void> _deleteRecipe(String recipeId, String recipeTitle) async {
    try {
      await _recipeService.deleteRecipeLocally(recipeId);
      setState(() {
        _expandedStates.remove(recipeId);
      });
      _loadSavedRecipes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe "$recipeTitle" deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting the recipe: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildIngredientsList(BuildContext context, List<String> ingredients) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ingredients[index], style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectionsList(BuildContext context, List<String> directions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: directions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(directions[index], style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _parseIngredientAmountAndUnit(String ingredientString) {
    final RegExp regex = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|stk\.?|el|tl|pckg\.?|prise)?\s*(.*)$', caseSensitive: false);
    final match = regex.firstMatch(ingredientString.trim());

    double quantity = 1.0;
    String unit = 'piece';
    String name = ingredientString.trim();

    if (match != null) {
      final String? quantityStr = match.group(1);
      final String? unitStr = match.group(2);
      final String? nameRemainder = match.group(3);

      if (quantityStr != null) {
        quantity = double.tryParse(quantityStr.replaceAll(',', '.')) ?? 1.0;
      }
      if (unitStr != null) {
        unit = unitStr.toLowerCase().replaceAll('.', '');
      }
      if (nameRemainder != null && nameRemainder.isNotEmpty) {
        name = nameRemainder.trim();
      } else if (quantityStr != null && unitStr != null && nameRemainder == null) {
        name = ingredientString.replaceFirst(RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|stk\.?|el|tl|pckg\.?|prise)?\s*', caseSensitive: false), '').trim();
        if (name.isEmpty && !ingredientString.contains(RegExp(r'\d'))){
          name = ingredientString.trim();
        }
      }
    } else {
      quantity = 1.0;
      unit = 'piece';
      name = ingredientString.trim();
    }

    switch (unit) {
      case 'kg':
        quantity *= 1000;
        unit = 'g';
        break;
      case 'l':
        quantity *= 1000;
        unit = 'ml';
        break;
      case 'stk':
      case 'el':
      case 'tl':
      case 'pckg':
      case 'prise':
        break;
      default:
        log('Unknown unit parsed: $unit for $ingredientString. Defaulting to "piece".');
        unit = 'piece';
        break;
    }

    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  String? _findIngredientCategory(String ingredientName) {
    if (_vegetablesMap.containsKey(ingredientName)) return 'Vegetables';
    if (_mainIngredientsMap.containsKey(ingredientName)) return 'Main Ingredients';
    if (_spicesMap.containsKey(ingredientName)) return 'Spices';
    if (_othersMap.containsKey(ingredientName)) return 'Others';
    return null;
  }

  double _getIngredientTotalQuantity(String ingredientName, String category) {
    List<InventoryIngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _vegetablesMap[ingredientName];
        break;
      case 'Main Ingredients':
        entries = _mainIngredientsMap[ingredientName];
        break;
      case 'Spices':
        entries = _spicesMap[ingredientName];
        break;
      case 'Others':
        entries = _othersMap[ingredientName];
        break;
    }
    return entries?.fold(0.0, (sum, entry) => sum! + entry.quantity) ?? 0.0;
  }

  String _getIngredientUnit(String ingredientName, String category) {
    List<InventoryIngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _vegetablesMap[ingredientName];
        break;
      case 'Main Ingredients':
        entries = _mainIngredientsMap[ingredientName];
        break;
      case 'Spices':
        entries = _spicesMap[ingredientName];
        break;
      case 'Others':
        entries = _othersMap[ingredientName];
        break;
    }
    return entries?.isNotEmpty == true ? entries!.first.unit : 'piece';
  }

  Future<void> _onDeductIngredients(Recipe recipe) async {
    if (recipe.usedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No used ingredients found to deduct.')),
      );
      log('Deduct Ingredients button pressed, but no used ingredients in current recipe.');
      return;
    }

    List<Map<String, dynamic>> parsedUsedIngredients =
    recipe.usedIngredients.map((s) => _parseIngredientAmountAndUnit(s)).toList();

    Map<String, double> deductionAmounts = {};
    Map<String, TextEditingController> _controllers = {};
    Map<String, FocusNode> _focusNodes = {};

    await _loadInventory();

    for (var parsedIngredient in parsedUsedIngredients) {
      String ingredientName = parsedIngredient['name'];
      double suggestedQuantity = parsedIngredient['quantity'];

      String? category = _findIngredientCategory(ingredientName);
      if (category != null) {
        double available = _getIngredientTotalQuantity(ingredientName, category);
        double initialDeduction = suggestedQuantity > available && available > 0 ? available : suggestedQuantity;
        if (initialDeduction < 0) initialDeduction = 0.0;

        deductionAmounts[ingredientName] = initialDeduction;

        final controller = TextEditingController(text: initialDeduction.toStringAsFixed(1));
        final focusNode = FocusNode();

        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
        });

        _controllers[ingredientName] = controller;
        _focusNodes[ingredientName] = focusNode;
      }
    }

    void disposeControllersAndFocusNodes() {
      _controllers.forEach((key, controller) => controller.dispose());
      _focusNodes.forEach((key, focusNode) => focusNode.dispose());
    }

    Map<String, double>? result = await showDialog<Map<String, double>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Deduct ingredients from inventory'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Adjust the quantities to be deducted from your inventory:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ...parsedUsedIngredients.map((parsedIngredient) {
                        String ingredientName = parsedIngredient['name'];
                        double suggestedQuantity = parsedIngredient['quantity'];
                        String suggestedUnit = parsedIngredient['unit'];

                        String? category = _findIngredientCategory(ingredientName);
                        double available = category != null ? _getIngredientTotalQuantity(ingredientName, category) : 0.0;
                        String inventoryUnit = category != null ? _getIngredientUnit(ingredientName, category) : 'piece';

                        if (category == null || available <= 0) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ingredientName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Not in inventory (Suggestion: ${suggestedQuantity.toStringAsFixed(1)} $suggestedUnit)',
                                    style: const TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        double currentDeduction = deductionAmounts[ingredientName] ?? 0.0;
                        TextEditingController? controller = _controllers[ingredientName];
                        FocusNode? focusNode = _focusNodes[ingredientName];

                        if (controller != null && focusNode != null && !focusNode.hasFocus) {
                          double? controllerValue = double.tryParse(controller.text.replaceAll(',', '.'));
                          if (controllerValue != currentDeduction) {
                            controller.text = currentDeduction.toStringAsFixed(1);
                            controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length));
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ingredientName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Available: ${available.toStringAsFixed(1)} $inventoryUnit',
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Deduct ($inventoryUnit)',
                                    hintText: 'Enter quantity',
                                    border: const OutlineInputBorder(),
                                    suffixText: inventoryUnit,
                                  ),
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value.isEmpty) {
                                        deductionAmounts[ingredientName] = 0.0;
                                      } else if (value == '.' || value == ',') {
                                        // Handle partial decimal input
                                      } else {
                                        double? parsedValue = double.tryParse(value.replaceAll(',', '.'));
                                        if (parsedValue != null && parsedValue >= 0) {
                                          deductionAmounts[ingredientName] = parsedValue > available ? available : parsedValue;
                                        } else {
                                          deductionAmounts[ingredientName] = 0.0;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(deductionAmounts),
                  child: const Text('Deduct'),
                ),
              ],
            );
          },
        );
      },
    );

    disposeControllersAndFocusNodes();

    if (result != null) {
      await _deductIngredientsFromInventory(result);
    }
  }

  Future<void> _deductIngredientsFromInventory(Map<String, double> deductions) async {
    bool inventoryChanged = false;

    Future<void> _saveInventory() async {
      final prefs = await SharedPreferences.getInstance();
      Map<String, String> inventoryMaps = {
        'Vegetables': jsonEncode(_vegetablesMap.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()))),
        'Main Ingredients': jsonEncode(_mainIngredientsMap.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()))),
        'Spices': jsonEncode(_spicesMap.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()))),
        'Others': jsonEncode(_othersMap.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()))),
      };
      await Future.wait(inventoryMaps.entries.map((entry) => prefs.setString(entry.key, entry.value)));
      log('SavedRecipesPage: Inventory saved after deduction.');
    }

    for (String ingredientName in deductions.keys) {
      double amountToDeduct = deductions[ingredientName] ?? 0.0;
      if (amountToDeduct <= 0) continue;

      String? category = _findIngredientCategory(ingredientName);
      if (category == null) {
        log('SavedRecipesPage: Could not find category for ingredient $ingredientName during deduction.');
        continue;
      }

      Map<String, List<InventoryIngredientEntry>> targetMap;
      switch (category) {
        case 'Vegetables':
          targetMap = _vegetablesMap;
          break;
        case 'Main Ingredients':
          targetMap = _mainIngredientsMap;
          break;
        case 'Spices':
          targetMap = _spicesMap;
          break;
        case 'Others':
          targetMap = _othersMap;
          break;
        default:
          continue;
      }

      if (targetMap.containsKey(ingredientName)) {
        double remainingToDeduct = amountToDeduct;
        targetMap[ingredientName]?.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));

        List<InventoryIngredientEntry> entriesToRemove = [];
        for (var entry in targetMap[ingredientName]!) {
          if (remainingToDeduct <= 0) break;

          if (entry.quantity > remainingToDeduct) {
            entry.quantity -= remainingToDeduct;
            remainingToDeduct = 0;
          } else {
            remainingToDeduct -= entry.quantity;
            entriesToRemove.add(entry);
          }
        }

        targetMap[ingredientName]?.removeWhere((entry) => entriesToRemove.contains(entry));

        if (targetMap[ingredientName]?.isEmpty ?? true) {
          targetMap.remove(ingredientName);
        }

        inventoryChanged = true;
      }
    }

    if (inventoryChanged) {
      await _saveInventory();
      await _loadInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingredients successfully deducted from inventory!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No quantities selected for deduction or invalid input.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh recipes',
            onPressed: () {
              _loadInventory();
              _loadSavedRecipes();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _savedRecipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading recipes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No recipes saved yet.'));
          }

          final recipes = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final bool isExpanded = _expandedStates[recipe.id] ?? false;
              final List<String> missingIngredients = _getMissingIngredientsForRecipe(recipe);
              final bool canBeCooked = missingIngredients.isEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedStates[recipe.id] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                recipe.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit recipe',
                                  onPressed: () => _editRecipe(recipe),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete recipe',
                                  onPressed: () => _showDeleteConfirmationDialog(recipe.id, recipe.title),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (!canBeCooked)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Missing ingredients: ${missingIngredients.join(', ')}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Saved on: ${DateFormat('dd.MM.yyyy HH:mm').format(recipe.savedAt.toLocal())}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Visibility(
                          visible: isExpanded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),

                              const Text(
                                "Ingredients",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildIngredientsList(context, recipe.ingredients),
                              const SizedBox(height: 24),

                              const Text(
                                "Directions",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              _buildDirectionsList(context, recipe.directions),
                              const SizedBox(height: 24),

                              if (recipe.usedIngredients.isNotEmpty) ...[
                                Text(
                                  "Used ingredients: ${recipe.usedIngredients.join(', ')}",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: canBeCooked
                                        ? () => _onDeductIngredients(recipe)
                                        : null,
                                    icon: const Icon(Icons.remove_shopping_cart),
                                    label: const Text(
                                      'Deduct used ingredients from inventory',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: canBeCooked ? Colors.orange : Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}