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
      'azam marine': 'Travel & Vacations',
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

      // Fines & Penalties
      'traffic fine': 'Fines & Penalties',
      'tms': 'Fines & Penalties',
      'faini': 'Fines & Penalties',
      'fine': 'Fines & Penalties',
      'penalty': 'Fines & Penalties',
      'adhabu': 'Fines & Penalties',

      // Emergencies
      'emergency': 'Emergencies',
      'emergencies': 'Emergencies',
      'dharura': 'Emergencies',
      'ambulance': 'Emergencies',
      'rescue': 'Emergencies',
      'first aid': 'Emergencies',
      'polisi': 'Emergencies',
      'police': 'Emergencies',
      'ajali': 'Emergencies',

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

      // Home & Maintenance
      'fundi': 'Home & Maintenance',
      'hardware': 'Home & Maintenance',
      'repairs': 'Home & Maintenance',
      'maintenance': 'Home & Maintenance',
      'ujenzi': 'Home & Maintenance',
      'plumber': 'Home & Maintenance',
      'electrician': 'Home & Maintenance',
      'furniture': 'Home & Maintenance',
      'carpenter': 'Home & Maintenance',
      'appliance': 'Home & Maintenance',

      // Insurance & Taxes
      'bima': 'Insurance & Taxes',
      'insurance': 'Insurance & Taxes',
      'nhif': 'Insurance & Taxes',
      'sanlam': 'Insurance & Taxes',
      'jubilee': 'Insurance & Taxes',
      'tra': 'Insurance & Taxes',
      'tax': 'Insurance & Taxes',
      'revenue': 'Insurance & Taxes',
      'leseni': 'Insurance & Taxes',
      'license': 'Insurance & Taxes',

      // Subscriptions & Streaming
      'netflix': 'Subscriptions & Streaming',
      'spotify': 'Subscriptions & Streaming',
      'showmax': 'Subscriptions & Streaming',
      'apple music': 'Subscriptions & Streaming',
      'google play': 'Subscriptions & Streaming',
      'youtube': 'Subscriptions & Streaming',

      // Vehicle & Fuel
      'petrol': 'Vehicle & Fuel',
      'diesel': 'Vehicle & Fuel',
      'fuel': 'Vehicle & Fuel',
      'totalenergies': 'Vehicle & Fuel',
      'puma energy': 'Vehicle & Fuel',
      'oilcom': 'Vehicle & Fuel',
      'shell': 'Vehicle & Fuel',
      'gapco': 'Vehicle & Fuel',
      'camel oil': 'Vehicle & Fuel',
      'car wash': 'Vehicle & Fuel',
      'kuosha gari': 'Vehicle & Fuel',
      'garage': 'Vehicle & Fuel',
      'mechanic': 'Vehicle & Fuel',
      'spare parts': 'Vehicle & Fuel',
      'parking': 'Vehicle & Fuel',
      'oil change': 'Vehicle & Fuel',

      // Travel & Vacations
      'hotel': 'Travel & Vacations',
      'lodge': 'Travel & Vacations',
      'resort': 'Travel & Vacations',
      'airbnb': 'Travel & Vacations',
      'vacation': 'Travel & Vacations',
      'safari': 'Travel & Vacations',
      'utalii': 'Travel & Vacations',
      'ferry': 'Travel & Vacations',
      'booking.com': 'Travel & Vacations',
      'holiday': 'Travel & Vacations',
      'zanzibar': 'Travel & Vacations',
      'serengeti': 'Travel & Vacations',

      // Fitness & Sports
      'gym': 'Fitness & Sports',
      'fitness': 'Fitness & Sports',
      'workout': 'Fitness & Sports',
      'football': 'Fitness & Sports',
      'mpira': 'Fitness & Sports',
      'aerobics': 'Fitness & Sports',
      'swimming': 'Fitness & Sports',
      'crossfit': 'Fitness & Sports',
      'sports': 'Fitness & Sports',
      'uwanja': 'Fitness & Sports',

      // Children & Baby
      'pampers': 'Children & Baby',
      'diapers': 'Children & Baby',
      'daycare': 'Children & Baby',
      'nanny': 'Children & Baby',
      'housegirl': 'Children & Baby',
      'dada wa kazi': 'Children & Baby',
      'baby': 'Children & Baby',
      'mtoto': 'Children & Baby',
      'watoto': 'Children & Baby',
      'toys': 'Children & Baby',
      'nursery': 'Children & Baby',

      // Gifts & Celebrations
      'zawadi': 'Gifts & Celebrations',
      'gift': 'Gifts & Celebrations',
      'birthday': 'Gifts & Celebrations',
      'anniversary': 'Gifts & Celebrations',
      'valentine': 'Gifts & Celebrations',
      'flowers': 'Gifts & Celebrations',
      'sikukuu': 'Gifts & Celebrations',
      'christmas': 'Gifts & Celebrations',
      'eid': 'Gifts & Celebrations',
      'krismasi': 'Gifts & Celebrations',
      'sherehe': 'Gifts & Celebrations',

      // Electronics & Tech
      'smartphone': 'Electronics & Tech',
      'iphone': 'Electronics & Tech',
      'samsung': 'Electronics & Tech',
      'laptop': 'Electronics & Tech',
      'charger': 'Electronics & Tech',
      'earbuds': 'Electronics & Tech',
      'headphones': 'Electronics & Tech',
      'gadget': 'Electronics & Tech',
      'computer': 'Electronics & Tech',
      'gaming': 'Electronics & Tech',
      'playstation': 'Electronics & Tech',
      'airpods': 'Electronics & Tech',

      // Pets & Animals
      'pet': 'Pets & Animals',
      'pets': 'Pets & Animals',
      'vet': 'Pets & Animals',
      'veterinary': 'Pets & Animals',
      'mbwa': 'Pets & Animals',
      'paka': 'Pets & Animals',
      'dawa ya mifugo': 'Pets & Animals',
      'pet food': 'Pets & Animals',
      'mifugo': 'Pets & Animals',

      // Legal & Professional
      'mwanasheria': 'Legal & Professional',
      'lawyer': 'Legal & Professional',
      'wakili': 'Legal & Professional',
      'advocate': 'Legal & Professional',
      'notary': 'Legal & Professional',
      'consultant': 'Legal & Professional',
      'legal': 'Legal & Professional',
      'audit': 'Legal & Professional',
      'court': 'Legal & Professional',
      'hakimu': 'Legal & Professional',
      'affidavit': 'Legal & Professional',

      // Hobbies & Recreation
      'camera': 'Hobbies & Recreation',
      'photography': 'Hobbies & Recreation',
      'art': 'Hobbies & Recreation',
      'craft': 'Hobbies & Recreation',
      'canvas': 'Hobbies & Recreation',
      'guitar': 'Hobbies & Recreation',
      'piano': 'Hobbies & Recreation',
      'hobby': 'Hobbies & Recreation',
      'picha': 'Hobbies & Recreation',
      'studio': 'Hobbies & Recreation',

      // Generic Subscriptions fallback
      'subscription': 'Subscriptions & Streaming',
      'subscriptions': 'Subscriptions & Streaming',
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
