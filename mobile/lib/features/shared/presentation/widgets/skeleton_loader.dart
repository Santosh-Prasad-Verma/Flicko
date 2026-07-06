import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Base animated shimmer Skeleton widget.
/// Sweeps a soft lime-green shimmer across a dark container.
class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1200.ms,
          colors: [
            const Color(0xFF1E2620),
            const Color(0xFF2E3D31),
            const Color(0xFF1E2620),
          ],
        );
  }
}

class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 40, height: 40, borderRadius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Skeleton(width: 120, height: 14),
                    SizedBox(width: 8),
                    Skeleton(width: 60, height: 10),
                  ],
                ),
                const SizedBox(height: 6),
                const Skeleton(width: double.infinity, height: 14),
                const SizedBox(height: 4),
                const Skeleton(width: 200, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageListSkeleton extends StatelessWidget {
  final int count;

  const MessageListSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: count,
      itemBuilder: (context, index) => const MessageSkeleton(),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Skeleton(width: double.infinity, height: 140, borderRadius: 0),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(FlickoColors.bgPrimary), width: 4),
                ),
                child: const Skeleton(width: 80, height: 80, borderRadius: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 160, height: 20),
                const SizedBox(height: 8),
                const Skeleton(width: 100, height: 14),
                const SizedBox(height: 16),
                const Skeleton(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                const Skeleton(width: 250, height: 14),
                const SizedBox(height: 24),
                const Skeleton(width: double.infinity, height: 48, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServerSkeleton extends StatelessWidget {
  const ServerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(FlickoColors.border), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner skeleton
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: const Skeleton(
              width: double.infinity,
              height: 120,
              borderRadius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon avatar skeleton
                const Skeleton(
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name skeleton
                      const Skeleton(
                        width: 160,
                        height: 16,
                      ),
                      const SizedBox(height: 6),
                      // Member count skeleton
                      const Skeleton(
                        width: 90,
                        height: 12,
                      ),
                      const SizedBox(height: 12),
                      // Description skeleton line 1
                      const Skeleton(
                        width: double.infinity,
                        height: 12,
                      ),
                      const SizedBox(height: 6),
                      // Description skeleton line 2
                      const Skeleton(
                        width: 200,
                        height: 12,
                      ),
                      const SizedBox(height: 16),
                      // Button skeleton aligned to right
                      Align(
                        alignment: Alignment.centerRight,
                        child: const Skeleton(
                          width: 110,
                          height: 36,
                          borderRadius: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChannelListSkeleton extends StatelessWidget {
  final int count;

  const ChannelListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Skeleton(width: 100, height: 12),
          ),
          ...List.generate(count, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Skeleton(width: 20, height: 20, borderRadius: 4),
                  const SizedBox(width: 8),
                  Skeleton(width: 100.0 + (index % 3) * 30.0, height: 14),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left rail server list
        Container(
          width: 72,
          color: const Color(FlickoColors.bgSecondary),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Skeleton(width: 48, height: 48, borderRadius: 24),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
              const SizedBox(height: 12),
              ...List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Skeleton(width: 48, height: 48, borderRadius: 16),
                ),
              ),
            ],
          ),
        ),
        // Channel list content area
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 16),
            child: ChannelListSkeleton(count: 8),
          ),
        ),
      ],
    );
  }
}

class NotificationSkeleton extends StatelessWidget {
  final int count;

  const NotificationSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Skeleton(width: 40, height: 40, borderRadius: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 180, height: 14),
                      SizedBox(height: 6),
                      Skeleton(width: 120, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Skeleton(width: 30, height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, sectionIndex) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 120, height: 14, margin: EdgeInsets.only(bottom: 12, top: 8)),
            Container(
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: List.generate(3, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Skeleton(width: 24, height: 24, borderRadius: 6),
                        const SizedBox(width: 16),
                        const Expanded(child: Skeleton(width: 140, height: 14)),
                        const Skeleton(width: 16, height: 16, borderRadius: 8),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class DMListSkeleton extends StatelessWidget {
  final int count;

  const DMListSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Skeleton(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Skeleton(width: 100, height: 14),
                        const Skeleton(width: 40, height: 10),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Skeleton(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
