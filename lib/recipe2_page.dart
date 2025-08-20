import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:developer';
import 'data/token.dart';
import 'package:recipe/data/IngriedientEntry.dart';
import 'widgets/ingredient_selector2.dart';
import 'widgets/recipe_display2.dart';
import 'data/recipe.dart';
import 'services/saved_recipe_service.dart';
import 'services/inventory_service.dart';


class Recipe2Page extends StatefulWidget {
  const Recipe2Page({super.key});

  @override
  State<Recipe2Page> createState() => _Recipe2PageState();
}

class _Recipe2PageState extends State<Recipe2Page> {

  final SavedRecipeService _savedRecipeService = SavedRecipeService();
  final InventoryService _inventoryService = InventoryService();

  String? _selectedModel;
  bool _isLoading = false;
  String _apiResponse = '';
  bool _isShowingRecipeResult = false;

  Recipe? _currentRecipe;
  bool _isCurrentRecipeSaved = false;


  Map<String, String?> _vegetablesMap = {};
  Map<String, String?> _mainIngredientsMap = {};
  Map<String, String?> _spicesMap = {};
  Map<String, String?> _othersMap = {};

  Set<String> _requiredIngredients = {};
  bool _autoExpandIngredients = true;


  final String _chatCompletionsApiEndpoint = 'https://router.huggingface.co/featherless-ai/v1/chat/completions';
  String _currentApiEndpointModel = "Qwen/Qwen2.5-72B-Instruct";

  String _selectedCuisineStyle = "any";
  Set<String> _selectedDietaryRestrictions = {'none'};


  @override
  void initState() {
    super.initState();
    _selectedModel = 'Qwen/Qwen2.5-72B-Instruct';
    _currentApiEndpointModel = "Qwen/Qwen2.5-72B-Instruct";
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadSettings();
    await _loadInventory();
  }
  String? _findIngredientCategory(String ingredientName) {
    if (_inventoryService.ingredientCountVegetables.containsKey(ingredientName)) return 'Vegetables';
    if (_inventoryService.ingredientCountMain.containsKey(ingredientName)) return 'Main Ingredients';
    if (_inventoryService.ingredientCountSpices.containsKey(ingredientName)) return 'Spices';
    if (_inventoryService.ingredientCountOthers.containsKey(ingredientName)) return 'Others';
    return null;
  }

