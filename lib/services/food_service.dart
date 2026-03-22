import 'dart:typed_data';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../models/meal_model.dart';
import 'gemini_service.dart';

class FoodService {
  final GeminiService _gemini = GeminiService();

  FoodService() {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'EaseOutLife',
      version: '1.0.0',
      url: 'https://github.com/easeoutlife',
    );
    OpenFoodAPIConfiguration.globalLanguages = [
      OpenFoodFactsLanguage.ENGLISH,
    ];
    OpenFoodAPIConfiguration.globalCountry = OpenFoodFactsCountry.INDIA;
  }

  /// Search Open Food Facts by dish name.
  /// Returns a list of matching [MealEntry] candidates (max 5).
  Future<List<MealEntry>> searchFood(String query) async {
    final params = ProductSearchQueryConfiguration(
      parametersList: [
        SearchTerms(terms: [query]),
        const SortBy(option: SortOption.POPULARITY),
        const PageSize(size: 5),
      ],
      fields: [
        ProductField.BARCODE,
        ProductField.NAME,
        ProductField.NUTRIMENTS,
        ProductField.SERVING_SIZE,
        ProductField.IMAGE_FRONT_SMALL_URL,
      ],
      version: ProductQueryVersion.v3,
    );

    final result = await OpenFoodAPIClient.searchProducts(null, params);
    if (result.products == null || result.products!.isEmpty) return [];

    return result.products!
        .where((p) => p.nutriments != null)
        .map((p) => _productToMeal(p))
        .toList();
  }

  MealEntry _productToMeal(Product product) {
    final n = product.nutriments!;
    return MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: product.productName ?? 'Unknown product',
      mealType: 'snack',
      calories: n.getValue(Nutrient.energyKCal, PerSize.serving) ??
          n.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams) ??
          0,
      protein: n.getValue(Nutrient.proteins, PerSize.serving) ??
          n.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ??
          0,
      carbs: n.getValue(Nutrient.carbohydrates, PerSize.serving) ??
          n.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ??
          0,
      fat: n.getValue(Nutrient.fat, PerSize.serving) ??
          n.getValue(Nutrient.fat, PerSize.oneHundredGrams) ??
          0,
      fiber: n.getValue(Nutrient.fiber, PerSize.serving) ??
          n.getValue(Nutrient.fiber, PerSize.oneHundredGrams) ??
          0,
      sugar: n.getValue(Nutrient.sugars, PerSize.serving) ??
          n.getValue(Nutrient.sugars, PerSize.oneHundredGrams) ??
          0,
      sodium: (n.getValue(Nutrient.sodium, PerSize.serving) ??
              n.getValue(Nutrient.sodium, PerSize.oneHundredGrams) ??
              0) *
          1000,
      servingSize: product.servingSize ?? '100g',
      source: 'openfoodfacts',
      timestamp: DateTime.now(),
    );
  }

  /// Primary entry point for manual dish analysis.
  /// Tries Open Food Facts first, falls back to Gemini for homemade/Indian dishes.
  Future<MealEntry> analyzeMeal(String dishName, String mealType) async {
    try {
      final offResults = await searchFood(dishName);
      if (offResults.isNotEmpty) {
        final best = offResults.first;
        return MealEntry(
          id: best.id,
          name: best.name,
          mealType: mealType,
          calories: best.calories,
          protein: best.protein,
          carbs: best.carbs,
          fat: best.fat,
          fiber: best.fiber,
          sugar: best.sugar,
          sodium: best.sodium,
          servingSize: best.servingSize,
          source: 'openfoodfacts',
          timestamp: DateTime.now(),
        );
      }
    } catch (_) {
      // OFF search failed, fall through to Gemini
    }

    return _gemini.analyzeMealByName(dishName, mealType);
  }

  /// Photo-based analysis (Gemini Vision — OFF doesn't support image recognition).
  Future<MealEntry> analyzePhoto(
      Uint8List imageBytes, String mimeType, String mealType) {
    return _gemini.analyzeMealByPhoto(imageBytes, mimeType, mealType);
  }
}
