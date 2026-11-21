import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/daos/transaction_dao.dart';
import '../../../data/database/database_providers.dart';
import '../../../data/repositories/category_repository.dart';

final autoCategorizerProvider = Provider<AutoCategorizer>((ref) {
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  return AutoCategorizer(categoryRepo, transactionDao);
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
  final TransactionDao _transactionDao;

  AutoCategorizer(this._categoryRepository, this._transactionDao);

  /// Classifies a transaction's category based on details (description, type, senderOrRecipient).
  Future<AutoCategorizerResult> categorize({
    required String type, // income, expense, airtime, fee
    required String description,
    required String senderOrRecipient,
  }) async {
    // 1. Fetch all system and user categories to find the correct database reference
    final categories = await _categoryRepository.getCategories();
    if (categories.isEmpty) {
      throw StateError('No categories available for auto-categorization');
    }
    final lowercaseText = '$description $senderOrRecipient'.toLowerCase();

    Category getCategoryByName(String name) {
      return categories.firstWhere(
        (cat) => cat.name.toLowerCase() == name.toLowerCase(),
        orElse: () => categories.firstWhere(
          (cat) => cat.name.toLowerCase() == 'other',
          orElse: () => categories.first,
        ),
      );
    }

    final otherCategory = getCategoryByName('Other');

    // 1.5 Dynamic categorization learning from transaction history
    // Requires 2+ consistent matches before applying high confidence.
    try {
      final recentCategoryIds = await _transactionDao
          .findRecentCategoriesForDescription(description, senderOrRecipient);
      if (recentCategoryIds.isNotEmpty) {
        final freq = <String, int>{};
        for (final id in recentCategoryIds) {
          freq[id] = (freq[id] ?? 0) + 1;
        }
        final mostCommon = freq.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        final matchedCategory = categories.firstWhere(
          (cat) => cat.id == mostCommon.key,
          orElse: () => otherCategory,
        );
        if (matchedCategory.id != otherCategory.id) {
          final confidence = mostCommon.value >= 2 ? 0.99 : 0.85;
          return AutoCategorizerResult(
            category: matchedCategory,
            confidence: confidence,
          );
        }
      }
    } catch (e) {
      developer.log(
        'Auto-categorization query failed: $e',
        name: 'AutoCategorizer',
      );
    }

    // 2. Exact match rules based on parsed types
    if (type == 'airtime') {
      final airtimeCat = getCategoryByName('Airtime & Data');
      return AutoCategorizerResult(category: airtimeCat, confidence: 1.0);
    }

    if (type == 'fee') {
      final feeCat = getCategoryByName('Bank Fees');
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

      // Food & Dining
      'restaurant': 'Food & Groceries',
      'hoteli ya chakula': 'Food & Groceries',
      'mkahawa': 'Food & Groceries',
      'chakula': 'Food & Groceries',
      'pizza': 'Food & Groceries',

      // Transport / Commute
      'stesheni': 'Transport',
      'nauli': 'Transport',
      'daladala': 'Transport',
      'uber': 'Transport',
      'bolt': 'Transport',
      'taxify': 'Transport',
      'mwendokasi': 'Transport',
      'ndege': 'Transport',

      // Utilities / Rent
      'luku': 'Utilities',
      'tanesco': 'Utilities',
      'umeme': 'Utilities',
      'water': 'Utilities',
      'maji': 'Utilities',
      'dawasco': 'Utilities',
      'dawasa': 'Utilities',
      'dstv': 'Utilities',
      'azam marine': 'Transport',
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

      // Savings
      'savings': 'Savings',
      'akiba': 'Savings',

      // Investments
      'investment': 'Investments',
      'investments': 'Investments',
      'hisa': 'Investments',
      'stock': 'Investments',
      'bond': 'Investments',
      'mutual fund': 'Investments',
      'dividends': 'Investments',
      'uwekezaji': 'Investments',
      'dse': 'Investments',
      'utt': 'Investments',

      // Fines & Violations (mapped to Other)
      'traffic fine': 'Other',
      'tms': 'Other',
      'faini': 'Other',
      'fine': 'Other',
      'penalty': 'Other',
      'adhabu': 'Other',

      // Emergencies (mapped to Health)
      'emergency': 'Health',
      'emergencies': 'Health',
      'dharura': 'Health',
      'ambulance': 'Health',
      'rescue': 'Health',
      'first aid': 'Health',
      'polisi': 'Other',
      'police': 'Other',
      'ajali': 'Health',

      // Charity & Offerings
      'sadaka': 'Charity & Offerings',
      'zaka': 'Charity & Offerings',
      'tithe': 'Charity & Offerings',
      'offering': 'Charity & Offerings',
      'offerings': 'Charity & Offerings',
      'kanisa': 'Charity & Offerings',
      'church': 'Charity & Offerings',
      'msikiti': 'Charity & Offerings',
      'mosque': 'Charity & Offerings',
      'donation': 'Charity & Offerings',
      'donations': 'Charity & Offerings',
      'charity': 'Charity & Offerings',
      'harambee': 'Charity & Offerings',
      'msaada': 'Charity & Offerings',

      // Contributions & Michango
      'mchango': 'Contributions & Michango',
      'michango': 'Contributions & Michango',
      'harusi': 'Contributions & Michango',
      'wedding': 'Contributions & Michango',
      'msiba': 'Contributions & Michango',
      'funeral': 'Contributions & Michango',
      'sendoff': 'Contributions & Michango',
      'send off': 'Contributions & Michango',
      'kitchen party': 'Contributions & Michango',
      'kikoba': 'Contributions & Michango',
      'upatu': 'Contributions & Michango',

      // Personal Care
      'saluni': 'Personal Care',
      'salon': 'Personal Care',
      'kinyozi': 'Personal Care',
      'barber': 'Personal Care',
      'cosmetics': 'Personal Care',
      'spa': 'Personal Care',
      'massage': 'Personal Care',
      'haircut': 'Personal Care',
      'beauty': 'Personal Care',
      'dobi': 'Personal Care',
      'laundry': 'Personal Care',

      // Family Support
      'wazazi': 'Family Support',
      'familia': 'Family Support',
      'family support': 'Family Support',
      'child support': 'Family Support',
      'upendo': 'Family Support',

      // Home & Maintenance (mapped to Utilities)
      'fundi': 'Utilities',
      'hardware': 'Utilities',
      'repairs': 'Utilities',
      'maintenance': 'Utilities',
      'ujenzi': 'Utilities',
      'plumber': 'Utilities',
      'electrician': 'Utilities',
      'furniture': 'Utilities',
      'carpenter': 'Utilities',
      'appliance': 'Utilities',

      // Insurance & Taxes (health insurance -> Health; taxes/fees -> Other)
      'bima': 'Health',
      'insurance': 'Health',
      'nhif': 'Health',
      'sanlam': 'Health',
      'jubilee': 'Health',
      'tra': 'Other',
      'tax': 'Other',
      'revenue': 'Other',
      'leseni': 'Other',
      'license': 'Other',

      // Subscriptions & Streaming (mapped to Entertainment)
      'netflix': 'Entertainment',
      'spotify': 'Entertainment',
      'showmax': 'Entertainment',
      'apple music': 'Entertainment',
      'google play': 'Entertainment',
      'youtube': 'Entertainment',

      // Vehicle & Fuel (mapped to Transport)
      'petrol': 'Transport',
      'diesel': 'Transport',
      'fuel': 'Transport',
      'totalenergies': 'Transport',
      'puma energy': 'Transport',
      'oilcom': 'Transport',
      'shell': 'Transport',
      'gapco': 'Transport',
      'camel oil': 'Transport',
      'car wash': 'Transport',
      'kuosha gari': 'Transport',
      'garage': 'Transport',
      'mechanic': 'Transport',
      'spare parts': 'Transport',
      'parking': 'Transport',
      'oil change': 'Transport',

      // Travel & Vacations (mapped to Transport)
      'hotel': 'Transport',
      'lodge': 'Transport',
      'resort': 'Transport',
      'airbnb': 'Transport',
      'vacation': 'Transport',
      'safari': 'Transport',
      'utalii': 'Transport',
      'ferry': 'Transport',
      'booking.com': 'Transport',
      'holiday': 'Transport',
      'zanzibar': 'Transport',
      'serengeti': 'Transport',

      // Fitness & Sports (mapped to Health)
      'gym': 'Health',
      'fitness': 'Health',
      'workout': 'Health',
      'football': 'Health',
      'mpira': 'Health',
      'aerobics': 'Health',
      'swimming': 'Health',
      'crossfit': 'Health',
      'sports': 'Health',
      'uwanja': 'Health',

      // Children & Baby (mapped to Family Support)
      'pampers': 'Family Support',
      'diapers': 'Family Support',
      'daycare': 'Family Support',
      'nanny': 'Family Support',
      'housegirl': 'Family Support',
      'dada wa kazi': 'Family Support',
      'baby': 'Family Support',
      'mtoto': 'Family Support',
      'watoto': 'Family Support',
      'toys': 'Family Support',
      'nursery': 'Family Support',

      // Gifts & Celebrations (mapped to Contributions & Michango)
      'zawadi': 'Contributions & Michango',
      'gift': 'Contributions & Michango',
      'birthday': 'Contributions & Michango',
      'anniversary': 'Contributions & Michango',
      'valentine': 'Contributions & Michango',
      'flowers': 'Contributions & Michango',
      'sikukuu': 'Contributions & Michango',
      'christmas': 'Contributions & Michango',
      'eid': 'Contributions & Michango',
      'krismasi': 'Contributions & Michango',
      'sherehe': 'Contributions & Michango',

      // Electronics & Tech (mapped to Shopping)
      'smartphone': 'Shopping',
      'iphone': 'Shopping',
      'samsung': 'Shopping',
      'laptop': 'Shopping',
      'charger': 'Shopping',
      'earbuds': 'Shopping',
      'headphones': 'Shopping',
      'gadget': 'Shopping',
      'computer': 'Shopping',
      'gaming': 'Shopping',
      'playstation': 'Shopping',
      'airpods': 'Shopping',

      // Pets & Animals (mapped to Other)
      'pet': 'Other',
      'pets': 'Other',
      'vet': 'Other',
      'veterinary': 'Other',
      'mbwa': 'Other',
      'paka': 'Other',
      'dawa ya mifugo': 'Other',
      'pet food': 'Other',
      'mifugo': 'Other',

      // Legal & Professional (mapped to Other)
      'mwanasheria': 'Other',
      'lawyer': 'Other',
      'wakili': 'Other',
      'advocate': 'Other',
      'notary': 'Other',
      'consultant': 'Other',
      'legal': 'Other',
      'audit': 'Other',
      'court': 'Other',
      'hakimu': 'Other',
      'affidavit': 'Other',

      // Hobbies & Recreation (mapped to Entertainment)
      'camera': 'Entertainment',
      'photography': 'Entertainment',
      'art': 'Entertainment',
      'craft': 'Entertainment',
      'canvas': 'Entertainment',
      'guitar': 'Entertainment',
      'piano': 'Entertainment',
      'hobby': 'Entertainment',
      'picha': 'Entertainment',
      'studio': 'Entertainment',

      // Generic Subscriptions fallback (mapped to Entertainment)
      'subscription': 'Entertainment',
      'subscriptions': 'Entertainment',
    };

    // Scan lowercase combined text for these keywords
    for (final entry in keywordMap.entries) {
      if (lowercaseText.contains(entry.key)) {
        final cat = getCategoryByName(entry.value);
        return AutoCategorizerResult(category: cat, confidence: 0.95);
      }
    }

    // 4. Default classification: fallback to 'Other' with low confidence
    return AutoCategorizerResult(category: otherCategory, confidence: 0.50);
  }
}
