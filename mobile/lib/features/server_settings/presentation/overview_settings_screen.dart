import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

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
  String? _errorMessage;

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _iconController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _iconController = TextEditingController();
    _loadServerData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _loadServerData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .single();

      if (mounted) {
        setState(() {
          _serverData = response;
          _nameController.text = response['name'] ?? '';
          _descController.text = response['description'] ?? '';
          _iconController.text = response['icon'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server name cannot be empty'),
          backgroundColor: Color(FlickoColors.danger),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final iconVal = _iconController.text.trim();
      await Supabase.instance.client
          .from('servers')
          .update({
            'name': name,
            'description': _descController.text.trim(),
            'icon': iconVal.isEmpty ? null : iconVal,
          })
          .eq('id', widget.serverId);

      await _loadServerData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server overview updated successfully!'),
            backgroundColor: Color(FlickoColors.green),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update server: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Overview',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading && _errorMessage == null)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(FlickoColors.brandLime),
                      ),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.brandLime),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text('Error loading server', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadServerData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServerInfoCard(),
          const SizedBox(height: 24),
          _buildEditFields(),
          const SizedBox(height: 24),
          _buildSection('SERVER INFORMATION', [
            _buildInfoRow('Server ID', _serverData?['id'] ?? 'Unknown'),
            _buildInfoRow('Created', _formatDate(_serverData?['created_at'])),
            _buildInfoRow('Owner ID', _serverData?['owner_id'] ?? 'Unknown'),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildServerInfoCard() {
    final iconUrl = _iconController.text.trim();
    final hasIcon = iconUrl.isNotEmpty;
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(FlickoColors.bgTertiary),
            backgroundImage: hasIcon ? CachedNetworkImageProvider(iconUrl) : null,
            child: !hasIcon
                ? Text(
                    initials,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.brandLime),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty ? 'New Server' : _nameController.text,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _descController.text.isEmpty ? 'No description set.' : _descController.text,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EDIT SERVER DETAILS',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildTextField(
                label: 'SERVER NAME',
                controller: _nameController,
                hint: 'Enter server name',
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'DESCRIPTION',
                controller: _descController,
                hint: 'Enter server description',
                maxLength: 256,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'ICON URL',
                controller: _iconController,
                hint: 'Enter image URL for server icon',
                maxLength: 500,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13),
            filled: true,
            fillColor: const Color(FlickoColors.bgTertiary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}
