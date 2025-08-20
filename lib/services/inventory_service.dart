import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../data/IngriedientEntry.dart';

class InventoryService {
  Map<String, List<IngredientEntry>> _ingredientCountVegetables = {};
  Map<String, List<IngredientEntry>> _ingredientCountMain = {};
  Map<String, List<IngredientEntry>> _ingredientCountSpices = {};
  Map<String, List<IngredientEntry>> _ingredientCountOthers = {};
  Map<String, Map<String, dynamic>> _lastUsedUnits = {};

  Map<String, List<IngredientEntry>> get ingredientCountVegetables => Map.from(_ingredientCountVegetables);
  Map<String, List<IngredientEntry>> get ingredientCountMain => Map.from(_ingredientCountMain);
  Map<String, List<IngredientEntry>> get ingredientCountSpices => Map.from(_ingredientCountSpices);
  Map<String, List<IngredientEntry>> get ingredientCountOthers => Map.from(_ingredientCountOthers);
  Map<String, Map<String, dynamic>> get lastUsedUnits => Map.from(_lastUsedUnits);

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Map<String, List<IngredientEntry>> _decodeMap(String? jsonString) {
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
        return decodedMap.map((key, value) {
          final List<dynamic> entryListJson = value as List<dynamic>;
          final List<IngredientEntry> entries = entryListJson
              .map((entryJson) => IngredientEntry.fromJson(entryJson as Map<String, dynamic>))
              .toList();
          return MapEntry(key, entries);
        });
      } catch (e) {
        print("InventoryService: Error decoding map for inventory: $e, json: $jsonString");
      }
    }
    return {};
  }

  Future<void> loadInventory() async {
    print("InventoryService: loadInventory is being executed...");
    final prefs = await SharedPreferences.getInstance();

    _ingredientCountVegetables = _decodeMap(prefs.getString('Vegetables'));
    _ingredientCountMain = _decodeMap(prefs.getString('Main Ingredients'));
    _ingredientCountSpices = _decodeMap(prefs.getString('Spices'));
    _ingredientCountOthers = _decodeMap(prefs.getString('Others'));

    print("--- InventoryService: LOADING FROM PREFS ---");
    print("Loaded Vegetables: $_ingredientCountVegetables");
    print("Loaded Main Ingredients: $_ingredientCountMain");
    print("Loaded Spices: $_ingredientCountSpices");
    print("Loaded Others: $_ingredientCountOthers");
    print("------------------------------------------");
  }

  Future<void> saveInventory() async {
    final prefs = await SharedPreferences.getInstance();

    Future<void> _encodeAndSet(String key, Map<String, List<IngredientEntry>> map) async {
      final jsonString = jsonEncode(map.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())));
      print("InventoryService: Attempting to save '$key': $jsonString");
      await prefs.setString(key, jsonString);
    }

    await _encodeAndSet('Vegetables', _ingredientCountVegetables);
    await _encodeAndSet('Main Ingredients', _ingredientCountMain);
    await _encodeAndSet('Spices', _ingredientCountSpices);
    await _encodeAndSet('Others', _ingredientCountOthers);
    print("InventoryService: Inventory save completed.");
  }

  Future<void> loadLastUsedUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('lastUsedUnits');
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
        _lastUsedUnits = decodedMap.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
        print("InventoryService: Loaded lastUsedUnits: $_lastUsedUnits");
      } catch (e) {
        print("InventoryService: Error decoding lastUsedUnits: $e");
      }
    }
  }

  Future<void> saveLastUsedUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_lastUsedUnits);
    await prefs.setString('lastUsedUnits', jsonString);
    print("InventoryService: Saved lastUsedUnits: $jsonString");
  }

  Future<void> addIngredient(IngredientEntry newEntry) async {
    final String normalizedIngredient = newEntry.name.toLowerCase();
    final String category = newEntry.category;

    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(category);

    bool entryFoundAndUpdated = false;
    if (targetMap.containsKey(normalizedIngredient)) {
      final List<IngredientEntry> existingEntries = targetMap[normalizedIngredient]!;
      for (int i = 0; i < existingEntries.length; i++) {
        final IngredientEntry existingEntry = existingEntries[i];
        if (existingEntry.unit == newEntry.unit && _isSameDay(existingEntry.dateAdded, newEntry.dateAdded)) {
          existingEntry.quantity += newEntry.quantity;
          entryFoundAndUpdated = true;
          break;
        }
      }
    }

    if (!entryFoundAndUpdated) {
      targetMap.update(
        normalizedIngredient,
            (list) => list..add(newEntry),
        ifAbsent: () => [newEntry],
      );
    }

    _lastUsedUnits[normalizedIngredient] = {
      'unit': newEntry.unit,
      'quantity': newEntry.quantity,
    };

    await saveInventory();
    await saveLastUsedUnits();
    print("InventoryService: Ingredient added/updated and saved successfully: ${newEntry.name}");
  }

  Future<void> removeSpecificIngredientEntry(IngredientEntry entryToDelete, String ingredientKey, String categoryMapKey) async {
    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(categoryMapKey);
    List<IngredientEntry>? entries = targetMap[ingredientKey];

    if (entries != null) {
      int indexToRemove = entries.indexWhere((entry) =>
      entry.dateAdded == entryToDelete.dateAdded &&
          entry.quantity == entryToDelete.quantity &&
          entry.unit == entryToDelete.unit &&
          entry.name == entryToDelete.name
      );

      if (indexToRemove != -1) {
        entries.removeAt(indexToRemove);

        if (entries.isEmpty) {
          targetMap.remove(ingredientKey);
        }

        await saveInventory();
        print("InventoryService: Successfully removed specific entry for $ingredientKey");
      } else {
        print("InventoryService: Entry not found for removal");
      }
    }
  }

  Future<void> removeIngredient(String ingredientKey, String categoryMapKey) async {
    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(categoryMapKey);
    if (targetMap.remove(ingredientKey) != null) {
      await saveInventory();
    }
  }

  Future<void> clearCategory(String categoryMapKey) async {
    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(categoryMapKey);
    targetMap.clear();
    await saveInventory();
  }

  Map<String, List<IngredientEntry>> _getTargetMap(String categoryMapKey) {
    switch (categoryMapKey) {
      case "Vegetables":
        return _ingredientCountVegetables;
      case "Main Ingredients":
        return _ingredientCountMain;
      case "Spices":
        return _ingredientCountSpices;
      case "Others":
        return _ingredientCountOthers;
      default:
        print("Warning: Unknown category map key: $categoryMapKey. Defaulting to _ingredientCountOthers.");
        return _ingredientCountOthers;
    }
  }

  bool areAllInventoriesEmpty() {
    return _ingredientCountVegetables.isEmpty &&
        _ingredientCountMain.isEmpty &&
        _ingredientCountSpices.isEmpty &&
        _ingredientCountOthers.isEmpty;
  }

  Future<void> deductIngredientQuantity(String ingredientName, String category, double amountToDeduct) async {
    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(category);
    List<IngredientEntry>? entries = targetMap[ingredientName];

    if (entries == null || entries.isEmpty) {
      print("InventoryService: Cannot deduct $amountToDeduct of $ingredientName. No entries found.");
      return;
    }

    entries.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));

    double remainingToDeduct = amountToDeduct;
    List<IngredientEntry> updatedEntries = [];

    for (IngredientEntry entry in entries) {
      if (remainingToDeduct <= 0) {
        updatedEntries.add(entry);
        continue;
      }

      if (entry.quantity > remainingToDeduct) {
        entry.quantity -= remainingToDeduct;
        updatedEntries.add(entry);
        remainingToDeduct = 0;
      } else {
        remainingToDeduct -= entry.quantity;
      }
    }

    if (remainingToDeduct > 0) {
      print("InventoryService: Warning: Not enough $ingredientName to deduct $amountToDeduct. Only ${amountToDeduct - remainingToDeduct} was deducted.");
    }

    if (updatedEntries.isEmpty) {
      targetMap.remove(ingredientName);
    } else {
      targetMap[ingredientName] = updatedEntries;
    }

    if (_lastUsedUnits.containsKey(ingredientName)) {
      _lastUsedUnits[ingredientName]!['quantity'] = 0.0;
    }

    await saveInventory();
    await saveLastUsedUnits();
    print("InventoryService: Deducted $amountToDeduct from $ingredientName. Remaining total: ${targetMap[ingredientName]?.fold(0.0, (sum, e) => sum + e.quantity) ?? 0.0} ${entries.first.unit}");
  }


  Future<void> updateIngredientEntryQuantity(String ingredientKey, String categoryMapKey, IngredientEntry originalEntry, double newQuantity) async {
    Map<String, List<IngredientEntry>> targetMap = _getTargetMap(categoryMapKey);
    List<IngredientEntry>? entries = targetMap[ingredientKey];

    if (entries == null) {
      print("InventoryService: Cannot update quantity. No entries found for $ingredientKey.");
      return;
    }

    int indexToUpdate = entries.indexWhere((entry) =>
    entry.name == originalEntry.name &&
        entry.dateAdded == originalEntry.dateAdded &&
        entry.unit == originalEntry.unit &&
        entry.quantity == originalEntry.quantity);
    if (indexToUpdate != -1) {
      if (newQuantity <= 0) {
        entries.removeAt(indexToUpdate);
        if (entries.isEmpty) {
          targetMap.remove(ingredientKey);
        }
        print("InventoryService: Removed entry for $ingredientKey (quantity <= 0).");
      } else {
        // Aktualisiere die Menge des spezifischen Eintrags
        entries[indexToUpdate].quantity = newQuantity;
        print("InventoryService: Updated quantity for $ingredientKey (specific entry). New quantity: $newQuantity");
      }

      await saveInventory();

    } else {
      print("InventoryService: Original entry not found for update for $ingredientKey. May have been modified or deleted elsewhere.");
    }
  }
}