import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Channel Media Gallery Sheet
/// Multi-tab attachment viewer for browsing Images, Videos, Links, Files, and Audio shared in a channel.
class ChannelMediaGallerySheet extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelMediaGallerySheet({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  static void show(BuildContext context, {required String channelId, required String channelName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChannelMediaGallerySheet(channelId: channelId, channelName: channelName),
    );
  }

  @override
  State<ChannelMediaGallerySheet> createState() => _ChannelMediaGallerySheetState();
}

class _ChannelMediaGallerySheetState extends State<ChannelMediaGallerySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';

  List<String> _imageUrls = [];
  List<String> _videoUrls = [];
  List<String> _links = [];
  List<Map<String, dynamic>> _files = [];
  List<String> _audioUrls = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('content, attachments')
          .eq('channel_id', widget.channelId)
          .order('created_at', ascending: false);

      final images = <String>[];
      final videos = <String>[];
      final links = <String>[];
      final files = <Map<String, dynamic>>[];
      final audios = <String>[];

      final urlRegex = RegExp(r'https?://[^\s]+');

      for (final msg in response) {
        final content = msg['content'] as String? ?? '';
        final matches = urlRegex.allMatches(content);
        for (final m in matches) {
          final url = m.group(0)!;
          if (!links.contains(url)) links.add(url);
        }

        final attachments = msg['attachments'] as List? ?? [];
        for (final att in attachments) {
          String? url;
          String name = 'Attachment';
          if (att is String) {
            url = att;
          } else if (att is Map) {
            url = att['url'] as String? ?? att['path'] as String?;
            name = att['name'] as String? ?? 'File';
          }

          if (url == null) continue;

          final lower = url.toLowerCase();
          if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif')) {
            images.add(url);
          } else if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm') || lower.endsWith('.mkv')) {
            videos.add(url);
          } else if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a') || lower.endsWith('.ogg')) {
            audios.add(url);
          } else {
            files.add({'url': url, 'name': name});
          }
        }
      }

      if (mounted) {
        setState(() {
          _imageUrls = images;
          _videoUrls = videos;
          _links = links;
          _files = files;
          _audioUrls = audios;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageZoom(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(url))),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.perm_media_outlined, color: Color(FlickoColors.brandLime), size: 22),
                const SizedBox(width: 10),
                Text(
                  '#${widget.channelName} — Media Gallery',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Filter attachments & links...',
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // TabBar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(FlickoColors.brandLime),
            labelColor: const Color(FlickoColors.brandLime),
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: '📸 Images'),
              Tab(text: '🎥 Videos'),
              Tab(text: '🔗 Links'),
              Tab(text: '📄 Files'),
              Tab(text: '🎵 Audio'),
            ],
          ),
          const Divider(color: Colors.white10, height: 1),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImagesTab(),
                      _buildVideosTab(),
                      _buildLinksTab(),
                      _buildFilesTab(),
                      _buildAudioTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    final filtered = _imageUrls.where((url) => _searchQuery.isEmpty || url.toLowerCase().contains(_searchQuery)).toList();
    if (filtered.isEmpty) return _emptyView('No images shared in this channel');

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final url = filtered[index];
        return GestureDetector(
          onTap: () => _showImageZoom(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab() {
    final filtered = _videoUrls.where((url) => _searchQuery.isEmpty || url.toLowerCase().contains(_searchQuery)).toList();
    if (filtered.isEmpty) return _emptyView('No videos shared in this channel');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final url = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(FlickoColors.bgTertiary), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.video_file_rounded, color: Colors.purpleAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(url, style: GoogleFonts.inter(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.play_circle_fill_rounded, color: Color(FlickoColors.brandLime)), onPressed: () {}),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    final filtered = _links.where((url) => _searchQuery.isEmpty || url.toLowerCase().contains(_searchQuery)).toList();
    if (filtered.isEmpty) return _emptyView('No web links shared in this channel');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final url = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(FlickoColors.bgTertiary), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(url, style: GoogleFonts.inter(color: const Color(FlickoColors.brandLime), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    final filtered = _files.where((f) => _searchQuery.isEmpty || (f['name'] as String).toLowerCase().contains(_searchQuery)).toList();
    if (filtered.isEmpty) return _emptyView('No documents shared in this channel');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final f = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(FlickoColors.bgTertiary), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(f['name'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
              const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioTab() {
    final filtered = _audioUrls.where((url) => _searchQuery.isEmpty || url.toLowerCase().contains(_searchQuery)).toList();
    if (filtered.isEmpty) return _emptyView('No voice notes or audio shared in this channel');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final url = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(FlickoColors.bgTertiary), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.audiotrack_rounded, color: Color(FlickoColors.brandLime), size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text('Voice Note / Audio Track #${index + 1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
              const Icon(Icons.play_arrow_rounded, color: Color(FlickoColors.brandLime), size: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyView(String text) {
    return Center(
      child: Text(text, style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
    );
  }
}
