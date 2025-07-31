import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/recipe.dart'; // Stelle sicher, dass der Pfad korrekt ist

class SavedRecipeService {
  static const String _recipesKey = 'saved_recipes';

  // Speichert ein einzelnes Rezept lokal.
  // Überschreibt es, wenn die ID bereits existiert, oder fügt es hinzu.
  Future<void> saveRecipeLocally(Recipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString(_recipesKey);
    List<Recipe> savedRecipes = [];

    if (recipesJson != null && recipesJson.isNotEmpty) {
      final List<dynamic> decodedList = jsonDecode(recipesJson);
      savedRecipes = decodedList.map((item) => Recipe.fromJson(item as Map<String, dynamic>)).toList();
    }

    // Prüfen, ob ein Rezept mit derselben ID bereits existiert
    int existingIndex = savedRecipes.indexWhere((r) => r.id == recipe.id);

    if (existingIndex != -1) {
      // Rezept aktualisieren
      savedRecipes[existingIndex] = recipe;
    } else {
      // Neues Rezept hinzufügen
      savedRecipes.add(recipe);
    }

    final List<Map<String, dynamic>> encodedList = savedRecipes.map((r) => r.toJson()).toList();
    await prefs.setString(_recipesKey, jsonEncode(encodedList));
    print('SavedRecipeService: Rezept "${recipe.title}" gespeichert/aktualisiert.');
  }

  // Lädt alle lokal gespeicherten Rezepte.
  Future<List<Recipe>> loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString(_recipesKey);

    if (recipesJson != null && recipesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(recipesJson);
        final List<Recipe> recipes = decodedList.map((item) => Recipe.fromJson(item as Map<String, dynamic>)).toList();
        print('SavedRecipeService: ${recipes.length} Rezepte geladen.');
        return recipes;
      } catch (e) {
        print('SavedRecipeService: Fehler beim Laden/Decodieren der Rezepte: $e');
        // Im Fehlerfall leere Liste zurückgeben, um App-Crash zu vermeiden
        return [];
      }
    }
    print('SavedRecipeService: Keine Rezepte gefunden.');
    return [];
  }

  // Löscht ein Rezept anhand seiner ID.
  Future<void> deleteRecipeLocally(String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString(_recipesKey);
    List<Recipe> savedRecipes = [];

    if (recipesJson != null && recipesJson.isNotEmpty) {
      final List<dynamic> decodedList = jsonDecode(recipesJson);
      savedRecipes = decodedList.map((item) => Recipe.fromJson(item as Map<String, dynamic>)).toList();
    }

    final int initialLength = savedRecipes.length;
    savedRecipes.removeWhere((r) => r.id == recipeId);

    if (savedRecipes.length < initialLength) {
      final List<Map<String, dynamic>> encodedList = savedRecipes.map((r) => r.toJson()).toList();
      await prefs.setString(_recipesKey, jsonEncode(encodedList));
      print('SavedRecipeService: Rezept mit ID "$recipeId" gelöscht.');
    } else {
      print('SavedRecipeService: Rezept mit ID "$recipeId" nicht gefunden zum Löschen.');
    }
  }

  // Prüft, ob ein Rezept bereits gespeichert ist.
  Future<bool> isRecipeSaved(String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString(_recipesKey);

    if (recipesJson != null && recipesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(recipesJson);
        return decodedList.any((item) => item['id'] == recipeId);
      } catch (e) {
        print('SavedRecipeService: Fehler beim Prüfen des gespeicherten Rezepts: $e');
        return false;
      }
    }
    return false;
  }
}