import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/profile/presentation/profile_semantics.dart';

void main() {
  final source = File(
    'lib/features/profile/presentation/profile_screen.dart',
  ).readAsStringSync();

  test('equipment slot labels include slot, item, state, and action', () {
    expect(
      profileEquipmentSlotSemanticsLabel(
        slotLabel: '魚竿',
        equippedItemName: '海風竿',
        selected: true,
      ),
      '魚竿裝備槽，已裝備海風竿，已選取，點擊更換',
    );
    expect(
      profileEquipmentSlotSemanticsLabel(
        slotLabel: '帽子',
        selected: false,
      ),
      '帽子裝備槽，未裝備，未選取，點擊更換',
    );
  });

  test('profile equipment entry points expose the shared semantics helper', () {
    expect(source, contains('profileEquipmentSlotSemanticsLabel'));
    expect(source, contains('excludeSemantics: true'));
    expect(source, contains('class _EquipmentSlotDef'));
  });

  test('profile shop routes expose an explicit Web back action', () {
    expect(source, contains('_profileShopAppBar'));
    expect(source, contains("tooltip: '返回'"));
    expect(source, contains('Navigator.of(routeContext).pop()'));
  });
}
