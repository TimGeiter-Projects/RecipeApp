import 'package:flutter/material.dart';
import '../recipe_page.dart'; // Importieren Sie Ihre bestehende RecipePage
import '../recipe2_page.dart'; // Importieren Sie Ihre bestehende Recipe2Page

class RecipeGenerationModeSelector extends StatefulWidget {
  const RecipeGenerationModeSelector({super.key});

  @override
  State<RecipeGenerationModeSelector> createState() => _RecipeGenerationModeSelectorState();
}

class _RecipeGenerationModeSelectorState extends State<RecipeGenerationModeSelector> {
  // Eine Variable, die das aktuell angezeigte Widget im Body hält
  Widget _currentBody = const _InitialSelectionBody(); // Initialer Body-Inhalt

  // Ein Flag, um zu verfolgen, ob wir uns auf einer "Unterseite" befinden
  bool _isRecipePageActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe'), // Titel für die kombinierte Rezeptseite
        backgroundColor: Theme.of(context).colorScheme.primary, // AppBar Hintergrundfarbe
        foregroundColor: Colors.white, // AppBar Vordergrundfarbe (Text/Icons)
        // Zeigt einen Zurück-Pfeil, wenn eine Rezeptseite aktiv ist
        leading: _isRecipePageActive
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Wenn der Zurück-Pfeil gedrückt wird, setzen wir den Body zurück
            _setBody(const _InitialSelectionBody(), isRecipePage: false);
          },
        )
            : null, // Kein Zurück-Pfeil auf der Initialauswahlseite
      ),
      body: _currentBody, // Zeigt den aktuellen Body-Inhalt an
    );
  }

  // Hilfsmethode zum Umschalten des Body-Inhalts
  void _setBody(Widget newBody, {bool isRecipePage = false}) {
    setState(() {
      _currentBody = newBody;
      _isRecipePageActive = isRecipePage;
    });
  }
}

// Ein separates Widget für den initialen Button-Auswahlbildschirm
class _InitialSelectionBody extends StatelessWidget {
  const _InitialSelectionBody();

  @override
  Widget build(BuildContext context) {
    // Den State des Eltern-Widgets abrufen, um _setBody aufzurufen
    final _RecipeGenerationModeSelectorState parentState =
    context.findAncestorStateOfType<_RecipeGenerationModeSelectorState>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                parentState._setBody(const RecipePage(), isRecipePage: true); // Body zu RecipePage ändern
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'Chef Transformer T5',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                parentState._setBody(const Recipe2Page(), isRecipePage: true); // Body zu Recipe2Page ändern
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'Qwen2.5-VL-72B-Instruct',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}