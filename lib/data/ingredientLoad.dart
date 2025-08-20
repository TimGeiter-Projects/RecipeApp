// lib/data/ingredient_data_manager.dart

import 'package:collection/collection.dart';
import 'ingredients.dart';

class IngredientData {
  final String name;
  final int frequency;

  IngredientData({required this.name, required this.frequency});

  factory IngredientData.fromMap(Map<String, dynamic> map) {
    return IngredientData(
      name: map['name'] as String,
      frequency: int.tryParse(map['frequency'] as String? ?? '0') ?? 0,
    );
  }
}

late List<IngredientData> allIngredientsSortedByFrequency;
late Map<String, String> _ingredientCategoryMap;


void initializeIngredientData() {
  print("IngredientDataManager: Initializing ingredient data...");

  final List<IngredientData> allIngredients = [];
  _ingredientCategoryMap = {};

  for (var categoryMap in ingredientCategories) {
    final String categoryName = categoryMap["name"] as String;
    final List<dynamic> ingredientsList = categoryMap["ingredients"] as List<dynamic>;

    for (var ingredientMap in ingredientsList) {
      final IngredientData ingredient = IngredientData.fromMap(ingredientMap as Map<String, dynamic>);
      allIngredients.add(ingredient);
      _ingredientCategoryMap[ingredient.name.toLowerCase()] = categoryName; // Store in lowercase for lookup
    }
  }

  allIngredientsSortedByFrequency = allIngredients
      .sorted((a, b) => b.frequency.compareTo(a.frequency)); // Descending order

  print("IngredientDataManager: Ingredient data initialized. Total ingredients: ${allIngredientsSortedByFrequency.length}");
}


String getCategoryForIngredient(String ingredientName) {
  final String normalizedName = ingredientName.toLowerCase();
  return _ingredientCategoryMap[normalizedName] ?? "Others";
}