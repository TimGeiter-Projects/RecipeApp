import 'package:flutter/material.dart';
import 'data/recipe.dart'; // Importiere dein Recipe-Modell hier

class RecipeEditPage extends StatefulWidget {
  final Recipe recipe;

  const RecipeEditPage({super.key, required this.recipe});

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  // Controller für jedes bearbeitbare Textfeld
  late TextEditingController _titleController;
  late TextEditingController _ingredientsController;
  late TextEditingController _directionsController;
  late TextEditingController _usedIngredientsController;

  @override
  void initState() {
    super.initState();
    // Initialisiere die Controller mit den aktuellen Rezeptdaten
    _titleController = TextEditingController(text: widget.recipe.title);
    // Listen werden zu einem String mit Zeilenumbrüchen verbunden, um sie in einem TextField zu bearbeiten
    _ingredientsController = TextEditingController(text: widget.recipe.ingredients.join('\n'));
    _directionsController = TextEditingController(text: widget.recipe.directions.join('\n'));
    _usedIngredientsController = TextEditingController(text: widget.recipe.usedIngredients.join('\n'));
  }

  @override
  void dispose() {
    // Controller entsorgen, um Speicherlecks zu vermeiden
    _titleController.dispose();
    _ingredientsController.dispose();
    _directionsController.dispose();
    _usedIngredientsController.dispose();
    super.dispose();
  }

  // Funktion zum Speichern der bearbeiteten Rezeptdaten
  void _saveRecipe() {
    // Texteingaben zurück in Listen aufteilen, leere Zeilen entfernen und trimmen
    final List<String> updatedIngredients = _ingredientsController.text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    final List<String> updatedDirections = _directionsController.text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    final List<String> updatedUsedIngredients = _usedIngredientsController.text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();

    // Ein neues Recipe-Objekt mit den aktualisierten Werten erstellen
    final updatedRecipe = Recipe(
      id: widget.recipe.id, // Die ID bleibt gleich
      title: _titleController.text.trim(),
      ingredients: updatedIngredients,
      directions: updatedDirections,
      usedIngredients: updatedUsedIngredients,
      savedAt: widget.recipe.savedAt, // Das Speicherdatum bleibt ebenfalls gleich
    );

    // Das aktualisierte Rezept an die vorherige Seite zurückgeben
    Navigator.pop(context, updatedRecipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit recipe'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Speichern-Button in der AppBar
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save recipe',
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Textfeld für den Titel
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Textfeld für Zutaten (mehrzeilig)
            TextFormField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                labelText: 'Ingredients',
                alignLabelWithHint: true, // Label oben links ausgerichtet bei mehrzeiligen Feldern
                border: OutlineInputBorder(),
              ),
              maxLines: null, // Erlaubt unbegrenzte Zeilen
              keyboardType: TextInputType.multiline, // Tastaturtyp für mehrere Zeilen
            ),
            const SizedBox(height: 16),
            // Textfeld für Anweisungen (mehrzeilig)
            TextFormField(
              controller: _directionsController,
              decoration: const InputDecoration(
                labelText: 'Directions',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            // Textfeld für verwendete Zutaten (KI-Generierung, mehrzeilig)
            TextFormField(
              controller: _usedIngredientsController,
              decoration: const InputDecoration(
                labelText: 'Used ingredients',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              // Kann bearbeitet werden, auch wenn KI-generiert
              enabled: true,
            ),
            const SizedBox(height: 24),
            // Zentrierter Speichern-Button am unteren Rand
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveRecipe,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ANNAHME: Das Recipe-Modell ist in 'data/recipe.dart' definiert und enthält
// die toJson() und fromJson() Methoden sowie die Felder:
// id, title, ingredients, directions, usedIngredients, savedAt.
// Ein Beispiel-Modell könnte so aussehen:
/*
import 'package:flutter/foundation.dart';

class Recipe {
  final String id;
  String title;
  List<String> ingredients;
  List<String> directions;
  List<String> usedIngredients;
  DateTime savedAt;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.directions,
    required this.usedIngredients,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ingredients': ingredients,
      'directions': directions,
      'usedIngredients': usedIngredients,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      ingredients: List<String>.from(json['ingredients'] as List),
      directions: List<String>.from(json['directions'] as List),
      usedIngredients: List<String>.from(json['usedIngredients'] as List),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}
*/
