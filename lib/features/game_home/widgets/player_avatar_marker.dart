import 'package:flutter/material.dart';
import '../../profile/presentation/profile_screen.dart';

/// 地圖上的玩家頭像標記
class PlayerAvatarMarker extends StatelessWidget {
  const PlayerAvatarMarker({super.key, required this.equipped});

  final Map<String, String> equipped;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.cyanAccent.withValues(alpha: 0.85),
                Colors.blueAccent.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.cyanAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: AvatarLayeredPreview(
              avatarState: AvatarProfileViewState.fromEquipped(equipped),
              size: 38,
            ),
          ),
        ),
      ],
    );
  }
}