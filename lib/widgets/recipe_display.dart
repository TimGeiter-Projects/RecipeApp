import 'package:flutter/material.dart';

class RecipeDisplay extends StatelessWidget {
  final Map<String, dynamic> recipeData;
  final bool isLoading;
  final VoidCallback onDeductIngredients;
  final bool hasIngredients;

  // onSaveRecipe und isCurrentRecipeSaved werden hier nicht mehr benötigt
  // da der Speichern/Löschen-Button in die AppBar der RecipePage verschoben wurde.
  const RecipeDisplay({
    super.key,
    required this.recipeData,
    required this.isLoading,
    required this.onDeductIngredients,
    required this.hasIngredients,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasIngredients) {
      return const Center(child: Text("Keine Zutaten im Inventar vorhanden."));
    }

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Generating recipe..."),
            SizedBox(height: 8),
            Text(
              "This will take a moment.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (recipeData.isEmpty || recipeData['title'] == null) {
      return const Center(child: Text("No recipe generated yet."));
    }

    // Fehlerbehandlung für API-Fehler
    if (recipeData.containsKey('error') || (recipeData['ingredients'] != null && recipeData['ingredients'].contains('Fehler beim Generieren des Rezepts.'))) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                recipeData['title'] ?? 'Fehler',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                (recipeData['directions'] as List<String>).join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(), // Gehe zurück zur Zutatenauswahl
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to ingredient selection'),
              ),
            ],
          ),
        ),
      );
    }


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipeData['title'] ?? 'Recipe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Der blaue Speichern-Button wurde hier vollständig entfernt.

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
          _buildIngredientsList(context, recipeData['ingredients'] ?? []),
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
          _buildDirectionsList(context, recipeData['directions'] ?? []),

          const SizedBox(height: 24),
          if (recipeData['used_ingredients'] != null && (recipeData['used_ingredients'] as List).isNotEmpty) ...[
            Text(
              "Used ingredients: ${(recipeData['used_ingredients'] as List).join(', ')}",
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (recipeData['used_ingredients'] != null && (recipeData['used_ingredients'] as List).isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDeductIngredients,
                icon: const Icon(Icons.remove_shopping_cart),
                label: const Text(
                  'Deduct used ingredients from inventory',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Powered by AI Recipe Generation disclaimer
          const Center(
            child: Text(
              '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(BuildContext context, List<dynamic> ingredients) {
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
                child: Text(ingredients[index].toString(), style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectionsList(BuildContext context, List<dynamic> directions) {
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
                child: Text(directions[index].toString(), style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        );
      },
    );
  }
}
