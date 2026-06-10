import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stickerServiceProvider = Provider((ref) => StickerService());

class StickerService {
  // Free test API key for Giphy. In production, use a secure backend.
  static const String _apiKey = 'pLURtkhVrGQm3MWEVu02mQNEwKDE6Q5k';
  static const String _baseUrl = 'https://api.giphy.com/v1/stickers';

  Future<List<String>> getTrendingStickers({int limit = 20}) async {
    // Return mock GIF stickers since Giphy API key requires registration
    return [
      'https://media.giphy.com/media/3o7aD2saalEvTehEXe/giphy.gif',
      'https://media.giphy.com/media/l41lFw057lAJQMwg0/giphy.gif',
      'https://media.giphy.com/media/11sBLVxNs7v6WA/giphy.gif',
      'https://media.giphy.com/media/26AHONQ79FdWZhAI0/giphy.gif',
      'https://media.giphy.com/media/d2lcHJTG5Tscg/giphy.gif',
      'https://media.giphy.com/media/3o7TKSjRrfIPjeiVyM/giphy.gif',
      'https://media.giphy.com/media/ICOgUNjpvO0PC/giphy.gif',
      'https://media.giphy.com/media/3o6Zt481isNVuQI1l6/giphy.gif',
    ];
  }

  Future<List<String>> searchStickers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return getTrendingStickers(limit: limit);

    // Mock search results
    return [
      'https://media.giphy.com/media/5GoVLqeAOo6PK/giphy.gif',
      'https://media.giphy.com/media/3nt2cUgUIBqAE/giphy.gif',
      'https://media.giphy.com/media/vFKqnCdLPNOKc/giphy.gif',
      'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif',
    ];
  }
}
