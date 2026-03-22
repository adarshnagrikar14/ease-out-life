import 'dart:convert';

class GroceryItem {
  final String id;
  final String name;
  final String quantity;
  final String category;
  final String forMealType;
  final String forDay;
  bool bought;

  GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
    required this.forMealType,
    required this.forDay,
    this.bought = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'category': category,
        'forMealType': forMealType,
        'forDay': forDay,
        'bought': bought,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> j) => GroceryItem(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as String? ?? '',
        category: j['category'] as String? ?? 'other',
        forMealType: j['forMealType'] as String? ?? 'all',
        forDay: j['forDay'] as String? ?? '',
        bought: j['bought'] as bool? ?? false,
      );
}

class WeeklyGroceryList {
  final String weekKey;
  final List<GroceryItem> items;

  WeeklyGroceryList({required this.weekKey, required this.items});

  Map<String, dynamic> toJson() => {
        'weekKey': weekKey,
        'items': items.map((i) => i.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory WeeklyGroceryList.fromJson(Map<String, dynamic> j) =>
      WeeklyGroceryList(
        weekKey: j['weekKey'] as String? ?? '',
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => GroceryItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  factory WeeklyGroceryList.decode(String data) =>
      WeeklyGroceryList.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
