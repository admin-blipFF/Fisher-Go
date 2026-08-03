String profileEquipmentSlotSemanticsLabel({
  required String slotLabel,
  String? equippedItemName,
  required bool selected,
}) {
  final equipment = equippedItemName == null ? '未裝備' : '已裝備$equippedItemName';
  final selection = selected ? '已選取' : '未選取';
  return '$slotLabel裝備槽，$equipment，$selection，點擊更換';
}
