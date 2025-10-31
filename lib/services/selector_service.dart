import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Service to manage selector configuration with remote update capability
class SelectorService {
  static const String _localAssetPath = 'assets/json/selectors.json';
  static const String _cacheKey = 'cached_selectors';
  
  // For MVP, we don't implement remote fetching yet
  // This can be added later with a maintenance URL
  // static const String _remoteUrl = 'https://example.com/selectors.json';
  
  final Dio _dio;
  
  SelectorService({Dio? dio}) : _dio = dio ?? Dio();
  
  /// Load selectors from local asset (fallback)
  Future<Map<String, dynamic>> loadLocalSelectors() async {
    try {
      final String jsonString = await rootBundle.loadString(_localAssetPath);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load local selectors: $e');
    }
  }
  
  /// Get selectors for a specific provider
  Future<Map<String, dynamic>> getSelectorsForProvider(String providerId) async {
    final selectors = await loadLocalSelectors();
    
    if (!selectors.containsKey(providerId)) {
      throw Exception('No selectors found for provider: $providerId');
    }
    
    return selectors[providerId] as Map<String, dynamic>;
  }
  
  /// Get all selectors
  Future<Map<String, dynamic>> getAllSelectors() async {
    return await loadLocalSelectors();
  }
  
  // Future enhancement: Remote selector update
  // Future<Map<String, dynamic>> fetchRemoteSelectors() async {
  //   try {
  //     final response = await _dio.get(_remoteUrl);
  //     if (response.statusCode == 200) {
  //       // Cache the response
  //       // await _cacheSelectors(response.data);
  //       return response.data as Map<String, dynamic>;
  //     }
  //     throw Exception('Failed to fetch remote selectors');
  //   } catch (e) {
  //     // Fallback to local
  //     return await loadLocalSelectors();
  //   }
  // }
}
