import 'package:flutter/material.dart'; // Nur für DateTime falls nicht anderswo importiert
import 'package:equatable/equatable.dart'; // NEU: Importiere Equatable

class IngredientEntry extends Equatable {
  final String name;
  final DateTime dateAdded;
  final String category;
  final String unit;
  double quantity;

  IngredientEntry({
    required this.name,
    required this.dateAdded,
    required this.category,
    required this.unit,
    required this.quantity,
  });

  // NEU: Überschreibe props für Equatable
  @override
  List<Object?> get props => [name, dateAdded, category, unit, quantity];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateAdded': dateAdded.toIso8601String(),
      'category': category,
      'unit': unit,
      'quantity': quantity,
    };
  }

  factory IngredientEntry.fromJson(Map<String, dynamic> json) {
    return IngredientEntry(
      name: json['name'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      category: json['category'] as String? ?? 'Unknown',
      unit: json['unit'] as String? ?? 'piece', // Fallback zu 'piece'
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() {
    return 'IngredientEntry(name: $name, dateAdded: ${dateAdded.toIso8601String()}, category: $category, unit: $unit, quantity: $quantity)';
  }

  IngredientEntry copyWith({
    String? name,
    DateTime? dateAdded,
    String? category,
    String? unit,
    double? quantity,
  }) {
    return IngredientEntry(
      name: name ?? this.name,
      dateAdded: dateAdded ?? this.dateAdded,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
    );
  }
}