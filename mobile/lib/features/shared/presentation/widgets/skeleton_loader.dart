import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
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
                Row(
                  children: [
                    const Skeleton(width: 120, height: 14),
                    const SizedBox(width: 8),
                    const Skeleton(width: 60, height: 10),
                  ],
                ),
                const SizedBox(height: 6),
                const Skeleton(width: 300, height: 14),
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
    return Column(
      children: [
        const Skeleton(width: double.infinity, height: 120, borderRadius: 0),
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(width: 160, height: 20),
              const SizedBox(height: 8),
              const Skeleton(width: 100, height: 14),
              const SizedBox(height: 16),
              const Skeleton(width: 300, height: 14),
              const SizedBox(height: 4),
              const Skeleton(width: 250, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class ServerSkeleton extends StatelessWidget {
  const ServerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Skeleton(width: double.infinity, height: 100, borderRadius: 12),
          const SizedBox(height: 16),
          Row(
            children: [
              const Skeleton(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(width: 140, height: 16),
                    const SizedBox(height: 6),
                    const Skeleton(width: 80, height: 12),
                  ],
                ),
              ),
            ],
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
                  Skeleton(width: 50 + (index * 20), height: 14),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
