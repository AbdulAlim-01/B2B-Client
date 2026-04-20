import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase Configuration - Add your values here
const String supabase_url = "";
const String supabase_anonkey = "";

// Model classes for type safety
class BusinessResult {
  final String thumbnail;
  final String title;
  final String address;
  final String phone;
  final String type;
  final double rating;
  final int reviews;
  final String reviewsOriginal;
  final String description;
  final String hours;

  BusinessResult({
    required this.thumbnail,
    required this.title,
    required this.address,
    required this.phone,
    required this.type,
    required this.rating,
    required this.reviews,
    required this.reviewsOriginal,
    required this.description,
    required this.hours,
  });

  factory BusinessResult.fromJson(Map<String, dynamic> json) {
    return BusinessResult(
      thumbnail: json['thumbnail'] ?? '',
      title: json['title'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      type: json['type'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      reviews: json['reviews'] ?? 0,
      reviewsOriginal: json['reviews_original'] ?? '',
      description: json['description'] ?? '',
      hours: json['hours'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thumbnail': thumbnail,
      'title': title,
      'address': address,
      'phone': phone,
      'type': type,
      'rating': rating,
      'reviews': reviews,
      'reviews_original': reviewsOriginal,
      'description': description,
      'hours': hours,
    };
  }
}

class SearchCustomersResponse {
  final bool success;
  final String? query;
  final List<String>? keywords;
  final int? totalBusinessesFound;
  final Map<String, List<BusinessResult>>? businessesByKeyword;
  final List<BusinessResult>? allBusinesses;
  final String? error;

  SearchCustomersResponse({
    required this.success,
    this.query,
    this.keywords,
    this.totalBusinessesFound,
    this.businessesByKeyword,
    this.allBusinesses,
    this.error,
  });

  factory SearchCustomersResponse.fromJson(Map<String, dynamic> json) {
    Map<String, List<BusinessResult>>? businessesByKeyword;
    List<BusinessResult>? allBusinesses;

    if (json['businessesByKeyword'] != null) {
      businessesByKeyword = {};
      json['businessesByKeyword'].forEach((key, value) {
        businessesByKeyword![key] = (value as List)
            .map((business) => BusinessResult.fromJson(business))
            .toList();
      });
    }

    if (json['allBusinesses'] != null) {
      allBusinesses = (json['allBusinesses'] as List)
          .map((business) => BusinessResult.fromJson(business))
          .toList();
    }

    return SearchCustomersResponse(
      success: json['success'] ?? false,
      query: json['query'],
      keywords: json['keywords']?.cast<String>(),
      totalBusinessesFound: json['totalBusinessesFound'],
      businessesByKeyword: businessesByKeyword,
      allBusinesses: allBusinesses,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> businessesByKeywordJson = {};
    businessesByKeyword?.forEach((key, value) {
      businessesByKeywordJson[key] = value.map((business) => business.toJson()).toList();
    });

    return {
      'success': success,
      if (query != null) 'query': query,
      if (keywords != null) 'keywords': keywords,
      if (totalBusinessesFound != null) 'totalBusinessesFound': totalBusinessesFound,
      if (businessesByKeyword != null) 'businessesByKeyword': businessesByKeywordJson,
      if (allBusinesses != null) 'allBusinesses': allBusinesses!.map((business) => business.toJson()).toList(),
      if (error != null) 'error': error,
    };
  }
}

// Main Business Coach Service Class
class BusinessCoachService {
  BusinessCoachService();

  final _supabase = Supabase.instance.client;
 
  Future<SearchCustomersResponse> searchCustomersLocal({
    required String businessDescription,
    String location = 'India',
    int keyword = 1,
  }) async {
    try {
      print('Invoking Supabase function for: $businessDescription');

      // Using direct http call to bypass potential JWT algorithm issues with the SDK's automatic session handling
      // The function is public anyway as it handles its own logic.
      final response = await http.post(
        Uri.parse('https://$supabase_url.supabase.co/functions/v1/hyper-api'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabase_anonkey',
        },
        body: jsonEncode({
          'businessDescription': businessDescription,
          'keywordCount': keyword,
          'location': location,
        }),
      );

      

      if (response.statusCode != 200) {
        throw Exception('Function returned error status: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return SearchCustomersResponse.fromJson(data);

    } catch (e) {
      print('Error invoking Supabase function: $e');
      return SearchCustomersResponse(
        success: false,
        error: e.toString(),
        query: businessDescription,
      );
    }
  }
}
