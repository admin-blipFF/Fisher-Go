import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';

/// 地圖上的玩家頭像標記
class PlayerAvatarMarker extends StatelessWidget {
  const PlayerAvatarMarker({
    super.key,
    required this.avatarState,
    required this.isLiveLocation,
    this.size = 82,
  });

  final AvatarProfileViewState avatarState;
  final bool isLiveLocation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent =
        isLiveLocation ? const Color(0xFF45F4E8) : const Color(0xFFFFB85C);
    return Semantics(
      label: isLiveLocation ? '玩家位置，GPS 已定位' : '玩家位置，等待 GPS 定位',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size * 1.2,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 4,
                child: Container(
                  width: size * 0.54,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF032C35).withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(size),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: size * 0.08,
                child: Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.42),
                        accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: size * 0.10,
                child: Image.asset(
                  avatarMapBodyAssetFor(avatarState),
                  width: size * 0.74,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) return child;
                    return Icon(
                      Icons.person_rounded,
                      color: const Color(0xFFF1FFFD),
                      size: size * 0.58,
                    );
                  },
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: const Color(0xFFF1FFFD),
                    size: size * 0.58,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: size * 0.22,
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF07333D),
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Icon(
                    Icons.navigation_rounded,
                    color: accent,
                    size: size * 0.13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
