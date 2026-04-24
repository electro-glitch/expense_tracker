import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) => ReceiptService());

class ReceiptService {
  static const String _apiKey = 'AIzaSyCd4ttVJggytpLD4sboBeWAfmSALOQDG-g';

  final _model = GenerativeModel(
    model: 'gemini-2.5-flash', // Appending -latest can help with model resolution
    apiKey: _apiKey,
  );

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(source: source);
  }

  /// Analyzes a receipt and returns a list of items grouped by category.
  /// Example return: [{"amount": 50.0, "category": "Food 🍔"}, {"amount": 20.0, "category": "Bills 💡"}]
  Future<List<Map<String, dynamic>>?> analyzeReceiptMulti(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      final prompt = 'Analyze this receipt image. It may contain items from different categories (e.g., groceries, electronics, food, etc.). '
          '1. Identify all items and their prices.\n'
          '2. Group these items into logical categories such as: Food 🍔, Travel ✈️, Shopping 🛍️, Bills 💡, Health 💊, Fuel ⛽, EMI/Loan 🏦, Emergency 🚨, Entertainment 🎬, Education 📚.\n'
          '3. If an item doesn\'t fit these, create a NEW specific category for it with a relevant emoji.\n'
          '4. Sum up the amounts for each category.\n'
          '5. Return ONLY a strict JSON array of objects, each containing "amount" (number) and "category" (string with emoji).\n'
          'Example format: [{"amount": 45.99, "category": "Groceries 🛒"}, {"amount": 15.50, "category": "Food 🍔"}]';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;
      
      if (text != null) {
        // More robust JSON extraction
        final jsonMatch = RegExp(r'\[.*\]', dotAll: true).stringMatch(text);
        if (jsonMatch != null) {
          final List<dynamic> decodedList = jsonDecode(jsonMatch);
          return decodedList.map((item) {
            double amount = 0.0;
            if (item['amount'] is num) {
              amount = (item['amount'] as num).toDouble();
            } else if (item['amount'] is String) {
              amount = double.tryParse(item['amount'].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            }
            return {
              'amount': amount,
              'category': item['category'] as String? ?? 'Other 📦',
            };
          }).toList();
        }
      }
      return null;
    } catch (e) {
      print('Error analyzing receipt: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeReceipt(XFile imageFile) async {
    final results = await analyzeReceiptMulti(imageFile);
    if (results != null && results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}
