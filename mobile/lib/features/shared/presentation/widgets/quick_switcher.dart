import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/core/constants/flicko_colors.dart';

class SwitcherItem {
  final String id;
  final String type;
  final String name;
  final String? subtitle;
  final IconData icon;
  final String? serverId;

  SwitcherItem({
    required this.id,
    required this.type,
    required this.name,
    this.subtitle,
    required this.icon,
    this.serverId,
  });
}

class QuickSwitcher extends ConsumerStatefulWidget {
  final bool visible;
  final VoidCallback onClose;

  const QuickSwitcher({
    super.key,
    required this.visible,
    required this.onClose,
  });

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<SwitcherItem> _results = [];
  List<SwitcherItem> _recentItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(QuickSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _focusNode.requestFocus();
      });
    } else if (!widget.visible) {
      _searchController.clear();
      _results.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results.clear());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final items = <SwitcherItem>[];
      final searchTerm = '%$query%';

      final channels = await Supabase.instance.client
          .from('channels')
          .select('id, name, server_id, servers!inner(name)')
          .ilike('name', searchTerm)
          .limit(10);

      for (final ch in (channels as List)) {
        items.add(SwitcherItem(
          id: ch['id'],
          type: 'channel',
          name: '#${ch['name']}',
          subtitle: ch['servers']?['name'],
          icon: Icons.chat_bubble_outline,
          serverId: ch['server_id'],
        ));
      }

      final servers = await Supabase.instance.client
          .from('servers')
          .select('id, name')
          .ilike('name', searchTerm)
          .limit(5);

      for (final s in (servers as List)) {
        items.add(SwitcherItem(
          id: s['id'],
          type: 'server',
          name: s['name'],
          icon: Icons.dns_outlined,
        ));
      }

      final users = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name')
          .or('username.ilike.$searchTerm,display_name.ilike.$searchTerm')
          .limit(5);

      for (final u in (users as List)) {
        items.add(SwitcherItem(
          id: u['id'],
          type: 'dm',
          name: u['display_name'] ?? u['username'],
          subtitle: '@${u['username']}',
          icon: Icons.person_outline,
        ));
      }

      setState(() {
        _results = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[QuickSwitcher] search error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleSelect(SwitcherItem item) {
    widget.onClose();
    switch (item.type) {
      case 'channel':
        if (item.serverId != null) {
          context.go('/server/${item.serverId}/channel/${item.id}');
        }
        break;
      case 'server':
        context.go('/server/${item.id}');
        break;
      case 'dm':
        context.go('/dm/${item.id}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
              child: Material(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(FlickoColors.bgTertiary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.search, color: Color(FlickoColors.textMuted), size: 18),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focusNode,
                                  onChanged: _search,
                                  style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                                  decoration: InputDecoration(
                                    hintText: 'Where would you like to go?',
                                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                                    border: InputBorder.none,
                                  ),
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted), size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _results.clear());
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchController.text.trim().isEmpty ? _recentItems.length : _results.length,
                                itemBuilder: (context, index) {
                                  final item = _searchController.text.trim().isEmpty ? _recentItems[index] : _results[index];
                                  return ListTile(
                                    leading: Icon(item.icon, color: const Color(FlickoColors.textSecondary)),
                                    title: Text(item.name, style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                                    subtitle: item.subtitle != null
                                        ? Text(item.subtitle!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12))
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(FlickoColors.bgTertiary),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.type == 'channel' ? 'Channel' : item.type == 'server' ? 'Server' : 'DM',
                                        style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 11),
                                      ),
                                    ),
                                    onTap: () => _handleSelect(item),
                                  );
                                },
                              ),
                      ),
                      if (_searchController.text.trim().isEmpty && _results.isEmpty && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Start typing to search channels, servers, and DMs',
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_searchController.text.trim().isNotEmpty && _results.isEmpty && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No results found',
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
