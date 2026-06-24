import 'package:latlong2/latlong.dart';

class BoatVendor {
  final String id;
  final String name;
  final String zoneName;
  final List<String> dialogues;
  final int priceCoins;
  final List<String> spotNames;
  final List<LatLng> spotLocations; // 5 spots

  const BoatVendor({
    required this.id,
    required this.name,
    required this.zoneName,
    required this.dialogues,
    required this.priceCoins,
    required this.spotNames,
    required this.spotLocations,
  });
}

const kBoatVendors = [
  BoatVendor(
    id: '4sea',
    name: '4Sea',
    zoneName: '東水一帶',
    dialogues: ['大過細個條', '依度新鮮架', '收起，車前少少', '收起，車返後少少', '落得'],
    priceCoins: 100,
    spotNames: ['中環10號碼頭', '九龍公眾碼頭', '糖水道碼頭', '三家村碼頭', '蒲苔群島'],
    spotLocations: [
      LatLng(22.285370343, 114.162900169), // 中環10號碼頭
      LatLng(22.293003496, 114.170314350), // 九龍公眾碼頭
      LatLng(22.293670445, 114.198504994), // 糖水道碼頭
      LatLng(22.291001000, 114.236315000), // 三家村碼頭
      LatLng(22.180357588, 114.265906562), // 蒲苔群島
    ],
  ),
  BoatVendor(
    id: 'howdee',
    name: '豪Dee',
    zoneName: '青馬一帶',
    dialogues: ['唉，收收收', '唉，試試'],
    priceCoins: 150,
    spotNames: ['荃灣渡輪碼頭', '大排咀碼頭', '交椅洲', '大排咀碼頭', '交椅洲'],
    spotLocations: [
      LatLng(22.366724837, 114.110725295), // 荃灣渡輪碼頭
      LatLng(22.342467938, 114.060985515), // 大排咀碼頭
      LatLng(22.284023430, 114.076753415), // 交椅洲
      LatLng(22.342467938, 114.060985515), // 大排咀碼頭
      LatLng(22.284023430, 114.076753415), // 交椅洲
    ],
  ),
];
