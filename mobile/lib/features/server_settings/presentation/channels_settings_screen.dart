import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
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

  /// True while a reorder is being written. Blocks a second drag from racing
  /// the first and writing positions derived from stale state.
  bool _isSavingOrder = false;

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

  /// Channels in the order they are displayed: ungrouped first, then each
  /// category followed by its children. `_loadChannels` sorts by `position`,
  /// so writing sequential positions in this order makes a reload reproduce
  /// exactly what the user arranged.
  List<ChannelModel> _displayOrderOf(List<ChannelModel> channels) {
    final ordered = <ChannelModel>[
      ...channels.where((c) => c.type != ChannelType.category && c.parentId == null),
      for (final cat in channels.where((c) => c.type == ChannelType.category)) ...[
        cat,
        ...channels.where((c) => c.parentId == cat.id),
      ],
    ];

    // A channel whose parent_id points at a row that is not a category here
    // would otherwise be dropped, leaving it with a stale position that could
    // collide with a reassigned one. Keep it at the end instead.
    final seen = ordered.map((c) => c.id).toSet();
    ordered.addAll(channels.where((c) => !seen.contains(c.id)));
    return ordered;
  }

  /// Reorders one group — the ungrouped section, or one category's children —
  /// and persists the new positions.
  ///
  /// Reordering is scoped to a group on purpose. A drag across group boundaries
  /// would have to decide whether the channel changed category, and a flat
  /// list gives no way to express "into this category, at the end" versus
  /// "after this category". Moving a channel between categories is an edit, not
  /// a drag.
  ///
  /// This used to only call [HapticFeedback.lightImpact] — the list snapped back
  /// on the next load because nothing was written.
  Future<void> _onReorderGroup(
    List<ChannelModel> group,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isSavingOrder) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    HapticFeedback.lightImpact();

    final reordered = List<ChannelModel>.of(group);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    // Splice the regrouped members back into the master list, keeping the slots
    // they already occupied so unrelated rows are untouched.
    final groupIds = group.map((c) => c.id).toSet();
    final next = List<ChannelModel>.of(_channels);
    var slot = 0;
    for (var i = 0; i < next.length; i++) {
      if (groupIds.contains(next[i].id)) {
        next[i] = reordered[slot++];
      }
    }

    final ordered = _displayOrderOf(next);
    final previous = _channels;

    // Show the new order immediately; roll back if the write is rejected.
    setState(() {
      _channels = ordered;
      _isSavingOrder = true;
    });

    try {
      await _persistPositions(ordered);
      if (!mounted) return;
      setState(() {
        _channels = [
          for (var i = 0; i < ordered.length; i++)
            ordered[i].copyWith(position: i),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _channels = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save channel order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  /// Writes sequential `position` values for every channel whose position
  /// changed.
  ///
  /// Each update selects the rows it touched. Under the `update_channels` RLS
  /// policy a user without server ownership or `MANAGE_CHANNELS` matches zero
  /// rows and PostgREST reports success, so a silent no-op is indistinguishable
  /// from a save unless the affected count is checked.
  Future<void> _persistPositions(List<ChannelModel> ordered) async {
    final changes = <String, int>{};
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].position != i) changes[ordered[i].id] = i;
    }
    if (changes.isEmpty) return;

    var applied = 0;
    for (final entry in changes.entries) {
      final rows = await _client
          .from('channels')
          .update({'position': entry.value})
          .eq('id', entry.key)
          .select('id');
      applied += (rows as List).length;
    }

    if (applied < changes.length) {
      throw Exception(
        'you do not have permission to reorder channels on this server',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _channels.where((c) => c.type == ChannelType.category).toList();
    final ungrouped = _channels.where((c) => c.type != ChannelType.category && c.parentId == null).toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
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
            icon: const Icon(Icons.add_rounded, color: Color(FlickoColors.brandLime)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _channels.isEmpty
              ? _buildEmptyState()
              // One reorderable list per group rather than a single list over
              // everything. The old single list mixed headers, spacers and
              // "Empty category" placeholders in with the channels, so the
              // reorder indices it reported did not line up with the channel
              // list — dragging a row moved a different one.
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Ungrouped channels
                    if (ungrouped.isNotEmpty) ...[
                      _buildSectionHeader('UNGROUPED', key: const ValueKey('ungrouped_header')),
                      _buildReorderableGroup(ungrouped),
                      const SizedBox(height: 32),
                    ],

                    // Grouped by category
                    ...categories.expand((cat) {
                      final children = _channels.where((c) => c.parentId == cat.id).toList();
                      return [
                        _buildCategoryHeader(cat, key: ValueKey('cat_${cat.id}')),
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
                          )
                        else
                          _buildReorderableGroup(children, indent: true),
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

  /// A reorderable run of channel tiles for one group. Indices here are
  /// positions within [group], which is what [_onReorderGroup] expects.
  Widget _buildReorderableGroup(List<ChannelModel> group, {bool indent = false}) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: group.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorderGroup(group, oldIndex, newIndex),
      itemBuilder: (context, index) => _buildChannelTile(
        group[index],
        index: index,
        indent: indent,
        key: ValueKey('channel_${group[index].id}'),
      ),
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

  /// [index] is the channel's position **within its own group**, matching the
  /// list that renders it. It used to be `_channels.indexOf(channel)` — an index
  /// into the full channel list — which did not correspond to the enclosing
  /// list's item indices at all.
  Widget _buildChannelTile(
    ChannelModel channel, {
    required int index,
    bool indent = false,
    Key? key,
  }) {
    return ReorderableDragStartListener(
      index: index,
      key: key,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: indent ? 16 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgPrimary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _typeIcons[channel.type] ?? Icons.chat_bubble_outline,
                size: 18,
                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.7),
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
              color: const Color(FlickoColors.bgSecondary),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(FlickoColors.brandLime)),
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
              backgroundColor: const Color(FlickoColors.brandLime),
              foregroundColor: const Color(FlickoColors.bgPrimary),
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
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                        selectedColor: const Color(FlickoColors.brandLime),
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
                      activeThumbColor: const Color(FlickoColors.brandLime),
                      activeTrackColor: const Color(FlickoColors.brandLime).withValues(alpha: 0.3),
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
                    backgroundColor: const Color(FlickoColors.brandLime),
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
      ),
    );
  }

  Widget _buildEditSheet() {
    if (_editChannel == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                        selectedColor: const Color(FlickoColors.brandLime),
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
                      activeThumbColor: const Color(FlickoColors.brandLime),
                      activeTrackColor: const Color(FlickoColors.brandLime).withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.white24,
                      inactiveTrackColor: Colors.white10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showPermissionOverridesDialog(context, _editChannel!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(FlickoColors.brandLime), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PER-CHANNEL PERMISSIONS OVERRIDES',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Configure role-specific Allow/Neutral/Deny rules',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _newName.trim().isEmpty || _isSubmitting ? null : _updateChannel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
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
        ),
      ),
    );
  }

  void _showPermissionOverridesDialog(BuildContext context, ChannelModel channel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Channel Permission Overrides',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set custom permission overrides for #${channel.name}.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('View Channel', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Allow or restrict viewing this channel', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Denied View Channel')));
                      },
                      tooltip: 'Deny',
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                      onPressed: () {},
                      tooltip: 'Neutral',
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(FlickoColors.brandLime)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allowed View Channel')));
                      },
                      tooltip: 'Allow',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime))),
          ),
        ],
      ),
    );
  }
}
