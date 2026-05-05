import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OverviewSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const OverviewSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<OverviewSettingsScreen> createState() => _OverviewSettingsScreenState();
}

class _OverviewSettingsScreenState extends ConsumerState<OverviewSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _serverData;
  
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadServerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadServerData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server not found'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _serverData = response;
          _nameController.text = response['name'] ?? '';
          _descriptionController.text = response['description'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading server: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    
    try {
      await Supabase.instance.client
          .from('servers')
          .update({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
          })
          .eq('id', widget.serverId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFFC8FF00),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadServerData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC8FF00))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFC8FF00), size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'OVERVIEW',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFFC8FF00), strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: Text(
                'SAVE',
                style: GoogleFonts.inter(
                  color: const Color(0xFFC8FF00),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIconPicker(),
            const SizedBox(height: 32),
            _buildSectionHeader('SERVER NAME'),
            _buildTextField(_nameController, 'Enter server name'),
            const SizedBox(height: 24),
            _buildSectionHeader('DESCRIPTION'),
            _buildTextField(_descriptionController, 'What is this server about?', maxLines: 3),
            const SizedBox(height: 32),
            _buildSectionHeader('SERVER INFO'),
            _buildInfoCard([
              _buildInfoRow('Server ID', widget.serverId),
              _buildInfoRow('Created On', _formatDate(_serverData?['created_at'])),
              _buildInfoRow('Owner ID', _serverData?['owner_id'] ?? 'Unknown'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFC8FF00).withValues(alpha: 0.1), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC8FF00).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: _serverData?['icon_url'] != null
                  ? Image.network(_serverData!['icon_url'], fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        (_serverData?['name'] ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFC8FF00),
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFC8FF00),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFFC8FF00).withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
