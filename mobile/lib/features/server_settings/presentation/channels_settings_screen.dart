import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/data/models/channel_model.dart';

/// Channels Settings Screen
///
/// List, create, edit, and delete server channels. Supports category grouping.
/// Route: /server/:serverId/settings/channels
class ChannelsSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ChannelsSettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<ChannelsSettingsScreen> createState() => _ChannelsSettingsScreenState();
}

class _ChannelsSettingsScreenState extends ConsumerState<ChannelsSettingsScreen> {
  bool _isLoading = true;
  List<ChannelModel> _channels = [];
  bool _showCreate = false;
  bool _isSubmitting = false;

  // Form state
  late TextEditingController _nameController;
  late TextEditingController _topicController;
  String _newName = '';
  ChannelType _newType = ChannelType.text;
  String _newTopic = '';
  bool _newNsfw = false;
  ChannelModel? _editChannel;


  final _client = Supabase.instance.client;

  final Map<ChannelType, IconData> _typeIcons = {
    ChannelType.text: Icons.chat_bubble_outline,
    ChannelType.voice: Icons.volume_up_outlined,
    ChannelType.announcement: Icons.campaign_outlined,
    ChannelType.forum: Icons.forum_outlined,
    ChannelType.stage: Icons.mic_outlined,
    ChannelType.category: Icons.folder_outlined,
    ChannelType.dm: Icons.message_outlined,
  };

