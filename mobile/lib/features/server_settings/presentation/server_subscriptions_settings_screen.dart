import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Server Subscriptions Settings Screen
/// Allows server creators to set up paid membership tiers, monthly pricing, and exclusive perks.
class ServerSubscriptionsSettingsScreen extends StatefulWidget {
  final String serverId;

  const ServerSubscriptionsSettingsScreen({super.key, required this.serverId});

  @override
  State<ServerSubscriptionsSettingsScreen> createState() => _ServerSubscriptionsSettingsScreenState();
}

class _ServerSubscriptionsSettingsScreenState extends State<ServerSubscriptionsSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tiers = [];

  final _tierNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  @override
  void dispose() {
    _tierNameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTiers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('server_subscription_tiers')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('price_cents', ascending: true);

      if (mounted) {
        setState(() {
          _tiers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTier() async {
    final name = _tierNameController.text.trim();
    final priceStr = _priceController.text.trim();
    if (name.isEmpty || priceStr.isEmpty || _isCreating) return;

    final priceCents = ((double.tryParse(priceStr) ?? 4.99) * 100).round();

    setState(() => _isCreating = true);
    try {
      await Supabase.instance.client.from('server_subscription_tiers').insert({
        'server_id': widget.serverId,
        'tier_name': name,
        'price_cents': priceCents,
        'description': _descController.text.trim(),
        'perks': ['Exclusive VIP Chat Channel', 'Custom Role Badge', 'Ad-Free Streams'],
      });

      _tierNameController.clear();
      _priceController.clear();
      _descController.clear();
      if (mounted) Navigator.pop(context);
      await _loadTiers();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showAddTierModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Subscription Tier', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _tierNameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tier Name (e.g. Gold Supporter)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Monthly Price in USD (e.g. 4.99)',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Description of Perks',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createTier,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text('Publish Tier', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Server Subscriptions', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, color: Color(FlickoColors.brandLime)), onPressed: _showAddTierModal),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _tiers.isEmpty
              ? Center(
                  child: Text('No subscription tiers configured yet.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tiers.length,
                  itemBuilder: (context, index) {
                    final tier = _tiers[index];
                    final price = ((tier['price_cents'] as int? ?? 499) / 100.0).toStringAsFixed(2);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tier['tier_name'] as String? ?? 'Tier', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('\$$price/mo', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (tier['description'] != null) ...[
                            const SizedBox(height: 6),
                            Text(tier['description'] as String, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
