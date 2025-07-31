// File: widgets/ingredient_selector2.dart
import 'package:flutter/material.dart';

class IngredientSelector2 extends StatefulWidget {
  final Map<String, String?> vegetablesMap;
  final Map<String, String?> mainIngredientsMap;
  final Map<String, String?> spicesMap;
  final Map<String, String?> othersMap;
  final Set<String> requiredIngredients;
  final bool autoExpandIngredients;
  final Function(String) onToggleIngredient;
  final Function() onGenerateRecipe;
  final Function() onToggleAutoExpand;
  final Function() onResetRequiredIngredients;
  final Future<void> Function() onRefreshData;
  final String selectedCuisineStyle;
  final ValueChanged<String> onCuisineStyleChanged;
  final Set<String> selectedDietaryRestrictions;
  final ValueChanged<Set<String>> onDietaryRestrictionsChanged;

  const IngredientSelector2({
    super.key,
    required this.vegetablesMap,
    required this.mainIngredientsMap,
    required this.spicesMap,
    required this.othersMap,
    required this.requiredIngredients,
    required this.autoExpandIngredients,
    required this.onToggleIngredient,
    required this.onGenerateRecipe,
    required this.onToggleAutoExpand,
    required this.onResetRequiredIngredients,
    required this.onRefreshData,
    required this.selectedCuisineStyle,
    required this.onCuisineStyleChanged,
    required this.selectedDietaryRestrictions,
    required this.onDietaryRestrictionsChanged,
  });

  @override
  State<IngredientSelector2> createState() => _IngredientSelector2State();
}

class _IngredientSelector2State extends State<IngredientSelector2>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // Dietary restriction options
  final List<String> _dietaryRestrictionOptions = [
    'none',
    'vegetarian',
    'vegan',
    'gluten-free',
    'dairy-free',
    'nut-free',
  ];

  bool get _hasIngredients {
    return widget.vegetablesMap.isNotEmpty ||
        widget.mainIngredientsMap.isNotEmpty ||
        widget.spicesMap.isNotEmpty ||
        widget.othersMap.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_hasIngredients) {
      return const Center(child: Text("Keine Zutaten im Inventar gefunden."));
    }

    return RefreshIndicator(
      onRefresh: widget.onRefreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-expand toggle card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.autoExpandIngredients ? Icons.smart_toy : Icons.apps,
                      color: widget.autoExpandIngredients ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automatically add ingredients',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: widget.autoExpandIngredients ? Colors.blue : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.autoExpandIngredients
                                ? 'Adds extra ingredients from your inventory'
                                : 'Adds extra ingredients from your inventory',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.autoExpandIngredients,
                      onChanged: (value) => widget.onToggleAutoExpand(),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cuisine and Dietary Restrictions Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipe settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cuisine Style
                    Row(
                      children: [
                        Icon(Icons.restaurant, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        const Text('Cuisine style:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            value: widget.selectedCuisineStyle,
                            isExpanded: true,
                            underline: Container(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                widget.onCuisineStyleChanged(newValue);
                              }
                            },
                            items: <String>['any', 'italian', 'mexican', 'asian', 'indian', 'mediterranean', 'american', 'french']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value.capitalize(), style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dietary Restrictions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        const Text('Diet:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: _dietaryRestrictionOptions.map((restriction) {
                        final isSelected = widget.selectedDietaryRestrictions.contains(restriction);
                        return FilterChip(
                          label: Text(
                            restriction.capitalize(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.orange,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            Set<String> updatedRestrictions = Set.from(widget.selectedDietaryRestrictions);
                            if (restriction == 'none') {
                              updatedRestrictions = {'none'};
                            } else {
                              updatedRestrictions.remove('none');
                              if (selected) {
                                updatedRestrictions.add(restriction);
                              } else {
                                updatedRestrictions.remove(restriction);
                              }
                              if (updatedRestrictions.isEmpty) {
                                updatedRestrictions.add('none');
                              }
                            }
                            widget.onDietaryRestrictionsChanged(updatedRestrictions);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Generate Recipe Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onGenerateRecipe,
                icon: const Icon(Icons.restaurant),
                label: const Text(
                  "Generate Recipe",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ingredient selection header
            Row(
              children: [
                Text(
                  "Selected ingredients (${widget.requiredIngredients.length})",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),

            // Ingredient categories
            _buildIngredientCategory(context, "Main ingredients", widget.mainIngredientsMap, widget.requiredIngredients, widget.onToggleIngredient),
            _buildIngredientCategory(context, "Vegetables", widget.vegetablesMap, widget.requiredIngredients, widget.onToggleIngredient),
            _buildIngredientCategory(context, "Spices", widget.spicesMap, widget.requiredIngredients, widget.onToggleIngredient),
            _buildIngredientCategory(context, "Others", widget.othersMap, widget.requiredIngredients, widget.onToggleIngredient),
            const SizedBox(height: 48), // Extra padding at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCategory(BuildContext context, String name, Map<String, String?> map, Set<String> selected, Function(String) onToggle) {
    if (map.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.green,
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: map.keys.map((ingredient) {
              final isSelected = selected.contains(ingredient);
              final oldestDate = map[ingredient];

              String labelText = ingredient;
              if (oldestDate != null && oldestDate.isNotEmpty) {
                labelText += ' ($oldestDate)';
              }

              return FilterChip(
                label: Text(labelText),
                selected: isSelected,
                onSelected: (_) => onToggle(ingredient),
                selectedColor: Theme.of(context).primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}