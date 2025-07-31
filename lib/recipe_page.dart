import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/recipe_service.dart';
import 'widgets/ingredient_selector.dart';
import 'widgets/recipe_display.dart';
import 'data/recipe.dart';
import 'dart:developer';
import 'package:intl/intl.dart';
import 'data/IngriedientEntry.dart';
import 'services/inventory_service.dart';

class RecipePage extends StatefulWidget {
  // NEU: Hinzufügen eines Callbacks für den Zurück-Button
  final VoidCallback? onBackToSelector;

  const RecipePage({super.key, this.onBackToSelector}); // Aktualisierter Konstruktor

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> with WidgetsBindingObserver {
  // ... (bestehender Code) ...

  // Services
  final RecipeService _recipeService = RecipeService();
  final InventoryService _inventoryService = InventoryService();

  // Recipe Data & Loading State
  Map<String, dynamic> _recipeData = {};
  bool _isLoading = false;
  bool _isCurrentRecipeSaved = false;

  // Inventory Maps
  Map<String, List<IngredientEntry>> _vegetablesMap = {};
  Map<String, List<IngredientEntry>> _mainIngredientsMap = {};
  Map<String, List<IngredientEntry>> _spicesMap = {};
  Map<String, List<IngredientEntry>> _othersMap = {};

  // Ingredient Selection State
  Set<String> _requiredIngredients = {};
  bool _showRecipes = false;
  bool _hasIngredients = false;
  bool _autoExpandIngredients = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    log('RecipePage: initState completed.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    log('RecipePage: dispose called.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log('RecipePage: App resumed, reloading inventory.');
      _loadInventory();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log('RecipePage: didChangeDependencies called, reloading inventory.');
    _loadInventory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoExpandIngredients = prefs.getBool('auto_expand_ingredients') ?? true;
    });
    log('RecipePage: Settings loaded. AutoExpand: $_autoExpandIngredients');
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_expand_ingredients', _autoExpandIngredients);
    log('RecipePage: Settings saved. AutoExpand: $_autoExpandIngredients');
  }

  Future<void> _loadInventory() async {
    log('RecipePage: _loadInventory started (using InventoryService).');

    await _inventoryService.loadInventory();

    if (!mounted) {
      log('RecipePage: _loadInventory - Widget not mounted, returning.');
      return;
    }

    setState(() {
      _vegetablesMap = _inventoryService.ingredientCountVegetables;
      _mainIngredientsMap = _inventoryService.ingredientCountMain;
      _spicesMap = _inventoryService.ingredientCountSpices;
      _othersMap = _inventoryService.ingredientCountOthers;

      _hasIngredients = _vegetablesMap.values.any((list) => list.isNotEmpty) ||
          _mainIngredientsMap.values.any((list) => list.isNotEmpty) ||
          _spicesMap.values.any((list) => list.isNotEmpty) ||
          _othersMap.values.any((list) => list.isNotEmpty);

      _cleanupRequiredIngredients();
      log(
          'RecipePage: _loadInventory setState completed. _hasIngredients: $_hasIngredients');
    });
  }

  void _cleanupRequiredIngredients() {
    Set<String> allAvailable = {
      ..._vegetablesMap.keys,
      ..._mainIngredientsMap.keys,
      ..._spicesMap.keys,
      ..._othersMap.keys
    };
    _requiredIngredients.removeWhere((ingredient) =>
    !allAvailable.contains(ingredient));
    log(
        'RecipePage: _cleanupRequiredIngredients called. Required ingredients after cleanup: $_requiredIngredients');
  }

  Future<void> _generateRecipe() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _recipeData = {};
      _showRecipes = true;
      _isCurrentRecipeSaved = false;
    });
    log('RecipePage: Generating recipe...');

    List<String> required = _requiredIngredients.toList();
    Map<String, List<IngredientEntry>> fullInventory = {
      ..._vegetablesMap,
      ..._mainIngredientsMap,
      ..._spicesMap,
      ..._othersMap,
    };

    try {
      log(
          'Sending request to RecipeService. Required: $required, Full Inventory for expansion: $fullInventory');

      final recipe = await _recipeService.generateRecipe(
        requiredIngredients: required,
        fullAvailableIngredients: fullInventory,
        autoExpandIngredients: _autoExpandIngredients,
      );

      if (!mounted) return;

      final String recipeId = recipe['id'] ?? DateTime
          .now()
          .microsecondsSinceEpoch
          .toString();
      final bool saved = await _recipeService.isRecipeSaved(recipeId);
      log(
          'RecipePage: Is newly generated recipe saved? $saved (ID: $recipeId)');

      setState(() {
        _recipeData = recipe;
        _recipeData['id'] = recipeId;
        _isCurrentRecipeSaved = saved;
        log(
            'RecipePage: Recipe generated and data set. Title: ${_recipeData['title']}, IsSaved: $_isCurrentRecipeSaved');
      });
    } catch (e) {
      log('RecipePage: Error generating recipe via RecipeService: $e',
          error: e);
      setState(() {
        _recipeData = {
          'title': 'Error during generation',
          'ingredients': ['There was a problem generating the recipe.'],
          'directions': [
            'Please check your internet connection or try later',
            'Details: ${e.toString()}'
          ],
          'used_ingredients': [],
          'id': DateTime
              .now()
              .microsecondsSinceEpoch
              .toString(),
        };
        _isCurrentRecipeSaved = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          log('RecipePage: Loading finished.');
        });
      }
    }
  }

  Future<void> _toggleSaveRecipe() async {
    if (_recipeData.isEmpty || _recipeData['title'] == null ||
        _recipeData['ingredients'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No valid recipe found to save/delete.'),
          backgroundColor: Colors.red,
        ),
      );
      log('RecipePage: Attempted to save/delete invalid recipe.');
      return;
    }

    final String recipeId = _recipeData['id'] ?? '';
    if (recipeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe does not have a valid ID for saving/deleting.'),
          backgroundColor: Colors.red,
        ),
      );
      log('RecipePage: Recipe has no valid ID for saving/deleting.');
      return;
    }

    if (_isCurrentRecipeSaved) {
      try {
        await _recipeService.deleteRecipeLocally(recipeId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Recipe "${_recipeData['title']}" deleted successfully!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isCurrentRecipeSaved = false;
          });
          log(
              'RecipePage: Recipe "${_recipeData['title']}" deleted successfully!');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to delete the recipe: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          log('RecipePage: Error deleting recipe: $e', error: e);
        }
      }
    } else {
      final newRecipe = Recipe(
        id: recipeId,
        title: _recipeData['title'],
        ingredients: List<String>.from(_recipeData['ingredients']),
        directions: List<String>.from(_recipeData['directions']),
        usedIngredients: List<String>.from(_recipeData['used_ingredients']),
        savedAt: DateTime.now(),
      );

      try {
        await _recipeService.saveRecipeLocally(newRecipe);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Recipe "${newRecipe.title}" successfully saved!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isCurrentRecipeSaved = true;
          });
          log('RecipePage: Recipe "${newRecipe.title}" saved successfully.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to save the recipe locally ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          log('RecipePage: Error saving recipe: $e', error: e);
        }
      }
    }
  }

  void _toggleView() {
    setState(() {
      _showRecipes = !_showRecipes;
      if (!_showRecipes) {
        _recipeData = {};
        _isCurrentRecipeSaved = false;
      }
      log('RecipePage: Toggled view. Show recipes: $_showRecipes');
    });
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_requiredIngredients.contains(ingredient)) {
        _requiredIngredients.remove(ingredient);
      } else {
        _requiredIngredients.add(ingredient);
      }
      log(
          'RecipePage: Toggled ingredient: $ingredient. Required: $_requiredIngredients');
    });
  }

  void _toggleAutoExpand() {
    setState(() {
      _autoExpandIngredients = !_autoExpandIngredients;
    });
    _saveSettings();
    log('RecipePage: Toggled auto expand to: $_autoExpandIngredients');
  }

  Future<void> _showIngredientDeductionDialog() async {
    if (_recipeData['used_ingredients'] == null) return;

    List<String> usedIngredients = List<String>.from(
        _recipeData['used_ingredients']);
    Map<String, double> deductionAmounts = {};
    Map<String, String> ingredientCategories = {};
    Map<String, String> ingredientUnits = {};

    Map<String, TextEditingController> _controllers = {};
    Map<String, FocusNode> _focusNodes = {};

    for (String ingredient in usedIngredients) {
      String? category = _findIngredientCategory(ingredient);
      if (category != null) {
        ingredientCategories[ingredient] = category;
        double availableQuantity = _getIngredientTotalQuantity(
            ingredient, category);
        String unit = _getIngredientUnit(ingredient, category);
        ingredientUnits[ingredient] = unit;

        deductionAmounts[ingredient] = 0.0;

        final controller = TextEditingController(text: '0.0');
        final focusNode = FocusNode();

        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
        });

        _controllers[ingredient] = controller;
        _focusNodes[ingredient] = focusNode;
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
                      ...usedIngredients.map((ingredient) {
                        String? category = ingredientCategories[ingredient];
                        double available = category != null
                            ? _getIngredientTotalQuantity(ingredient, category)
                            : 0.0;
                        String unit = ingredientUnits[ingredient] ?? 'Stück';
                        double currentDeduction = deductionAmounts[ingredient] ??
                            0.0;

                        TextEditingController? controller = _controllers[ingredient];
                        FocusNode? focusNode = _focusNodes[ingredient];

                        if (controller != null && focusNode != null &&
                            !focusNode.hasFocus) {
                          double? controllerValue = double.tryParse(
                              controller.text.replaceAll(',', '.'));
                          if (controllerValue != currentDeduction) {
                            controller.text =
                                currentDeduction.toStringAsFixed(1);
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
                                  ingredient,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  available > 0
                                      ? 'Available: ${available.toStringAsFixed(
                                      1)} $unit'
                                      : 'Not in inventory',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: available > 0 ? Colors.green : Colors
                                        .red,
                                  ),
                                ),
                                if (available > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      const SizedBox(height: 8),
                                      TextField(
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Deduct ($unit)',
                                          hintText: 'Enter quantity',
                                          border: const OutlineInputBorder(),
                                          suffixText: unit,
                                        ),
                                        controller: controller,
                                        focusNode: focusNode,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (value.isEmpty) {
                                              deductionAmounts[ingredient] =
                                              0.0;
                                            } else
                                            if (value == '.' || value == ',') {}
                                            else {
                                              double? parsedValue = double
                                                  .tryParse(
                                                  value.replaceAll(',', '.'));
                                              if (parsedValue != null &&
                                                  parsedValue >= 0) {
                                                deductionAmounts[ingredient] =
                                                parsedValue > available
                                                    ? available
                                                    : parsedValue;
                                              } else {
                                                deductionAmounts[ingredient] =
                                                0.0;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ],
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

  String? _findIngredientCategory(String ingredient) {
    if (_vegetablesMap.containsKey(ingredient)) return 'Vegetables';
    if (_mainIngredientsMap.containsKey(ingredient)) return 'Main Ingredients';
    if (_spicesMap.containsKey(ingredient)) return 'Spices';
    if (_othersMap.containsKey(ingredient)) return 'Others';
    return null;
  }

  double _getIngredientTotalQuantity(String ingredient, String category) {
    List<IngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _vegetablesMap[ingredient];
        break;
      case 'Main Ingredients':
        entries = _mainIngredientsMap[ingredient];
        break;
      case 'Spices':
        entries = _spicesMap[ingredient];
        break;
      case 'Others':
        entries = _othersMap[ingredient];
        break;
    }
    return entries?.fold(0.0, (sum, entry) => sum! + entry.quantity) ?? 0.0;
  }

  String _getIngredientUnit(String ingredient, String category) {
    List<IngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _vegetablesMap[ingredient];
        break;
      case 'Main Ingredients':
        entries = _mainIngredientsMap[ingredient];
        break;
      case 'Spices':
        entries = _spicesMap[ingredient];
        break;
      case 'Others':
        entries = _othersMap[ingredient];
        break;
    }
    return entries?.first.unit ?? 'Stück';
  }

  Future<void> _deductIngredientsFromInventory(
      Map<String, double> deductions) async {
    bool inventoryChanged = false;

    for (String ingredientName in deductions.keys) {
      double amountToDeduct = deductions[ingredientName] ?? 0.0;
      if (amountToDeduct <= 0) continue;

      String? category = _findIngredientCategory(ingredientName);
      if (category == null) {
        log(
            'RecipePage: Could not find category for ingredient $ingredientName during deduction.');
        continue;
      }

      await _inventoryService.deductIngredientQuantity(
          ingredientName, category, amountToDeduct);
      inventoryChanged = true;
    }

    if (inventoryChanged) {
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
            content: Text(
                'No quantities selected for deduction or invalid input.'),
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
        title: Text(_showRecipes ? 'Suggestion' : 'Select ingredients'), // <-- Diese Zeile wurde geändert
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        foregroundColor: Theme
            .of(context)
            .colorScheme
            .onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // HIER IST DIE WICHTIGE ÄNDERUNG:
        leading: _showRecipes // Nur anzeigen, wenn _showRecipes true ist
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          // Oder Icons.close, wenn du das Kreuz willst
          tooltip: 'Select ingredient',
          // Dieser Tooltip gilt nur, wenn das Rezept angezeigt wird
          onPressed: () {
            _toggleView(); // Wenn ein Rezept angezeigt wird, gehe zurück zur Zutatenauswahl
          },
        )
            : null,
        // Wenn _showRecipes false ist, kein Icon anzeigen
        actions: [
          // ... (deine vorhandenen Actions bleiben gleich) ...
          if (_showRecipes)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Generate new recipe',
              onPressed: _generateRecipe,
            ),
          if (_showRecipes && _recipeData.isNotEmpty &&
              _recipeData['title'] != null && !_isLoading)
            IconButton(
              icon: Icon(
                _isCurrentRecipeSaved ? Icons.favorite : Icons.favorite_border,
                color: _isCurrentRecipeSaved ? Colors.red : null,
              ),
              tooltip: _isCurrentRecipeSaved
                  ? 'Rezept entfernen'
                  : 'Rezept speichern',
              onPressed: _toggleSaveRecipe,
            ),
        ],
      ),
      body: _showRecipes
          ? RecipeDisplay(
        recipeData: _recipeData,
        isLoading: _isLoading,
        onDeductIngredients: _showIngredientDeductionDialog,
        hasIngredients: _hasIngredients,
      )
          : IngredientSelector(
        // ... (deine IngredientSelector-Eigenschaften bleiben gleich) ...
        vegetablesMap: _vegetablesMap.map((key, entries) {
          double totalQuantity = _getIngredientTotalQuantity(key, 'Vegetables');
          String unit = _getIngredientUnit(key, 'Vegetables');
          return MapEntry(key, entries.isNotEmpty
              ? '${totalQuantity.toStringAsFixed(1)} $unit'
              : null);
        }),
        mainIngredientsMap: _mainIngredientsMap.map((key, entries) {
          double totalQuantity = _getIngredientTotalQuantity(
              key, 'Main Ingredients');
          String unit = _getIngredientUnit(key, 'Main Ingredients');
          return MapEntry(key, entries.isNotEmpty
              ? '${totalQuantity.toStringAsFixed(1)} $unit'
              : null);
        }),
        spicesMap: _spicesMap.map((key, entries) {
          double totalQuantity = _getIngredientTotalQuantity(key, 'Spices');
          String unit = _getIngredientUnit(key, 'Spices');
          return MapEntry(key, entries.isNotEmpty
              ? '${totalQuantity.toStringAsFixed(1)} $unit'
              : null);
        }),
        othersMap: _othersMap.map((key, entries) {
          double totalQuantity = _getIngredientTotalQuantity(key, 'Others');
          String unit = _getIngredientUnit(key, 'Others');
          return MapEntry(key, entries.isNotEmpty
              ? '${totalQuantity.toStringAsFixed(1)} $unit'
              : null);
        }),
        requiredIngredients: _requiredIngredients,
        autoExpandIngredients: _autoExpandIngredients,
        onToggleIngredient: _toggleIngredient,
        onGenerateRecipe: _generateRecipe,
        onToggleAutoExpand: _toggleAutoExpand,
        onResetRequiredIngredients: () {
          setState(() => _requiredIngredients.clear());
        },
      ),
    );
  }
}