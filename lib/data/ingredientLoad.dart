// lib/data/ingredient_data_manager.dart

import 'package:collection/collection.dart';
import 'ingredients.dart'; // Import the raw data file

// Define the structure for an individual ingredient within a category
class IngredientData {
  final String name;
  final int frequency; // Changed to int for proper numerical comparison

  IngredientData({required this.name, required this.frequency});

  // Factory constructor to create an IngredientData from a Map
  factory IngredientData.fromMap(Map<String, dynamic> map) {
    return IngredientData(
      name: map['name'] as String,
      frequency: int.tryParse(map['frequency'] as String? ?? '0') ?? 0, // Safely parse frequency to int
    );
  }
}

// --- Global variables for easy access after initialization ---
late List<IngredientData> allIngredientsSortedByFrequency;
late Map<String, String> _ingredientCategoryMap; // Maps ingredient name (lowercase) to its category

/// Initializes the global ingredient data.
/// This should be called once at application startup (e.g., in main.dart)
/// or before accessing ingredient data for the first time.
void initializeIngredientData() {
  print("IngredientDataManager: Initializing ingredient data...");

  final List<IngredientData> allIngredients = [];
  _ingredientCategoryMap = {};

  for (var categoryMap in ingredientCategories) { // Use ingredientCategories from ingredients.dart
    final String categoryName = categoryMap["name"] as String;
    final List<dynamic> ingredientsList = categoryMap["ingredients"] as List<dynamic>;

    for (var ingredientMap in ingredientsList) {
      final IngredientData ingredient = IngredientData.fromMap(ingredientMap as Map<String, dynamic>);
      allIngredients.add(ingredient);
      _ingredientCategoryMap[ingredient.name.toLowerCase()] = categoryName; // Store in lowercase for lookup
    }
  }

  // Sort all ingredients by frequency in descending order
  allIngredientsSortedByFrequency = allIngredients
      .sorted((a, b) => b.frequency.compareTo(a.frequency)); // Descending order

  print("IngredientDataManager: Ingredient data initialized. Total ingredients: ${allIngredientsSortedByFrequency.length}");
}

/// Returns the category name for a given ingredient.
/// If the ingredient is not found in any defined categories, it defaults to "Others".
String getCategoryForIngredient(String ingredientName) {
  final String normalizedName = ingredientName.toLowerCase();
  return _ingredientCategoryMap[normalizedName] ?? "Others";
}