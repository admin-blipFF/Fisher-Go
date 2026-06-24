import 'package:flutter/material.dart';
import '../../navigation/game_screen.dart';
import 'map_hud_pill.dart';
import 'game_top_status_bar.dart';
import 'game_side_hud_button.dart';
import 'game_bottom_command_bar.dart';

/// 地圖 HUD 疊加層 — 組合所有遊戲 HUD widgets
class GameHudLayer extends StatelessWidget {
  const GameHudLayer({
    super.key,
    required this.spotsShown,
    required this.spotsTotal,
    required this.checkpoints,
    required this.autoEnabled,
    required this.onToggleAuto,
    required this.hasCurrent,
    required this.pendingCount,
    required this.baitSummary,
    required this.onAddCheckpoint,
    required this.onFishNearby,
    required this.onOpenScreen,
  });

  final int spotsShown;
  final int spotsTotal;
  final int checkpoints;
  final bool autoEnabled;
  final VoidCallback onToggleAuto;
  final bool hasCurrent;
  final int pendingCount;
  final String baitSummary;
  final VoidCallback? onAddCheckpoint;
  final VoidCallback onFishNearby;
  final void Function(GameScreen) onOpenScreen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 頂部狀態列
        Positioned(
          left: 14,
          top: 12,
          right: 14,
          child: GameTopStatusBar(
            spotsShown: spotsShown,
            spotsTotal: spotsTotal,
            checkpoints: checkpoints,
            autoEnabled: autoEnabled,
            onToggleAuto: onToggleAuto,
          ),
        ),
        // 左上角 HUD 膠囊
        Positioned(
          left: 10,
          top: 10,
          child: MapHudPill(
            icon: Icons.radar,
            label: 'FISH RADAR',
            color: Colors.cyanAccent,
          ),
        ),
        // 右上角 HUD 膠囊
        Positioned(
          right: 10,
          top: 10,
          child: MapHudPill(
            icon: Icons.location_searching,
            label: hasCurrent ? 'GPS ON' : 'HK DEMO',
            color: hasCurrent ? Colors.lightGreenAccent : Colors.amberAccent,
          ),
        ),
        // 右側垂直功能按鈕（4個：圖鑑/魚獲/排行/角色）
        Positioned(
          right: 12,
          top: 94,
          child: Column(
            children: [
              _buildSideButton(Icons.menu_book, '圖鑑', GameScreen.encyclopedia),
              const SizedBox(height: 10),
              _buildSideButton(Icons.camera_alt, '魚獲', GameScreen.catchLog),
              const SizedBox(height: 10),
              _buildSideButton(Icons.emoji_events, '排行', GameScreen.leaderboard),
              const SizedBox(height: 10),
              _buildSideButton(Icons.person, '角色', GameScreen.profile),
            ],
          ),
        ),
        // 底部指令列
        Positioned(
          left: 14,
          right: 14,
          bottom: 18,
          child: GameBottomCommandBar(
            hasCurrent: hasCurrent,
            pendingCount: pendingCount,
            baitSummary: baitSummary,
            onAddCheckpoint: onAddCheckpoint,
            onFishNearby: onFishNearby,
          ),
        ),
      ],
    );
  }

  Widget _buildSideButton(IconData icon, String label, GameScreen screen) {
    return GameSideHudButton(
      icon: icon,
      label: label,
      onTap: () => onOpenScreen(screen),
    );
  }
}