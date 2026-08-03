import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web secondary-screen smoke covers accessible navigation', () {
    final source = File('tool/web_secondary_screen_smoke.js').readAsStringSync();
    final workflow =
        File('.github/workflows/web-production-smoke.yml').readAsStringSync();

    expect(source, contains("entry: '帳戶'"));
    expect(source, contains("entry: '圖鑑'"));
    expect(source, contains("entry: '上魚獲'"));
    expect(source, contains("entry: '排行'"));
    expect(source, contains("getByRole('button', {name: screen.entry"));
    expect(source, contains("stableRole: 'progressbar'"));
    expect(source, contains("stableRole: 'checkbox'"));
    expect(source, contains("stableName: '全部'"));
    expect(source, contains("stableRole: 'group'"));
    expect(source, contains('真實捕獲排行榜，共 \\d+ 項'));
    expect(source, contains("getByRole('button', {name: '返回地圖'"));
    expect(source, contains('openProfileShopFromMap'));
    expect(source, contains("shop: '裝備商店'"));
    expect(source, contains("shop: '釣魚道具商城'"));
    expect(source, contains('shop.match || shop.stable'));
    expect(source, contains("match: '可購買並裝備到外圍裝備槽'"));
    expect(source, contains("match: '魚餌、誘餌、探測器與掃描券'"));
    expect(source, contains("stableRole: 'button'"));
    expect(source, contains("stableName: '購買'"));
    expect(source, contains('stableName: /金幣/'));
    expect(source, contains('可購買並裝備到外圍裝備槽'));
    expect(source, contains('魚餌、誘餌、探測器與掃描券'));
    expect(source, contains("getByRole('button', {name: '返回'"));
    expect(source, contains('output/playwright/web-secondary-'));
    expect(workflow, contains('tool/web_secondary_screen_smoke.js'));
    expect(workflow, contains('tmp/web-secondary-screen-smoke.json'));
  });
}
