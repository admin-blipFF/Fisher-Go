class GameShopItem {
  const GameShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.icon,
    this.defaultQuantity = 0,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String category;
  final String icon;
  final int defaultQuantity;
}

const gameShopItems = <GameShopItem>[
  GameShopItem(
    id: 'basic_bait',
    name: '普通魚餌',
    description: '在釣點進行一次虛擬釣魚。適合新手刷圖鑑灰章。',
    price: 20,
    category: '魚餌',
    icon: '🪱',
    defaultQuantity: 10,
  ),
  GameShopItem(
    id: 'harbor_lure',
    name: '碼頭誘餌',
    description: '提升普通及中等稀有魚出現率，適合碼頭釣點。',
    price: 80,
    category: '誘餌',
    icon: '🎣',
  ),
  GameShopItem(
    id: 'island_lure',
    name: '離島誘餌',
    description: '提升高稀有度魚種出現率，適合海島釣點。',
    price: 120,
    category: '誘餌',
    icon: '🏝️',
  ),
  GameShopItem(
    id: 'fish_detector',
    name: '魚群探測器',
    description: '預覽附近釣點可能出現的魚類，不直接解鎖圖鑑。',
    price: 150,
    category: '探測',
    icon: '📡',
  ),
  GameShopItem(
    id: 'scan_pass',
    name: '真實捕獲掃描券',
    description: '預留給相片驗證/AI辨識流程；MVP 先作活動道具。',
    price: 200,
    category: '驗證',
    icon: '📷',
  ),
];

final gameShopItemById = {for (final item in gameShopItems) item.id: item};
