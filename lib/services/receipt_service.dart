import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) => ReceiptService());

class ReceiptService {
  // Using the provided API Key
  static const String _apiKey = 'AIzaSyCd4ttVJggytpLD4sboBeWAfmSALOQDG-g';

  final _model = GenerativeModel(
    model: 'gemini-2.5-flash', // Appending -latest can help with model resolution
    apiKey: _apiKey,
  );

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(source: source);
  }

  Future<Map<String, dynamic>?> analyzeReceipt(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      final prompt = 'Analyze this receipt image. Extract the total amount and the category of the expense. '
          'Provide the output in strict JSON format like this: {"amount": 120.50, "category": "Food 🍔"}. '
          'Use emojis in category names if possible to match existing patterns: '
          'Food 🍔, Travel ✈️, Shopping 🛍️, Bills 💡, Health 💊, Fuel ⛽, EMI/Loan 🏦, Emergency 🚨, Entertainment 🎬, Education 📚. '
          'If it doesn\'t fit these, suggest a new one with an emoji.';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;
      
      if (text != null) {
        // Find JSON block in the response to handle cases where Gemini adds conversational text
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(text);
        if (jsonMatch != null) {
          final decoded = jsonDecode(jsonMatch) as Map<String, dynamic>;
          // Ensure amount is a double
          if (decoded['amount'] is String) {
            decoded['amount'] = double.tryParse(decoded['amount']) ?? 0.0;
          } else if (decoded['amount'] is int) {
            decoded['amount'] = (decoded['amount'] as int).toDouble();
          }
          return decoded;
        }
      }
      return null;
    } catch (e) {
      print('Error analyzing receipt: $e');
      return null;
    }
  }
}
