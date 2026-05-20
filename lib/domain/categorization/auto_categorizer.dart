import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';

final autoCategorizerProvider = Provider<AutoCategorizer>((ref) {
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  return AutoCategorizer(categoryRepo);
});

class AutoCategorizerResult {
  final Category category;
  final double confidence; // 0.0 to 1.0

  const AutoCategorizerResult({
    required this.category,
    required this.confidence,
  });
}

class AutoCategorizer {
  final CategoryRepository _categoryRepository;

  AutoCategorizer(this._categoryRepository);

  /// Classifies a transaction's category based on details (description, type, senderOrRecipient).
  Future<AutoCategorizerResult> categorize({
    required String type, // income, expense, airtime, fee
    required String description,
    required String senderOrRecipient,
  }) async {
    // 1. Fetch all system and user categories to find the correct database reference
    final categories = await _categoryRepository.getCategories();
    final lowercaseText = '$description $senderOrRecipient'.toLowerCase();

    // Helper: finds the first category matching name (case-insensitive)
    Category? findCategoryByName(String name) {
      return categories.firstWhere(
        (cat) => cat.name.toLowerCase() == name.toLowerCase(),
        orElse: () => categories.firstWhere(
          (cat) => cat.name.toLowerCase() == 'other',
          orElse: () => categories.first,
        ),
      );
    }

    final otherCategory = findCategoryByName('Other');

    // 2. Exact match rules based on parsed types
    if (type == 'airtime') {
      final airtimeCat = findCategoryByName('Airtime');
      return AutoCategorizerResult(category: airtimeCat, confidence: 1.0);
    }

    if (type == 'fee') {
      final feeCat = findCategoryByName('Taxes'); // Map telco fees to system taxes/fees
      return AutoCategorizerResult(category: feeCat, confidence: 1.0);
    }

    // 3. Keyword categorization mapping
    // Map of keywords to standard seeded category names
    final keywordMap = {
      // Groceries / Shopping
      'supermarket': 'Food & Groceries',
      'shop': 'Food & Groceries',
      'duka': 'Food & Groceries',
      'shoppers': 'Food & Groceries',
      'quick mart': 'Food & Groceries',
      'soko': 'Food & Groceries',
      'mall': 'Shopping',
      'pos': 'Shopping',
      'merchant': 'Shopping',
      'kadi': 'Shopping',

      // Food & Dining
      'restaurant': 'Food & Groceries',
      'hotel': 'Food & Groceries',
      'mkahawa': 'Food & Groceries',
      'chakula': 'Food & Groceries',
      'food': 'Food & Groceries',
      'cafe': 'Food & Groceries',
      'coffee': 'Food & Groceries',
      'pizza': 'Food & Groceries',

      // Transport / Travel
      'petrol': 'Transport',
      'fuel': 'Transport',
      'stesheni': 'Transport',
      'nauli': 'Transport',
      'uber': 'Transport',
      'bolt': 'Transport',
      'taxify': 'Transport',
      'mwendokasi': 'Transport',
      'bas': 'Transport',
      'travel': 'Travel',
      'ndege': 'Travel',
      'flight': 'Travel',

      // Utilities / Rent
      'luku': 'Utilities',
      'tanesco': 'Utilities',
      'umeme': 'Utilities',
      'water': 'Utilities',
      'maji': 'Utilities',
      'dawasco': 'Utilities',
      'dawasa': 'Utilities',
      'dstv': 'Utilities',
      'azam': 'Utilities',
      'startimes': 'Utilities',
      'kodi': 'Rent',
      'rent': 'Rent',
      'pango': 'Rent',

      // Income / Work / Salary
      'salary': 'Salary',
      'mshahara': 'Salary',
      'bonus': 'Salary',
      'dividend': 'Salary',
      'ajira': 'Salary',
      'biashara': 'Business',
      'sales': 'Business',
      'dukani': 'Business',

      // Savings / Investments
      'savings': 'Savings',
      'akiba': 'Savings',
      'investment': 'Investment',
      'hisa': 'Investment',
      'utp': 'Investment',
    };

    // Scan lowercase combined text for these keywords
    for (final entry in keywordMap.entries) {
      if (lowercaseText.contains(entry.key)) {
        final cat = findCategoryByName(entry.value);
        return AutoCategorizerResult(category: cat, confidence: 0.95);
      }
    }

    // 4. Default classification: fallback to 'Other' with low confidence
    return AutoCategorizerResult(category: otherCategory, confidence: 0.50);
  }
}
