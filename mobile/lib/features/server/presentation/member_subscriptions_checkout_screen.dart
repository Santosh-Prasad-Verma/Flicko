import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Member Subscriptions Checkout Screen
/// Checkout modal for server members to view perks and purchase monthly server tiers.
class MemberSubscriptionsCheckoutScreen extends StatefulWidget {
  final String serverId;
  final String tierId;

  const MemberSubscriptionsCheckoutScreen({
    super.key,
    required this.serverId,
    required this.tierId,
  });

  @override
  State<MemberSubscriptionsCheckoutScreen> createState() => _MemberSubscriptionsCheckoutScreenState();
}

class _MemberSubscriptionsCheckoutScreenState extends State<MemberSubscriptionsCheckoutScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _tier;
  bool _isSubscribing = false;

  @override
  void initState() {
    super.initState();
    _loadTierDetails();
  }

  Future<void> _loadTierDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('server_subscription_tiers')
          .select('*')
          .eq('id', widget.tierId)
          .single();

      if (mounted) {
        setState(() {
          _tier = response;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processSubscription() async {
    if (_isSubscribing) return;
    setState(() => _isSubscribing = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('member_server_subscriptions').insert({
        'server_id': widget.serverId,
        'tier_id': widget.tierId,
        'user_id': userId,
        'status': 'active',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Server Tier Subscribed Successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Join Server Tier', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _tier == null
              ? const Center(child: Text('Tier not found'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgSecondary),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tier!['tier_name'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              '\$${((_tier!['price_cents'] as int) / 100.0).toStringAsFixed(2)} / month',
                              style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Text('Included Member Perks:', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...(_tier!['perks'] as List? ?? ['VIP Role', 'Special Emoji Access']).map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(FlickoColors.brandLime), size: 18),
                                      const SizedBox(width: 8),
                                      Text(p.toString(), style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubscribing ? null : _processSubscription,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(FlickoColors.brandLime),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSubscribing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text('Subscribe Now', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