  double _getIngredientTotalQuantity(String ingredientName, String category) {
    List<IngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _inventoryService.ingredientCountVegetables[ingredientName];
        break;
      case 'Main Ingredients':
        entries = _inventoryService.ingredientCountMain[ingredientName];
        break;
      case 'Spices':
        entries = _inventoryService.ingredientCountSpices[ingredientName];
        break;
      case 'Others':
        entries = _inventoryService.ingredientCountOthers[ingredientName];
        break;
    }
    return entries?.fold(0.0, (sum, entry) => sum! + entry.quantity) ?? 0.0;
  }

  String _getIngredientUnit(String ingredientName, String category) {
    List<IngredientEntry>? entries;
    switch (category) {
      case 'Vegetables':
        entries = _inventoryService.ingredientCountVegetables[ingredientName];
        break;
      case 'Main Ingredients':
        entries = _inventoryService.ingredientCountMain[ingredientName];
        break;
      case 'Spices':
        entries = _inventoryService.ingredientCountSpices[ingredientName];
        break;
      case 'Others':
        entries = _inventoryService.ingredientCountOthers[ingredientName];
        break;
    }
    return entries?.isNotEmpty == true ? entries!.first.unit : 'Piece';
  }
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoExpandIngredients = prefs.getBool('auto_expand_ingredients') ?? true;
    });
    log('Recipe2Page: Settings loaded. AutoExpand: $_autoExpandIngredients');
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_expand_ingredients', _autoExpandIngredients);
    log('Recipe2Page: Settings saved. AutoExpand: $_autoExpandIngredients');
  }

  Future<void> _loadInventory() async {
    log('Recipe2Page: _loadInventory started (using InventoryService).');

    await _inventoryService.loadInventory(); // Lade Daten über den InventoryService

    if (!mounted) {
      log('Recipe2Page: _loadInventory - Widget not mounted, returning.');
      return;
    }

    setState(() {
      _vegetablesMap = _convertIngredientEntryMapToDisplayMap(_inventoryService.ingredientCountVegetables);
      _mainIngredientsMap = _convertIngredientEntryMapToDisplayMap(_inventoryService.ingredientCountMain);
      _spicesMap = _convertIngredientEntryMapToDisplayMap(_inventoryService.ingredientCountSpices);
      _othersMap = _convertIngredientEntryMapToDisplayMap(_inventoryService.ingredientCountOthers);


      _cleanupRequiredIngredients();
      log('Recipe2Page: _loadInventory setState completed. _hasIngredients: $_hasIngredients');
    });
  }

  Map<String, String?> _convertIngredientEntryMapToDisplayMap(Map<String, List<IngredientEntry>> sourceMap) {
    return sourceMap.map((key, value) {
      if (value.isEmpty) return MapEntry(key, null);
      value.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
      return MapEntry(key, DateFormat('MM/dd/yyyy').format(value.first.dateAdded));
    });
  }

  void _cleanupRequiredIngredients() {
    Set<String> allAvailable = {
      ..._vegetablesMap.keys,
      ..._mainIngredientsMap.keys,
      ..._spicesMap.keys,
      ..._othersMap.keys
    };
    _requiredIngredients.removeWhere((ingredient) => !allAvailable.contains(ingredient));
    log('Recipe2Page: _cleanupRequiredIngredients called. Required ingredients after cleanup: $_requiredIngredients');
  }

  bool get _hasIngredients {
    return _vegetablesMap.isNotEmpty ||
        _mainIngredientsMap.isNotEmpty ||
        _spicesMap.isNotEmpty ||
        _othersMap.isNotEmpty;
  }

  void _onToggleIngredient(String ingredient) {
    setState(() {
      if (_requiredIngredients.contains(ingredient)) {
        _requiredIngredients.remove(ingredient);
      } else {
        _requiredIngredients.add(ingredient);
      }
    });
    log('Ingredient toggled: $ingredient. Currently selected: $_requiredIngredients');
  }

  void _onGenerateRecipe() async {
    setState(() {
      _isShowingRecipeResult = true;
      _apiResponse = '';
      _currentRecipe = null;
      _isCurrentRecipeSaved = false;
    });
    await _callHuggingFaceApi();
  }


  Map<String, dynamic> _parseIngredientAmountAndUnit(String ingredientString) {
    final RegExp regex = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|stk\.?|el|tl|pckg\.?|prise)?\s*(.*)$', caseSensitive: false);
    final match = regex.firstMatch(ingredientString.trim());

    double quantity = 1.0; // Standardmenge
    String unit = 'Stück'; // Standardeinheit
    String name = ingredientString.trim(); // Standardname (ganzer String)

    if (match != null) {
      final String? quantityStr = match.group(1);
      final String? unitStr = match.group(2);
      final String? nameRemainder = match.group(3);

      if (quantityStr != null) {
        quantity = double.tryParse(quantityStr.replaceAll(',', '.')) ?? 1.0;
      }
      if (unitStr != null) {
        unit = unitStr.toLowerCase().replaceAll('.', ''); // Punkt bei "Stk." etc. entfernen
      }
      if (nameRemainder != null && nameRemainder.isNotEmpty) {
        name = nameRemainder.trim();
      } else if (quantityStr != null && unitStr != null && nameRemainder == null) {
        name = ingredientString.trim();

        name = ingredientString.replaceFirst(RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|stk\.?|el|tl|pckg\.?|prise)?\s*', caseSensitive: false), '').trim();
        if (name.isEmpty && !ingredientString.contains(RegExp(r'\d'))){ // Z.B. "1 Ei" -> name wäre "Ei". Aber wenn "Ei" ohne 1 ist, und regex matcht nicht, ist name "Ei"
          name = ingredientString.trim();
        }
      }
    } else {
      quantity = 1.0;
      unit = 'Stück';
      name = ingredientString.trim();
    }

    // Einheiten normalisieren
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
        log('Unknown unit parsed: $unit for $ingredientString. Defaulting to "Stück".');
        unit = 'Stück';
        break;
    }

    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  Future<void> _onDeductIngredients() async {
    if (_currentRecipe == null || _currentRecipe!.usedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No used ingredients found to deduct.')),
      );
      log('Deduct Ingredients button pressed, but no used ingredients in current recipe.');
      return;
    }

    List<Map<String, dynamic>> parsedUsedIngredients =
    _currentRecipe!.usedIngredients.map((s) => _parseIngredientAmountAndUnit(s)).toList();

    Map<String, double> deductionAmounts = {};

    Map<String, TextEditingController> _controllers = {};
    Map<String, FocusNode> _focusNodes = {};

    await _inventoryService.loadInventory();

    for (var parsedIngredient in parsedUsedIngredients) {
      String ingredientName = parsedIngredient['name'];
      double suggestedQuantity = parsedIngredient['quantity'];

      String? category = _findIngredientCategory(ingredientName);
      if (category != null) {
        double available = _getIngredientTotalQuantity(ingredientName, category);
        double initialDeduction = suggestedQuantity > available && available > 0 ? available : suggestedQuantity;
        if (initialDeduction < 0) initialDeduction = 0.0; // Negative Werte vermeiden

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
                        String suggestedUnit = parsedIngredient['unit']; // Einheit aus dem Rezept

                        String? category = _findIngredientCategory(ingredientName);
                        double available = category != null ? _getIngredientTotalQuantity(ingredientName, category) : 0.0;
                        String inventoryUnit = category != null ? _getIngredientUnit(ingredientName, category) : 'Stück'; // Einheit aus dem Inventar

                        // Prüfe, ob die Zutat überhaupt im Inventar ist, bevor du einen Controller anbietest
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

                        // Aktualisiere den Text des Controllers nur, wenn er nicht fokussiert ist
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
                                    labelText: 'Deduct ($inventoryUnit)', // Einheit vom Inventar
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
                                          // Maximal die verfügbare Menge abziehen
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

    for (String ingredientName in deductions.keys) {
      double amountToDeduct = deductions[ingredientName] ?? 0.0;
      if (amountToDeduct <= 0) continue;

      String? category = _findIngredientCategory(ingredientName);
      if (category == null) {
        log('Recipe2Page: Could not find category for ingredient $ingredientName during deduction.');
        continue;
      }

      await _inventoryService.deductIngredientQuantity(ingredientName, category, amountToDeduct);
      inventoryChanged = true;
    }

    if (inventoryChanged) {
      // Lade das Inventar neu, um die UI zu aktualisieren, nachdem Abzüge gemacht wurden
      await _loadInventory(); // Ruft deine Methode zum Neuladen auf

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



  Recipe _parseApiResponseToRecipe(String response) {

    response = response.split(RegExp(r'<[^>]*>'))[0].trim();

    String title = 'Generated Recipe';
    List<String> ingredients = [];
    List<String> directions = [];
    List<String> usedIngredients = []; // The AI will hopefully return these

    if (response.contains('Error') || response.contains('Error') || response.isEmpty) {
      return Recipe(
        id: DateTime.now().microsecondsSinceEpoch.toString(), // Unique ID for error recipes
        title: 'Error Generating Recipe',
        ingredients: [],
        directions: [
          'There was a problem generating the recipe.',
          'Please check your internet connection and or try later',
          'Error details: $response',
        ],
        usedIngredients: [],
        savedAt: DateTime.now(),
      );
    }

    String cleanResponse = response.trim().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> lines = cleanResponse.split('\n');

    String currentSection = '';

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.toLowerCase().startsWith('title:')) {
        title = line.substring(line.indexOf(':') + 1).trim();
        currentSection = 'title';
      } else if (line.toLowerCase().startsWith('ingredients:')) {
        currentSection = 'ingredients';
        String ingredientsOnSameLine = line.substring(line.indexOf(':') + 1).trim();
        if (ingredientsOnSameLine.isNotEmpty) {
          ingredients.addAll(
            ingredientsOnSameLine.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
          );
        }
      } else if (line.toLowerCase().startsWith('instructions:') ||
          line.toLowerCase().startsWith('directions:') ||
          line.toLowerCase().startsWith('directions:')) {
        currentSection = 'directions';
        String instructionsOnSameLine = line.substring(line.indexOf(':') + 1).trim();
        if (instructionsOnSameLine.isNotEmpty) {
          final instructionMatches = RegExp(r'\d+\.\s.*?(?=\d+\.|$)', dotAll: true)
              .allMatches(instructionsOnSameLine);

          if (instructionMatches.isNotEmpty) {
            for (final match in instructionMatches) {
              final step = match.group(0)?.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
              if (step != null && step.isNotEmpty) {
                directions.add(step);
              }
            }
          } else {
            directions.add(instructionsOnSameLine);
          }
        }
      } else if (line.toLowerCase().startsWith('used ingredients:') ||
          line.toLowerCase().startsWith('used ingredients:')) {
        String usedIngredientsStr = line.substring(line.indexOf(':') + 1).trim();
        if (usedIngredientsStr.isNotEmpty) {
          usedIngredients.addAll(
            usedIngredientsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
          );
        }
      } else if (currentSection == 'ingredients') {
        ingredients.addAll(
          line.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      } else if (currentSection == 'directions') {
        if (RegExp(r'^\d+\.').hasMatch(line)) {
          String cleanInstruction = line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          directions.add(cleanInstruction.trim());
        } else {
          directions.add(line);
        }
      }
    }

    ingredients = ingredients.where((ingredient) => ingredient.isNotEmpty).toSet().toList();
    directions = directions.where((direction) => direction.isNotEmpty).toList();

    if (directions.isEmpty) {
      String lowerResponse = response.toLowerCase();
      int instructionIndex = -1;
      List<String> instructionKeywords = ['instructions:', 'instructions:', 'directions:', 'steps:', 'steps'];
      for (String keyword in instructionKeywords) {
        int index = lowerResponse.indexOf(keyword);
        if (index != -1) {
          instructionIndex = index;
          break;
        }
      }

      if (instructionIndex != -1) {
        String instructionsPart = response.substring(instructionIndex);
        List<String> instructionLines = instructionsPart.split('\n');

        for (int i = 1; i < instructionLines.length; i++) {
          String line = instructionLines[i].trim();
          if (line.isNotEmpty) {
            if (RegExp(r'^\d+\.').hasMatch(line)) {
              line = line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
            }
            if (line.isNotEmpty) {
              directions.add(line);
            }
          }
        }
      }
    }

    if (title.isEmpty || ingredients.isEmpty || directions.isEmpty) {
      return Recipe(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Error Processing Recipe',
        ingredients: [],
        directions: [
          'The AI response could not be fully interpreted.',
          'Please try again or select different ingredients.',
          'Raw response: $response'
        ],
        usedIngredients: [],
        savedAt: DateTime.now(),
      );
    }

    // Create a unique ID for the recipe.
    final String recipeId = DateTime.now().microsecondsSinceEpoch.toString();

    return Recipe(
      id: recipeId,
      title: title,
      ingredients: ingredients,
      directions: directions,
      usedIngredients: usedIngredients,
      savedAt: DateTime.now(),
    );
  }

  Future<void> _callHuggingFaceApi() async {
    if (!mounted) return;
    if (_isLoading) return;

    if (_requiredIngredients.isEmpty & ! _autoExpandIngredients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one ingredient.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isShowingRecipeResult = false;
        _currentRecipe = null;
        _isCurrentRecipeSaved = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _apiResponse = '';
      _currentRecipe = null;
      _isCurrentRecipeSaved = false;
    });
    log('Recipe2Page: Generating recipe...');

    List<String> ingredientsToUseInPrompt = [];
    Map<String, String?> allAvailableIngredientsWithDates = {};
    allAvailableIngredientsWithDates.addAll(_vegetablesMap);
    allAvailableIngredientsWithDates.addAll(_mainIngredientsMap);
    allAvailableIngredientsWithDates.addAll(_spicesMap);
    allAvailableIngredientsWithDates.addAll(_othersMap);

    Set<String> finalIngredientsForPromptSelection = <String>{};

    if (_autoExpandIngredients) {
      finalIngredientsForPromptSelection.addAll(allAvailableIngredientsWithDates.keys);
    } else {
      finalIngredientsForPromptSelection.addAll(_requiredIngredients);
    }

    for (String ingredientName in finalIngredientsForPromptSelection) {
      final String? dateStr = allAvailableIngredientsWithDates[ingredientName];
      if (dateStr != null) {
        try {
          final DateTime parsedDate = DateFormat('MM/dd/yyyy').parse(dateStr);
          final String formattedDateForPrompt = DateFormat('yyyy-MM-dd').format(parsedDate);
          ingredientsToUseInPrompt.add('$ingredientName ($formattedDateForPrompt)');
        } catch (e) {
          log("Error parsing date for $ingredientName: $dateStr. Using name only. Error: $e");
          ingredientsToUseInPrompt.add(ingredientName);
        }
      } else {
        ingredientsToUseInPrompt.add(ingredientName);
      }
    }

    ingredientsToUseInPrompt.sort();

    final String ingredientsStr = ingredientsToUseInPrompt.join(', ');
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String dietaryRestrictionsStr;
    if (_selectedDietaryRestrictions.contains('none') && _selectedDietaryRestrictions.length == 1) {
      dietaryRestrictionsStr = 'None';
    } else {
      final filteredRestrictions = _selectedDietaryRestrictions.where((r) => r != 'none').join(', ');
      dietaryRestrictionsStr = filteredRestrictions.isEmpty ? 'None' : filteredRestrictions.capitalize();
    }

    String prompt;
    final String requiredIngredientsList = _requiredIngredients.join(', ');
    if (_requiredIngredients.isEmpty && _autoExpandIngredients) {
      prompt = """You are a chef creating recipes for beginners.
TASK: Create ONE complete recipe using only ingredients from the provided lists.
RULES:
1. You MAY use: $ingredientsStr.
2. The recipe has to be $dietaryRestrictionsStr, $_selectedCuisineStyle.
3. Prioritize OLDER Ingredients. TODAY'S DATE: $todayDate.
4. You are not allowed to use Ingredients I did not mention.
5. Output EXACTLY in the specified format (no additional text).
OUTPUT FORMAT (STRICT):
Title: [recipe name]
Ingredients: [ingredient1] [quantity] [unit], [ingredient2] [quantity] [unit], ...
Instructions: 1. [step], 2. [step], 3. [step], ...
Used Ingredients: [ingredient_name_from_available_list], [ingredient_name_from_available_list], ...""";
    } else if (_requiredIngredients.isNotEmpty && _autoExpandIngredients){
      prompt = """You are a chef creating recipes for beginners.
TASK: Create ONE complete recipe using only ingredients from the provided lists.
RULES:
1. Use ALL of: $requiredIngredientsList.
2. You MAY use: $ingredientsStr.
3. The recipe has to be $dietaryRestrictionsStr, $_selectedCuisineStyle.
4. Prioritize OLDER Ingredients. TODAY'S DATE: $todayDate.
5. You are not allowed to use Ingredients I did not mention.
6. Output EXACTLY in the specified format (no additional text).
OUTPUT FORMAT (STRICT):
Title: [recipe name]
Ingredients: [ingredient1] [quantity] [unit], [ingredient2] [quantity] [unit], ...
Instructions: 1. [step], 2. [step], 3. [step], ...
Used Ingredients: [ingredient_name_from_available_list], [ingredient_name_from_available_list], ...""";
    } else {
  prompt = """You are a chef creating recipes for beginners.
TASK: Create ONE complete recipe using only ingredients from the provided lists.
RULES:
1. Use ALL of: $requiredIngredientsList.
2. The recipe has to be $dietaryRestrictionsStr, $_selectedCuisineStyle.
3. Prioritize OLDER Ingredients. TODAY'S DATE: $todayDate.
4. You are not allowed to use Ingredients I did not mention.
5. Output EXACTLY in the specified format (no additional text).
OUTPUT FORMAT (STRICT):
Title: [recipe name]
Ingredients: [ingredient1] [quantity] [unit], [ingredient2] [quantity] [unit], ...
Instructions: 1. [step], 2. [step], 3. [step], ...
Used Ingredients: [ingredient_name_from_available_list], [ingredient_name_from_available_list], ...""";
  }
    try {
      final response = await http.post(
        Uri.parse(_chatCompletionsApiEndpoint),
        headers: {
          'Authorization': 'Bearer $huggingFaceApiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": _currentApiEndpointModel,
          "messages": [
            {
              "role": "user",
              "content": prompt,
            }
          ],
          "max_tokens": 1000,
          "temperature": 0.7,
          "top_p": 0.9,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['choices'] != null &&
            data['choices'].isNotEmpty &&
            data['choices'][0]['message'] != null &&
            data['choices'][0]['message']['content'] != null) {
          setState(() {
            _apiResponse = data['choices'][0]['message']['content'];
            // NEW: Parse API response and create Recipe object
            _currentRecipe = _parseApiResponseToRecipe(_apiResponse);
          });
          log("API Response received and parsed. Title: ${_currentRecipe?.title}");

          // NEW: Check if the generated recipe is already saved
          if (_currentRecipe != null) {
            final bool saved = await _savedRecipeService.isRecipeSaved(_currentRecipe!.id);
            setState(() {
              _isCurrentRecipeSaved = saved;
            });
            log('Recipe2Page: Is newly generated recipe saved? $_isCurrentRecipeSaved (ID: ${_currentRecipe!.id})');
          }
        } else {
          setState(() {
            _apiResponse = 'Error: Invalid response structure from API (expected Choices/Message/Content).';
            _currentRecipe = _parseApiResponseToRecipe(_apiResponse); // Generate error recipe
          });
          log('API Error: Unexpected response structure: $data');
        }
      } else {
        setState(() {
          _apiResponse = 'Error during API call: ${response.statusCode}\n${response.body}';
          _currentRecipe = _parseApiResponseToRecipe(_apiResponse); // Generate error recipe
        });
        log('API Error: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _apiResponse = 'Error: Could not connect to API. $e';
        _currentRecipe = _parseApiResponseToRecipe(_apiResponse); // Generate error recipe
      });
      log('Network Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          log('Recipe2Page: Loading finished.');
        });
      }
    }
  }

  // NEW: Method to save/delete the current recipe
  Future<void> _toggleSaveRecipe() async {
    if (_currentRecipe == null || _currentRecipe!.title.isEmpty || _currentRecipe!.ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid recipe to save/delete.'),
          backgroundColor: Colors.red,
        ),
      );
      log('Recipe2Page: Attempted to save/delete invalid recipe (currentRecipe is null or empty).');
      return;
    }

    if (_currentRecipe!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe has no valid ID to save/delete.'),
          backgroundColor: Colors.red,
        ),
      );
      log('Recipe2Page: Recipe has no valid ID for saving/deleting.');
      return;
    }

    if (_isCurrentRecipeSaved) {
      try {
        await _savedRecipeService.deleteRecipeLocally(_currentRecipe!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe "${_currentRecipe!.title}" successfully deleted locally!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isCurrentRecipeSaved = false;
          });
          log('Recipe2Page: Recipe "${_currentRecipe!.title}" deleted successfully.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting recipe locally: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          log('Recipe2Page: Error deleting recipe: $e', error: e);
        }
      }
    } else {
      try {
        await _savedRecipeService.saveRecipeLocally(_currentRecipe!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe "${_currentRecipe!.title}" successfully saved locally!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isCurrentRecipeSaved = true;
          });
          log('Recipe2Page: Recipe "${_currentRecipe!.title}" saved successfully.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving recipe locally: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          log('Recipe2Page: Error saving recipe: $e', error: e);
        }
      }
    }
  }

  void _onBackToIngredientSelection() {
    setState(() {
      _isShowingRecipeResult = false;
      _apiResponse = ''; // Clear response when going back to selection
      _isLoading = false;
      _currentRecipe = null; // Important: Reset current recipe
      _isCurrentRecipeSaved = false; // Reset save status
    });
    log('Recipe2Page: Back to ingredient selection. Current recipe cleared.');
  }

  Future<void> _onRefreshData() async {
    log('Recipe2Page: Refreshing data...');
    await _loadInventory(); // Lade das Inventar neu
    setState(() {
      _requiredIngredients.clear(); // Auch die ausgewählten Zutaten zurücksetzen
    });
    log('Recipe2Page: Data refreshed and required ingredients cleared.');
  }

  void _onToggleAutoExpand(bool? newValue) {
    if (newValue != null) {
      setState(() {
        _autoExpandIngredients = newValue;
      });
      _saveSettings(); // Speichere die Einstellung sofort
      log('Recipe2Page: Auto expand ingredients toggled to $_autoExpandIngredients');
    }
  }

  void _onResetRequiredIngredients() {
    setState(() {
      _requiredIngredients.clear();
    });
    log('Recipe2Page: Required ingredients reset.');
  }

  List<Widget> _buildAppBarActions() {
    if (_isShowingRecipeResult && !_isLoading && _currentRecipe != null && _currentRecipe!.title != 'Error Generating Recipe') {
      return [
        IconButton(
          icon: const Icon(Icons.refresh), // Reload button
          tooltip: 'Regenerate Recipe',
          onPressed: _onGenerateRecipe, // Calls the generate recipe function
        ),
        IconButton(
          icon: Icon(
            _isCurrentRecipeSaved ? Icons.favorite : Icons.favorite_border,
            color: _isCurrentRecipeSaved ? Colors.red : null,
          ),
          tooltip: _isCurrentRecipeSaved ? 'Remove recipe' : 'Save recipe',
          onPressed: _toggleSaveRecipe,
        ),
      ];
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isShowingRecipeResult ? const Text('Suggestion') : Text('Select ingredients'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        leading: _isShowingRecipeResult && !_isLoading
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Adjust Ingredients',
          onPressed: _onBackToIngredientSelection,
        )
            : null,
        actions: _buildAppBarActions(),
      ),
      body: _isShowingRecipeResult
          ? RecipeDisplay2(
        isLoading: _isLoading,
        currentRecipe: _currentRecipe,
        onGenerateRecipe: _onGenerateRecipe,
        onBackToIngredientSelection: _onBackToIngredientSelection,
        onDeductIngredients: _onDeductIngredients,
        hasIngredients: _hasIngredients,
        isCurrentRecipeSaved: _isCurrentRecipeSaved,
        onToggleSaveRecipe: _toggleSaveRecipe,
      )
          : RefreshIndicator(
        onRefresh: _onRefreshData,
        child: IngredientSelector2(
          vegetablesMap: _vegetablesMap,
          mainIngredientsMap: _mainIngredientsMap,
          spicesMap: _spicesMap,
          othersMap: _othersMap,
          requiredIngredients: _requiredIngredients,
          autoExpandIngredients: _autoExpandIngredients,
          onToggleIngredient: _onToggleIngredient,
          onGenerateRecipe: _onGenerateRecipe,
          onToggleAutoExpand: () {
            _onToggleAutoExpand(!_autoExpandIngredients);
          },
          onResetRequiredIngredients: _onResetRequiredIngredients,
          onRefreshData: _onRefreshData,
          selectedCuisineStyle: _selectedCuisineStyle,
          onCuisineStyleChanged: (value) {
            setState(() {
              _selectedCuisineStyle = value;
            });
          },
          selectedDietaryRestrictions: _selectedDietaryRestrictions,
          onDietaryRestrictionsChanged: (newRestrictions) {
            setState(() {
              _selectedDietaryRestrictions = newRestrictions;
            });
          },
        ),
      ),
    );
  }
}


