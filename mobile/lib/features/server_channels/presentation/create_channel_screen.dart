import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum ChannelType { text, voice }

class CreateChannelScreen extends ConsumerStatefulWidget {
  final String serverId;

  const CreateChannelScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final _nameController = TextEditingController();
  ChannelType _selectedType = ChannelType.text;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameChange(String value) {
    setState(() {
      _nameController.value = TextEditingValue(
        text: value.toLowerCase().replaceAll(' ', '-'),
        selection: _nameController.selection,
      );
      _errorMessage = null;
    });
  }

  Future<void> _createChannel() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Channel name is required');
      return;
    }

    if (name.length > 100) {
      setState(() => _errorMessage = 'Channel name must be 100 characters or less');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final response = await Supabase.instance.client
          .from('channels')
          .insert({
            'name': name,
            'type': _selectedType.name,
            'server_id': widget.serverId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      if (mounted) {
        Navigator.of(context).pop(response['id']);
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Channel',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChannelTypeSelector(),
            const SizedBox(height: 24),
            _buildChannelNameInput(),
            const SizedBox(height: 24),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHANNEL TYPE',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildTypeOption(
                ChannelType.text,
                Icons.text_fields,
                'Text',
                'Send messages, images, GIFs, and more',
              ),
              Container(
                height: 1,
                color: const Color(FlickoColors.bgTertiary),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              _buildTypeOption(
                ChannelType.voice,
                Icons.volume_up,
                'Voice',
                'Hang out together with voice, video, and screen share',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(
    ChannelType type,
    IconData icon,
    String label,
    String description,
  ) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(FlickoColors.bgTertiary) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(FlickoColors.textPrimary)
                  : const Color(FlickoColors.textMuted),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(FlickoColors.blurple)
                      : const Color(FlickoColors.textMuted),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(FlickoColors.blurple),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _isNameFocused = false;

  Widget _buildChannelNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHANNEL NAME',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (focused) {
            setState(() {
              _isNameFocused = focused;
            });
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _errorMessage != null
                  ? const Color(FlickoColors.danger).withValues(alpha: 0.1)
                  : const Color(0xFF0C0C10).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _errorMessage != null
                    ? const Color(FlickoColors.danger)
                    : (_isNameFocused ? const Color(0xFF52B788) : Colors.white.withValues(alpha: 0.12)),
                width: 1.5,
              ),
              boxShadow: _isNameFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF52B788).withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Icon(
                    _selectedType == ChannelType.text ? Icons.tag : Icons.volume_up_rounded,
                    size: 20,
                    color: _isNameFocused ? const Color(0xFF52B788) : const Color(FlickoColors.textMuted),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    onChanged: _handleNameChange,
                    cursorColor: const Color(0xFF52B788),
                    cursorWidth: 2.2,
                    cursorHeight: 20.0,
                    cursorRadius: const Radius.circular(1.0),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'new-channel',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLength: 100,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _createChannel(),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.danger),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _nameController.text.trim().isEmpty || _isCreating ? null : _createChannel,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(FlickoColors.blurple),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Create Channel',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
