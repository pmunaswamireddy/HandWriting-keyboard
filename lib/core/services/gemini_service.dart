import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class GeminiService {
  final String _apiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  GeminiService(this._apiKey);

  Future<List<String>> getKeyboardSuggestions(String currentText) async {
    if (currentText.trim().isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'You are a predictive text keyboard. The user has typed: "$currentText". Predict the next 3 most likely words they will type. Respond ONLY with a JSON array of 3 strings. Example: ["the", "a", "is"]'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content']['parts'][0]['text'] as String;
          final jsonStr = content.replaceAll('```json', '').replaceAll('```', '').trim();
          final List<dynamic> words = jsonDecode(jsonStr);
          return words.map((e) => e.toString()).toList();
        }
      } else {
        print('Gemini API Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception calling Gemini: $e');
    }
    return [];
  }

  Future<Map<String, String>> recognizeHandwritingImage(List<int> imageBytes, String mimeType) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'This image contains a grid of handwritten letters and symbols. Identify each distinct character reading from left to right, top to bottom. Return ONLY a JSON object where the keys are the characters found (like "a", "b", "A", "/") and the values are their approximate relative bounding boxes in format "x,y,w,h" (values 0.0 to 1.0). If multiple of the same character exist, only keep one. Example: {"A":"0.1,0.1,0.2,0.2","b":"0.3,0.1,0.2,0.2"}'
                },
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content']['parts'][0]['text'] as String;
          final jsonStr = content.replaceAll('```json', '').replaceAll('```', '').trim();
          final Map<String, dynamic> result = jsonDecode(jsonStr);
          return result.map((key, value) => MapEntry(key, value.toString()));
        }
      } else {
        print('Gemini API Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Exception calling Gemini image recognition: $e');
    }
    return {};
  }
}

final geminiServiceProvider = Provider((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  return GeminiService(apiKey);
});
