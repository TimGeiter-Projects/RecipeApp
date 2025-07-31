import 'package:flutter/material.dart';
import '../data/recipe.dart'; // Füge dies hinzu

class RecipeDisplay2 extends StatelessWidget {
  final bool isLoading;
  // ÄNDERUNG: Ersetze apiResponse durch currentRecipe
  final Recipe? currentRecipe;
  final VoidCallback onGenerateRecipe;
  final VoidCallback onBackToIngredientSelection;
  final VoidCallback onDeductIngredients;
  final bool hasIngredients;
  // NEU: Callback für den Speicherstatus
  final bool isCurrentRecipeSaved;
  final VoidCallback onToggleSaveRecipe; // NEU: Callback für Speichern/Löschen

  const RecipeDisplay2({
    super.key,
    required this.isLoading,
    required this.currentRecipe, // ÄNDERUNG
    required this.onGenerateRecipe,
    required this.onBackToIngredientSelection,
    required this.onDeductIngredients,
    required this.hasIngredients,
    required this.isCurrentRecipeSaved, // NEU
    required this.onToggleSaveRecipe, // NEU
  });

  // Die _parseApiResponse Methode ist NICHT MEHR HIER.
  // Sie wurde in Recipe2Page verschoben.

  @override
  Widget build(BuildContext context) {
    if (!hasIngredients) {
      return const Center(child: Text("No ingredients available in inventory."));
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

    // ACHTUNG: Hier wird jetzt direkt das übergebene currentRecipe verwendet
    if (currentRecipe == null || currentRecipe!.directions.isEmpty) {
      // Dies sollte eigentlich nicht passieren, da _currentRecipe in Recipe2Page gesetzt wird.
      // Wenn es doch passiert, ist es ein Fehlerfall (z.B. wenn das Parsen fehlschlägt).
      // Oder ein leeres/ungültiges Rezept vom Service zurückgegeben wird.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                currentRecipe?.title ?? 'Error loading/parsing the recipe',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                (currentRecipe?.directions.isNotEmpty == true
                    ? currentRecipe!.directions.join('\n')
                    : 'There was an unexpected problem displaying the recipe.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onBackToIngredientSelection,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to ingredient selection'),
              ),
            ],
          ),
        ),
      );
    }

    // Wenn currentRecipe != null und gültig ist
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        onBackToIngredientSelection();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    currentRecipe!.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // ENTFERNT: Speichern/Löschen Button (Herz-Icon)
                // IconButton(
                //   icon: Icon(
                //     isCurrentRecipeSaved ? Icons.favorite : Icons.favorite_border,
                //     color: isCurrentRecipeSaved ? Colors.red : null,
                //   ),
                //   tooltip: isCurrentRecipeSaved ? 'Rezept entfernen' : 'Rezept speichern',
                //   onPressed: onToggleSaveRecipe,
                // ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("Ingredients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            const SizedBox(height: 8),
            _buildList(context, currentRecipe!.ingredients, isIngredient: true),
            const SizedBox(height: 24),
            const Text("Directions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            const SizedBox(height: 8),
            _buildList(context, currentRecipe!.directions, isIngredient: false),
            const SizedBox(height: 24),

            if (currentRecipe!.usedIngredients.isNotEmpty) ...[
              Text(
                "Used Ingredients: ${currentRecipe!.usedIngredients.join(', ')}",
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDeductIngredients,
                  icon: const Icon(Icons.remove_shopping_cart),
                  label: const Text('Deduct used ingredients from inventory', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Debug-Ansicht der rohen API-Antwort beibehalten
            ExpansionTile(
              title: const Text('Raw API response '),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(currentRecipe!.toJson().toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ENTFERNT: Die Row mit den Buttons "Zutaten anpassen" und "Neues Rezept"
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     Expanded(
            //       child: ElevatedButton.icon(
            //         onPressed: onBackToIngredientSelection,
            //         icon: const Icon(Icons.arrow_back),
            //         label: const Text('Zutaten anpassen'),
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: Colors.blueGrey,
            //           foregroundColor: Colors.white,
            //           padding: const EdgeInsets.symmetric(vertical: 14),
            //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 10),
            //     Expanded(
            //       child: ElevatedButton.icon(
            //         onPressed: onGenerateRecipe,
            //         icon: const Icon(Icons.refresh),
            //         label: const Text('Neues Rezept'),
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: Theme.of(context).colorScheme.primary,
            //           foregroundColor: Colors.white,
            //           padding: const EdgeInsets.symmetric(vertical: 14),
            //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<String> items, {required bool isIngredient}) {
    if (items.isEmpty) {
      return Text(
        isIngredient ? 'No ingredients found.' : 'No instructions found.',
        style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: isIngredient ? 8 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isIngredient)
                const Icon(Icons.check_circle_outline, size: 20, color: Colors.green)
              else
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
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items[index], // `items` ist jetzt bereits List<String>
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}