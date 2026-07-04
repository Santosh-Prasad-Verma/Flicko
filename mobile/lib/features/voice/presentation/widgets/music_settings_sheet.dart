import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/audio_effects_service.dart';
import '../../data/sleep_timer_service.dart';

/// Music settings bottom sheet
class MusicSettingsSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPause;
  final VoidCallback? onStop;

  const MusicSettingsSheet({
    super.key,
    this.onPause,
    this.onStop,
  });

  @override
  ConsumerState<MusicSettingsSheet> createState() => _MusicSettingsSheetState();
}

class _MusicSettingsSheetState extends ConsumerState<MusicSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF52B788);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audio Settings',
                  style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: _neon,
            labelColor: _white,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 11),
            tabs: const [
              Tab(text: 'EQUALIZER'),
              Tab(text: 'EFFECTS'),
              Tab(text: 'SLEEP'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EqualizerTab(),
                _EffectsTab(),
                _SleepTimerTab(
                  onPause: widget.onPause,
                  onStop: widget.onStop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(audioEffectsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Equalizer', style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontSize: 16, fontWeight: FontWeight.w600)),
              Switch(
                value: effects.eqEnabled,
                onChanged: (v) => ref.read(audioEffectsProvider.notifier).setEqEnabled(v),
                activeThumbColor: const Color(0xFF52B788),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Presets
          Text('Presets', style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EqPreset.builtIn.map((preset) {
              final isActive = effects.activePresetId == preset.id;
              return GestureDetector(
                onTap: effects.eqEnabled
                    ? () => ref.read(audioEffectsProvider.notifier).setPreset(preset.id)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF52B788) : const Color(0xFF050505),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? const Color(0xFF52B788) : const Color(0xFF71717A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    preset.name,
                    style: GoogleFonts.inter(
                      color: isActive ? Colors.black : const Color(0xFFFBF9FA),
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Frequency bands
          if (effects.eqEnabled) ...[
            Text('Frequency Bands', style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: effects.bands.asMap().entries.map((entry) {
                  final band = entry.value;
                  return _BandSlider(
                    frequency: '${band.frequency.round()}',
                    gain: band.gain,
                    onChanged: (gain) => ref.read(audioEffectsProvider.notifier).setBandGain(band.index, gain),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Reset button
          Center(
            child: TextButton(
              onPressed: () => ref.read(audioEffectsProvider.notifier).resetAll(),
              child: Text('Reset to Default', style: GoogleFonts.inter(color: const Color(0xFF52B788))),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String frequency;
  final double gain;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.frequency,
    required this.gain,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${gain > 0 ? '+' : ''}${gain.round()}',
          style: GoogleFonts.robotoMono(color: const Color(0xFFFBF9FA), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: gain,
                min: -12,
                max: 12,
                divisions: 24,
                activeColor: const Color(0xFF52B788),
                inactiveColor: const Color(0xFF71717A).withValues(alpha: 0.3),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          frequency,
          style: GoogleFonts.robotoMono(color: const Color(0xFF71717A), fontSize: 9),
        ),
      ],
    );
  }
}

class _EffectsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(audioEffectsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _EffectSlider(
            title: 'Bass Boost',
            subtitle: 'Enhance low frequencies',
            icon: Icons.graphic_eq,
            value: effects.bassBoost,
            onChanged: (v) => ref.read(audioEffectsProvider.notifier).setBassBoost(v),
          ),
          const SizedBox(height: 16),
          _EffectSlider(
            title: 'Surround Sound',
            subtitle: '3D audio experience',
            icon: Icons.surround_sound,
            value: effects.surround,
            onChanged: (v) => ref.read(audioEffectsProvider.notifier).setSurround(v),
          ),
          const SizedBox(height: 16),
          _EffectSlider(
            title: 'Virtualizer',
            subtitle: 'Spatial audio effect',
            icon: Icons.threed_rotation,
            value: effects.virtualizer,
            onChanged: (v) => ref.read(audioEffectsProvider.notifier).setVirtualizer(v),
          ),
          const SizedBox(height: 16),
          _EffectSlider(
            title: 'Loudness Enhancer',
            subtitle: 'Boost overall volume',
            icon: Icons.volume_up,
            value: effects.loudnessEnhancer,
            onChanged: (v) => ref.read(audioEffectsProvider.notifier).setLoudnessEnhancer(v),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => ref.read(audioEffectsProvider.notifier).resetAll(),
              child: Text('Reset All Effects', style: GoogleFonts.inter(color: const Color(0xFF52B788))),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectSlider extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _EffectSlider({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF52B788), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontWeight: FontWeight.w600)),
                    Text(subtitle, style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 11)),
                  ],
                ),
              ),
              Text('${value.round()}%', style: GoogleFonts.robotoMono(color: const Color(0xFF52B788), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              activeColor: const Color(0xFF52B788),
              inactiveColor: const Color(0xFF71717A).withValues(alpha: 0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepTimerTab extends ConsumerWidget {
  final VoidCallback? onPause;
  final VoidCallback? onStop;

  const _SleepTimerTab({
    this.onPause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timerState.isActive) ...[
            // Active timer display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF52B788).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF52B788).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Sleep Timer Active',
                    style: GoogleFonts.inter(color: const Color(0xFF52B788), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (timerState.remaining != null)
                    Text(
                      _formatDuration(timerState.remaining!),
                      style: GoogleFonts.robotoMono(color: const Color(0xFFFBF9FA), fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => notifier.extend(const Duration(minutes: 5)),
                        child: Text('+5 min', style: GoogleFonts.inter(color: const Color(0xFF52B788))),
                      ),
                      ElevatedButton(
                        onPressed: () => notifier.stop(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Quick presets
          Text('Set Sleep Timer', style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TimerPreset(label: '5 min', duration: const Duration(minutes: 5)),
              _TimerPreset(label: '15 min', duration: const Duration(minutes: 15)),
              _TimerPreset(label: '30 min', duration: const Duration(minutes: 30)),
              _TimerPreset(label: '45 min', duration: const Duration(minutes: 45)),
              _TimerPreset(label: '1 hour', duration: const Duration(hours: 1)),
              _TimerPreset(label: '2 hours', duration: const Duration(hours: 2)),
            ],
          ),
          const SizedBox(height: 24),
          // After current track
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.skip_next, color: Color(0xFF52B788)),
              title: Text('After Current Track', style: GoogleFonts.inter(color: const Color(0xFFFBF9FA))),
              subtitle: Text('Stop playback when current song ends', style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 11)),
              onTap: () {
                notifier.startAfterTrack(SleepTimerAction.pause);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TimerPreset extends ConsumerWidget {
  final String label;
  final Duration duration;

  const _TimerPreset({
    required this.label,
    required this.duration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(sleepTimerProvider.notifier).start(duration, SleepTimerAction.pause);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF71717A).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(color: const Color(0xFFFBF9FA), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
