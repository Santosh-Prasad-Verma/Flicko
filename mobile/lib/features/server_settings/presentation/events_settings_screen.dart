import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Event data model
class _ServerEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime;
  final String? channelId;
  final String? imageUrl;
  final int? attendeeCount;

  _ServerEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.channelId,
    this.imageUrl,
    this.attendeeCount,
  });

  factory _ServerEvent.fromJson(Map<String, dynamic> json) {
    return _ServerEvent(
      id: json['id'] as String,
      title: json['name'] ?? json['title'] ?? 'Unnamed Event',
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'] as String) 
          : null,
      channelId: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
      attendeeCount: json['interested_count'] as int?,
    );
  }
}

/// Events Settings Screen
///
/// Create and manage scheduled server events.
class EventsSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const EventsSettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<EventsSettingsScreen> createState() => _EventsSettingsScreenState();
}

class _EventsSettingsScreenState extends ConsumerState<EventsSettingsScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  List<_ServerEvent> _events = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _client
          .from('scheduled_events')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('start_time', ascending: false);

      setState(() {
        _events = (response as List)
            .map((r) => _ServerEvent.fromJson(r as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Event',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this event?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.red)),
            child: Text('Delete',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('scheduled_events').delete().eq('id', eventId);
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateEventDialog(
        serverId: widget.serverId,
        onEventCreated: _loadEvents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
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
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: _showCreateEventDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _errorMessage != null
              ? _buildErrorState()
              : _events.isEmpty
                  ? _buildEmptyState()
                  : _buildEventsList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
          const SizedBox(height: 16),
          Text(
            'Error loading events',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEvents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_outlined,
                size: 48, color: Color(FlickoColors.textMuted)),
          ),
          const SizedBox(height: 16),
          Text(
            'No Events Yet',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create scheduled events for your community.',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showCreateEventDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text('Create Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: const Color(FlickoColors.blurple),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) => _buildEventCard(_events[index]),
      ),
    );
  }

  Widget _buildEventCard(_ServerEvent event) {
    final isPast = event.startTime.isBefore(DateTime.now());
    
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPast
                      ? const Color(FlickoColors.textMuted).withValues(alpha: 0.2)
                      : const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPast ? 'Past' : 'Upcoming',
                  style: GoogleFonts.inter(
                    color: isPast
                        ? const Color(FlickoColors.textMuted)
                        : const Color(FlickoColors.blurple),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, 
                    color: Color(FlickoColors.danger), size: 20),
                onPressed: () => _deleteEvent(event.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (event.description != null) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, 
                  size: 16, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(event.startTime),
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 12,
                ),
              ),
              if (event.attendeeCount != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.people, 
                    size: 16, color: Color(FlickoColors.textMuted)),
                const SizedBox(width: 8),
                Text(
                  '${event.attendeeCount} attending',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Create Event Dialog
class _CreateEventDialog extends StatefulWidget {
  final String serverId;
  final VoidCallback onEventCreated;

  const _CreateEventDialog({
    required this.serverId,
    required this.onEventCreated,
  });

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _client = Supabase.instance.client;

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _client.from('scheduled_events').insert({
        'server_id': widget.serverId,
        'creator_id': userId,
        'name': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'event_type': 'text',
        'start_time': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onEventCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating event: $e'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(FlickoColors.bgSecondary),
      title: Text(
        'Create Event',
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                labelText: 'Event Title',
                labelStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted)),
                hintText: 'e.g. Weekly Gaming Night',
                hintStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted)),
                hintText: 'Add details about your event...',
                hintStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted))),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(FlickoColors.blurple),
            disabledBackgroundColor: const Color(FlickoColors.bgTertiary),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Create',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
