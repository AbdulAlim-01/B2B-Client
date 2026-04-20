import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<Map?> getBusinessProfile(String userId) async {
    final res = await supabase
        .from('business_profiles')
        .select()
        .eq('user_id', userId)
        .single();
    return res;
  }

  Future<void> createBusinessProfile(
      String userId, String name, String description, String aiMessage, List keywords, int initialLeads,String? type) async {
    await supabase.from('business_profiles').insert({
      'user_id': userId,
      'business_name': name,
      'description': description,
      'ai_message': aiMessage,
      'keywords': jsonEncode(keywords),
      'leads_remaining': initialLeads,
      'type': type,
    });
  }

  Future<void> updateBusinessProfile(
      String userId,
      String name,
      String description,
      String aiMessage,
      String? type) async {
    await supabase.from('business_profiles').update({
      'business_name': name,
      'description': description,
      'ai_message': aiMessage,
      'type': type,
    }).eq('user_id',userId);
  }

  Future<void> updateLeadsRemaining(String profileId, int newCount) async {
    await supabase.from('business_profiles').update({
      'leads_remaining': newCount,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', profileId);
  }

  Future<List<Map<String, dynamic>>> getExistingLeads(String userId, String profileId) async {
  try {
    final response = await supabase
        .from('leads') // Replace with your actual table name
        .select('phone')
        .eq('user_id', userId)
        .eq('profile_id', profileId);
    
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    print('Error fetching existing leads: $e');
    return [];
  }
}

  Future<void> storeLeads(
      String userId, String? profileId, List leads, String usedKeywordsJson) async {
    for (var l in leads) {
      await supabase.from('leads').insert({
        'user_id': userId,
        'profile_id': profileId,
        'name': l['title'] ?? '',
        'phone': l['phone'] ?? '',
        'address': l['address'] ?? '',
        'source_keyword': l['source'] ?? '',
        'raw': l,
      });
    }
    if (profileId != null) {
      await supabase
          .from('business_profiles')
          .update({'keywords': usedKeywordsJson})
          .eq('id', profileId);
    }
  }

  Future<void> addLeads(
      String userId,
      int initialLeads,
      int addLeads) async {
      int finalLeads = initialLeads + addLeads;
    await supabase.from('business_profiles').update({
      'business_name': finalLeads,
    }).eq('user_id',userId);
  }

  Future<void> savePayment(String userId, double amount, String plan) async {
    await supabase.from('payments').insert({
      'user_id': userId,
      'amount': amount,
      'currency': 'INR',
      'plan': plan,
    });
  }
}
