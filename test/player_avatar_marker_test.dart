import 'package:fishergo/features/game_home/widgets/player_avatar_marker.dart';
import 'package:fishergo/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('map marker shows the selected full-body avatar', (tester) async {
    final avatarState = AvatarProfileViewState.initial().copyWith(
      selectedGender: 'female',
      selectedPreset: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerAvatarMarker(
            avatarState: avatarState,
            isLiveLocation: true,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ClipOval), findsNothing);
    expect(find.bySemanticsLabel('玩家位置，GPS 已定位'), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/avatar/layers/body_female_map.png');
  });
}
