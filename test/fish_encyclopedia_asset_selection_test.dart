import 'package:flutter_test/flutter_test.dart';

import 'package:fishergo/features/fish/domain/fish_collection_status.dart';
import 'package:fishergo/features/fish/presentation/fish_encyclopedia_screen.dart';

void main() {
  test('catalog artwork cache size follows the card display density', () {
    expect(fishCatalogArtworkCacheWidth(1), 180);
    expect(fishCatalogArtworkCacheWidth(2), 300);
    expect(fishCatalogArtworkCacheWidth(4), 480);
  });

  test('locked encyclopedia cards do not decode the full fish image', () {
    expect(
      fishArtworkAssetPath(
        discovered: false,
        imagePath: 'assets/fish/mobile_webp/fish-001.webp',
        silhouettePath: 'assets/fish/icons/locked_silhouette.png',
      ),
      'assets/fish/icons/locked_silhouette.png',
    );
  });

  test('discovered encyclopedia cards use their color image', () {
    expect(
      fishArtworkAssetPath(
        discovered: true,
        imagePath: 'assets/fish/mobile_webp/fish-001.webp',
        silhouettePath: 'assets/fish/icons/locked_silhouette.png',
      ),
      'assets/fish/mobile_webp/fish-001.webp',
    );
  });

  test('specific silhouettes remain available for locked cards', () {
    expect(
      fishArtworkAssetPath(
        discovered: false,
        imagePath: 'assets/fish/mobile_webp/fish-001.webp',
        silhouettePath: 'assets/fish/icons/silhouettes/fish-001.png',
      ),
      'assets/fish/icons/silhouettes/fish-001.png',
    );
  });

  test('catalog cards prefer transparent fish art over badge artwork', () {
    expect(
      fishCatalogArtworkAssetPath(
        discovered: true,
        imagePath:
            'assets/fish/mobile_webp/003_hk-goldlined-seabream-badge.webp',
        silhouettePath: 'assets/fish/icons/locked_silhouette.png',
      ),
      'assets/fish/mobile_webp/003_hk-goldlined-seabream.webp',
    );
  });

  test('local badge art falls back to the numbered transparent asset', () {
    expect(
      fishCatalogArtworkAssetPath(
        discovered: true,
        imagePath: 'assets/fish/mobile_webp/059_hk-goatfish-local-badge.webp',
        silhouettePath: 'assets/fish/icons/locked_silhouette.png',
      ),
      'assets/fish/mobile_webp/059.webp',
    );
  });

  test('encyclopedia card semantics expose the discovery stage', () {
    expect(
      fishEncyclopediaCardSemanticsLabel(
        numberLabel: '#001',
        displayName: '黃腳鱲',
        status: FishDiscoveryStatus.unknown,
      ),
      '魚種 #001，名稱未知，未發現',
    );
    expect(
      fishEncyclopediaCardSemanticsLabel(
        numberLabel: '#002',
        displayName: '烏頭',
        status: FishDiscoveryStatus.gameCaught,
      ),
      '魚種 #002，烏頭，遊戲釣獲 · 全彩圖示',
    );
    expect(
      fishEncyclopediaCardSemanticsLabel(
        numberLabel: '#003',
        displayName: '班類',
        status: FishDiscoveryStatus.verifiedRealCatch,
        hasPhotoProof: true,
      ),
      '魚種 #003，班類，真實釣獲 · 魚鈎認證，已附真實魚獲相片',
    );
  });
}
