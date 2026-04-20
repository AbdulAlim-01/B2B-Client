import 'dart:convert';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/services/service.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class GenerateLeadsScreen extends StatefulWidget {
  final String userId;
  const GenerateLeadsScreen({super.key, required this.userId});
  @override
  State<GenerateLeadsScreen> createState() => _GenerateLeadsScreenState();
}

class _GenerateLeadsScreenState extends State<GenerateLeadsScreen>
    with TickerProviderStateMixin {
  final supa = SupabaseService();
  Map? profile;
  bool loading = true;
  bool generating = false;
  List generatedLeads = [];
  List<String> keywords = [];

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Modern color scheme (matching dashboard)
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color surfaceColor = Color(0xFFF8FAFE);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);

  late BusinessCoachService services;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    services = BusinessCoachService();
    fetchProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    profile = await supa.getBusinessProfile(widget.userId);
    setState(() => loading = false);
  }

  int computeKeywordsToUse(int leadsLeft) {
    if (leadsLeft <= 0) return 0;
    if (leadsLeft <= 5) return 1;
    if (leadsLeft <= 10) return 1;
    if (leadsLeft <= 20) return 2;
    if (leadsLeft <= 30) return 3;
    if (leadsLeft <= 40) return 4;
    return 6;
  }


  Future<void> generate() async {
    if (profile == null) return;
    final leadsLeft = profile!['leads_remaining'] as int? ?? 0;
    if (leadsLeft <= 0) {
      _showSnackBar('No leads left. Please upgrade to continue.', Colors.red);
      return;
    }

    setState(() {
      generating = true;
      generatedLeads.clear();
      keywords.clear();
    });

    _pulseController.repeat(reverse: true);

  try {
    final desc = profile!['description'] ?? '';
    final keyword = computeKeywordsToUse(leadsLeft);
    final resp = await services.searchCustomersLocal(businessDescription: desc, keyword: keyword);
    
    if (!resp.success) {
      throw Exception(resp.error ?? 'Unknown error occurred during generation');
    }

    final allBusinesses = resp.allBusinesses ?? [];
    final responseKeywords = resp.keywords ?? [];
    
    print('Found ${allBusinesses.length} total potential leads from AI');

    // Get existing leads for this user to avoid duplicates
    final existingLeads = await supa.getExistingLeads(widget.userId, profile!['id']);
    final existingPhones = existingLeads.map((lead) => lead['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '')).where((phone) => phone != null && phone.isNotEmpty).toSet();

    // Filter leads: must have phone number and not be duplicate
    final validLeads = allBusinesses.where((business) {
      final businessJson = business.toJson();
      final phone = businessJson['phone']?.toString() ?? '';
      
      // Check if phone exists and is not empty
      if (phone.isEmpty) {
        print('Lead "${business.title}" skipped: No phone number');
        return false;
      }
      
      // Normalize phone number for comparison
      final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedPhone.isEmpty) {
        print('Lead "${business.title}" skipped: Invalid phone format "$phone"');
        return false;
      }
      
      // Check if not duplicate
      if (existingPhones.contains(normalizedPhone)) {
        print('Lead "${business.title}" skipped: Duplicate phone "$normalizedPhone"');
        return false;
      }
      
      return true;
    }).toList();

    final wantCount = leadsLeft;
    final taken = validLeads.take(wantCount).map((business) => business.toJson()).toList();

    // Only proceed if we have valid leads
    if (taken.isNotEmpty) {
      // Save leads
      await supa.storeLeads(
          widget.userId, profile!['id'], taken, jsonEncode(responseKeywords));

      // Deduct leads based on actual valid leads taken
      final deducted = taken.length;
      final newLeft = (leadsLeft - deducted).clamp(0, 999999);
      await supa.updateLeadsRemaining(profile!['id'], newLeft);

      setState(() {
        generatedLeads = taken;
        keywords = responseKeywords.cast<String>();
        profile!['leads_remaining'] = newLeft;
      });

      _slideController.forward();
      _showSnackBar(
          'Successfully generated ${taken.length} leads!', accentGreen);
    } else {
      // No valid leads found
      setState(() {
        generatedLeads = [];
        keywords = responseKeywords.cast<String>();
      });
      
      _showSnackBar(
          'No new leads with phone numbers found. Try again later.', Colors.orange);
    }
    } catch (e) {
      print('error : $e');
      _showSnackBar('Generation failed: ${e.toString()}', Colors.red);
      
    } finally {
      _pulseController.stop();
      setState(() => generating = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void openWhatsApp(String phone, String message) async {
    final url = Uri.parse(
        'https://wa.me/+91${phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open WhatsApp', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: surfaceColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: primaryBlue,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your profile...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final leadsLeft = profile?['leads_remaining'] ?? 0;
    final aiMessage = profile?['ai_message'] ?? '';

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Generate Leads',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Info Card
            _modernGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.business,
                          color: primaryBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?['business_name'] ?? 'Your Business',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: leadsLeft > 0
                                    ? accentGreen.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$leadsLeft leads available',
                                style: TextStyle(
                                  color:
                                      leadsLeft > 0 ? accentGreen : Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile?['description'] ?? 'No description available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generation Section
            _modernGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rocket_launch, color: primaryBlue, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Lead Generation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (generating) ...[
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: primaryBlue.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: primaryBlue,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Generating leads...',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Our AI is analyzing your business and finding the best potential customers',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ] else if (generatedLeads.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: primaryBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ready to generate leads?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click the button below to find potential customers based on your business description',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: generating || leadsLeft <= 0 ? null : generate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            leadsLeft > 0 ? primaryBlue : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: generating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 20),
                      label: Text(
                        generating
                            ? 'Generating...'
                            : leadsLeft <= 0
                                ? 'No Leads Available'
                                : 'Generate Leads Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            

            // Results Section
            if (generatedLeads.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Generated Leads',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${generatedLeads.length} leads',
                      style: TextStyle(
                        color: accentGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: generatedLeads
                      .map((lead) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _enhancedLeadCard(lead, aiMessage),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _enhancedLeadCard(Map lead, String aiMessage) {
    final name = lead['title'] ?? 'Unknown Business';
    final phone = lead['phone'] ?? '';
    final email = lead['email'] ?? '';
    final address = lead['address'] ?? '';
    final rating = lead['rating']?.toString() ?? '';
    final reviewCount = lead['review_count']?.toString() ?? '';
    final website = lead['website'] ?? '';

    return _modernGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.business,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rating.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: accentOrange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$rating${reviewCount.isNotEmpty ? ' ($reviewCount reviews)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Contact Info
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (phone.isNotEmpty)
                _contactChip(Icons.phone, phone, primaryBlue),
              if (email.isNotEmpty)
                _contactChip(Icons.email, email, accentGreen),
              if (website.isNotEmpty)
                _contactChip(Icons.language, website, accentOrange),
            ],
          ),

          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.grey[500], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: phone.isNotEmpty
                  ? () => openWhatsApp(phone, aiMessage)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.send, size: 18),
              label: const Text(
                'Contact via WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