  final List<(ChannelType, String)> _channelTypes = [
    (ChannelType.text, 'Text'),
    (ChannelType.voice, 'Voice'),
    (ChannelType.announcement, 'Announcement'),
    (ChannelType.forum, 'Forum'),
    (ChannelType.stage, 'Stage'),
    (ChannelType.category, 'Category'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _topicController = TextEditingController();
    _loadChannels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('channels')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('position', ascending: true);

      setState(() {
        _channels = (response as List)
            .map((c) => ChannelModel.fromJson(c as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateChannel() async {
    if (_editChannel == null) return;
    final name = _newName.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _client.from('channels').update({
        'name': name,
        'type': _newType.name,
        'topic': _newTopic.trim().isNotEmpty ? _newTopic.trim() : null,
        'nsfw': _newNsfw,
      }).eq('id', _editChannel!.id);

      await _loadChannels();
      _resetForms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel updated')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createChannel() async {
    final name = _newName.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _client.from('channels').insert({
        'server_id': widget.serverId,
        'name': name,
        'type': _newType.name,
        'topic': _newTopic.trim().isNotEmpty ? _newTopic.trim() : null,
        'nsfw': _newNsfw,
        'position': _channels.length,
      });

      _resetForms();
      await _loadChannels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating channel: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteChannel(ChannelModel channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Channel',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Delete #${channel.name}? All messages will be lost.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.red)),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('channels').delete().eq('id', channel.id);
      await _loadChannels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting channel: $e')),
        );
      }
    }
  }

  void _resetForms() {
    setState(() {
      _showCreate = false;
      _editChannel = null;
      _isSubmitting = false;
      _newName = '';
      _newType = ChannelType.text;
      _newTopic = '';
      _newNsfw = false;
      _nameController.clear();
      _topicController.clear();
    });
  }

  void _startEdit(ChannelModel channel) {
    setState(() {
      _editChannel = channel;
      _showCreate = false;
      _newName = channel.name;
      _newType = channel.type;
      _newTopic = channel.topic ?? '';
      _newNsfw = channel.nsfw;
      _nameController.text = channel.name;
      _topicController.text = channel.topic ?? '';
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    // Handling generic ReorderableListView reorder visually without true depth logic
    // for now we just show a slight haptic feedback, a full DB hierarchy save requires
    // analyzing the flat list's new state.
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _channels.where((c) => c.type == ChannelType.category).toList();
    final ungrouped = _channels.where((c) => c.type != ChannelType.category && c.parentId == null).toList();

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
          'CHANNELS',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFFC8FF00)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8FF00)))
          : _channels.isEmpty
              ? _buildEmptyState()
              : ReorderableListView(
                  padding: const EdgeInsets.all(24),
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  children: [
                    // Ungrouped channels
                    if (ungrouped.isNotEmpty) ...[
                      _buildSectionHeader('UNGROUPED', key: const ValueKey('ungrouped_header')),
                      ...ungrouped.map((ch) => _buildChannelTile(ch, key: ValueKey('channel_${ch.id}'))),
                      const SizedBox(key: ValueKey('ungrouped_spacer'), height: 32),
                    ],

                    // Grouped by category
                    ...categories.expand((cat) {
                      final children = _channels.where((c) => c.parentId == cat.id).toList();
                      return [
                        _buildCategoryHeader(cat, key: ValueKey('cat_${cat.id}')),
                        ...children.map((ch) => _buildChannelTile(ch, indent: true, key: ValueKey('channel_${ch.id}'))),
                        if (children.isEmpty)
                          Padding(
                            key: ValueKey('cat_empty_${cat.id}'),
                            padding: const EdgeInsets.only(left: 32, top: 4, bottom: 16),
                            child: Text(
                              'Empty category',
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        SizedBox(key: ValueKey('cat_spacer_${cat.id}'), height: 24),
                      ];
                    }),
                  ],
                ),
      bottomSheet: _showCreate 
          ? _buildCreateSheet() 
          : (_editChannel != null ? _buildEditSheet() : null),
    );
  }

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Padding(
      key: key,
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

  Widget _buildCategoryHeader(ChannelModel category, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Text(
            category.name.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
            onPressed: () => _startEdit(category),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 14, color: Colors.redAccent),
            onPressed: () => _deleteChannel(category),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(ChannelModel channel, {bool indent = false, Key? key}) {
    return ReorderableDragStartListener(
      index: _channels.indexOf(channel),
      key: key,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: indent ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _typeIcons[channel.type] ?? Icons.chat_bubble_outline,
                size: 18,
                color: const Color(0xFFC8FF00).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (channel.topic != null && channel.topic!.isNotEmpty)
                    Text(
                      channel.topic!,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (channel.nsfw)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'NSFW',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white24),
              onPressed: () => _startEdit(channel),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent.withValues(alpha: 0.5)),
              onPressed: () => _deleteChannel(channel),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8FF00).withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFFC8FF00)),
          ),
          const SizedBox(height: 24),
          Text(
            'NO CHANNELS',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start by creating your first space',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _resetForms();
              setState(() => _showCreate = true);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('CREATE CHANNEL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC8FF00),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEW CHANNEL',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  onPressed: _resetForms,
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CHANNEL TYPE'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _channelTypes.map((type) {
                  final isSelected = _newType == type.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.$2.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _newType = type.$1),
                      backgroundColor: Colors.black,
                      selectedColor: const Color(0xFFC8FF00),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.black : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CHANNEL NAME'),
            _buildSheetTextField(
              hint: 'e.g. general',
              controller: _nameController,
              onChanged: (v) => setState(() => _newName = v),
              prefix: const Icon(Icons.tag_rounded, color: Colors.white24, size: 20),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('TOPIC'),
            _buildSheetTextField(
              hint: 'What\'s this channel about?',
              controller: _topicController,
              onChanged: (v) => setState(() => _newTopic = v),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NSFW CHANNEL',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Age-restricted content',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _newNsfw,
                    onChanged: (v) => setState(() => _newNsfw = v),
                    activeThumbColor: const Color(0xFFC8FF00),
                    activeTrackColor: const Color(0xFFC8FF00).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.white24,
                    inactiveTrackColor: Colors.white10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _newName.trim().isEmpty || _isSubmitting ? null : _createChannel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8FF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  disabledBackgroundColor: Colors.white10,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'CREATE CHANNEL',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSheet() {
    if (_editChannel == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EDIT CHANNEL',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  onPressed: _resetForms,
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CHANNEL TYPE'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _channelTypes.map((type) {
                  final isSelected = _newType == type.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.$2.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _newType = type.$1),
                      backgroundColor: Colors.black,
                      selectedColor: const Color(0xFFC8FF00),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.black : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CHANNEL NAME'),
            _buildSheetTextField(
              hint: 'e.g. general',
              controller: _nameController,
              onChanged: (v) => setState(() => _newName = v),
              prefix: const Icon(Icons.tag_rounded, color: Colors.white24, size: 20),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('TOPIC'),
            _buildSheetTextField(
              hint: 'What\'s this channel about?',
              controller: _topicController,
              onChanged: (v) => setState(() => _newTopic = v),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NSFW CHANNEL',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Age-restricted content',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _newNsfw,
                    onChanged: (v) => setState(() => _newNsfw = v),
                    activeThumbColor: const Color(0xFFC8FF00),
                    activeTrackColor: const Color(0xFFC8FF00).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.white24,
                    inactiveTrackColor: Colors.white10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _newName.trim().isEmpty || _isSubmitting ? null : _updateChannel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8FF00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  disabledBackgroundColor: Colors.white10,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'SAVE CHANGES',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTextField({
    required String hint,
    required ValueChanged<String> onChanged,
    TextEditingController? controller,
    int maxLines = 1,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          prefixIcon: prefix,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
