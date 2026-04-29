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

  // Create form
  String _newName = '';
  ChannelType _newType = ChannelType.text;
  String _newTopic = '';
  bool _newNsfw = false;

  // Edit form
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
    _loadChannels();
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

      _resetCreateForm();
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

  void _resetCreateForm() {
    setState(() {
      _showCreate = false;
      _newName = '';
      _newType = ChannelType.text;
      _newTopic = '';
      _newNsfw = false;
    });
  }

  void _startEdit(ChannelModel channel) {
    setState(() {
      _editChannel = channel;
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
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Channels (${_channels.length})',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _channels.isEmpty
              ? _buildEmptyState()
              : ReorderableListView(
                  padding: const EdgeInsets.all(16),
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false, // We'll add our own icons or just rely on long press
                  children: [
                    // Ungrouped channels
                    if (ungrouped.isNotEmpty) ...[
                      _buildSectionHeader('CHANNELS', key: const ValueKey('ungrouped_header')),
                      ...ungrouped.map((ch) => _buildChannelTile(ch, key: ValueKey('channel_${ch.id}'))),
                      const SizedBox(key: ValueKey('ungrouped_spacer'), height: 16),
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
                            padding: const EdgeInsets.only(left: 32, top: 4),
                            child: Text(
                              'No channels in this category',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        SizedBox(key: ValueKey('cat_spacer_${cat.id}'), height: 16),
                      ];
                    }),
                  ],
                ),

      // Create Modal
      bottomSheet: _showCreate ? _buildCreateSheet() : null,

      // Edit Modal
      floatingActionButton: _editChannel != null ? null : null,
    );
  }

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(ChannelModel category, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.expand_more, size: 14, color: Color(FlickoColors.textMuted)),
          const SizedBox(width: 4),
          Text(
            category.name.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit, size: 14, color: Color(FlickoColors.textMuted)),
            onPressed: () => _startEdit(category),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete, size: 14, color: Color(FlickoColors.red)),
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
      index: _channels.indexOf(channel), // Will not be completely accurate with categories mapped to flat list
      key: key,
      child: Container(
      margin: EdgeInsets.only(bottom: 4, left: indent ? 20 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _typeIcons[channel.type] ?? Icons.chat_bubble_outline,
            size: 18,
            color: const Color(FlickoColors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (channel.topic != null && channel.topic!.isNotEmpty)
                  Text(
                    channel.topic!,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (channel.nsfw)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.red).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'NSFW',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.red),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16, color: Color(FlickoColors.textSecondary)),
            onPressed: () => _startEdit(channel),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 16, color: Color(FlickoColors.red)),
            onPressed: () => _deleteChannel(channel),
            padding: const EdgeInsets.all(8),
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
          const Icon(Icons.chat_bubble_outline, size: 48, color: Color(FlickoColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            'No channels',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first channel to get started',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.textMuted),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Create Channel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Type chips
            Text(
              'CHANNEL TYPE',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _channelTypes.map((type) {
                final isSelected = _newType == type.$1;
                return ChoiceChip(
                  label: Text(type.$2),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _newType = type.$1),
                  backgroundColor: const Color(FlickoColors.bgTertiary),
                  selectedColor: const Color(FlickoColors.blurple),
                  labelStyle: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(FlickoColors.textSecondary),
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              onChanged: (v) => setState(() => _newName = v),
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                labelText: 'Channel Name',
                labelStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 8),

            // Topic
            TextField(
              onChanged: (v) => setState(() => _newTopic = v),
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                labelText: 'Topic (optional)',
                labelStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLength: 1024,
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            // NSFW switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NSFW',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _newNsfw,
                  onChanged: (v) => setState(() => _newNsfw = v),
                  activeThumbColor: const Color(FlickoColors.blurple),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetCreateForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.bgTertiary),
                      foregroundColor: const Color(FlickoColors.textPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _newName.trim().isEmpty || _isSubmitting ? null : _createChannel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.blurple),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: const Color(FlickoColors.bgTertiary),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
