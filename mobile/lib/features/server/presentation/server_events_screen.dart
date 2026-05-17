import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Server Events Screen
///
/// Lists scheduled events with RSVP and create functionality.
/// Route: /server/:serverId/events
class ServerEventsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerEventsScreen({super.key, required this.serverId});

  @override
  ConsumerState<ServerEventsScreen> createState() => _ServerEventsScreenState();
}

class _Event {
  final String id;
  final String name;
  final String? description;
  final DateTime startTime;
  final String status;
  final String? channelName;
  final String? location;
  final int interestedCount;

  _Event({
    required this.id,
    required this.name,
    this.description,
    required this.startTime,
    required this.status,
    this.channelName,
    this.location,
    this.interestedCount = 0,
  });
}

class _ServerEventsScreenState extends ConsumerState<ServerEventsScreen> {
  bool _isLoading = true;
  List<_Event> _events = [];
  bool _showCreate = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _events = [
          _Event(
            id: '1',
            name: 'Community Hangout',
            description: 'Join us for a chill talk about the future of Flicko.',
            startTime: DateTime.now().add(const Duration(hours: 2)),
            status: 'scheduled',
            channelName: 'general',
            interestedCount: 15,
          ),
          _Event(
            id: '2',
            name: 'Voice Night',
            startTime: DateTime.now().add(const Duration(days: 1)),
            status: 'scheduled',
            interestedCount: 5,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(now).inDays;
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today at $time';
    if (diff == 1) return 'Tomorrow at $time';
    return '${_monthName(d.month)} ${d.day} at $time';
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }

  void _createEvent() {
    if (_nameCtrl.text.trim().isEmpty) return;

    final event = _Event(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      startTime: DateTime.now().add(const Duration(hours: 1)),
      status: 'scheduled',
      location: _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : null,
    );

    setState(() {
      _events.insert(0, event);
      _showCreate = false;
      _nameCtrl.clear();
      _descCtrl.clear();
      _locationCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Events',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(FlickoColors.blurple)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
              : _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: Color(FlickoColors.textMuted)),
                          const SizedBox(height: 12),
                          Text(
                            'No upcoming events',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textSecondary),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final isActive = event.status == 'active';
                        final isScheduled = event.status == 'scheduled';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(FlickoColors.bgSecondary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(FlickoColors.green)
                                          : isScheduled
                                              ? const Color(FlickoColors.blurple)
                                              : const Color(FlickoColors.textMuted),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDate(event.startTime),
                                      style: GoogleFonts.inter(
                                        color: const Color(FlickoColors.blurple),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(FlickoColors.green),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'LIVE',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Name
                              Text(
                                event.name,
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textPrimary),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (event.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event.description!,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textSecondary),
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 10),
                              // Meta
                              Row(
                                children: [
                                  if (event.channelName != null)
                                    _buildMetaChip(Icons.chat_bubble_outline, '#${event.channelName}')
                                  else if (event.location != null)
                                    _buildMetaChip(Icons.location_on_outlined, event.location!),
                                  _buildMetaChip(Icons.star_outline, '${event.interestedCount} interested'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // RSVP
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.star_outline, size: 16),
                                label: Text('Interested', style: GoogleFonts.inter(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(FlickoColors.bgTertiary),
                                  foregroundColor: const Color(FlickoColors.textSecondary),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          // Create modal
          if (_showCreate)
            Container(
              color: Colors.black54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(FlickoColors.bgSecondary),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Color(FlickoColors.textSecondary)),
                                onPressed: () => setState(() => _showCreate = false),
                              ),
                              Text(
                                'Create Event',
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textPrimary),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _nameCtrl.text.trim().isEmpty ? null : _createEvent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(FlickoColors.blurple),
                                ),
                                child: Text('Create', style: GoogleFonts.inter(color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameCtrl,
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                            decoration: InputDecoration(
                              hintText: 'Event name',
                              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                              filled: true,
                              fillColor: const Color(FlickoColors.bgTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descCtrl,
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                            decoration: InputDecoration(
                              hintText: 'Description (optional)',
                              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                              filled: true,
                              fillColor: const Color(FlickoColors.bgTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _locationCtrl,
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                            decoration: InputDecoration(
                              hintText: 'Location (optional)',
                              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                              filled: true,
                              fillColor: const Color(FlickoColors.bgTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(FlickoColors.textMuted)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
