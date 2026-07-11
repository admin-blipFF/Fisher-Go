import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _sourcePath = 'data/hk_geo/hk_fishing_spots_master_all_geocoded_gov.csv';
const _osmVectorCachePath = 'data/hk_geo/osm_vector_cache.json';
const _osmRoadCachePath = 'data/hk_geo/osm_road_geometry_cache.json';
const _outputPath = 'assets/maps/hk_terrain_mvp.json';

Map<String, Object> buildTerrainAsset({
  required String sourceCsv,
  String? osmVectorCacheJson,
  String? osmRoadCacheJson,
}) {
  final features = <Map<String, Object>>[
    if (osmVectorCacheJson != null)
      ..._featuresFromOsmVectorCache(osmVectorCacheJson),
    if (osmRoadCacheJson != null)
      ..._featuresFromOsmVectorCache(osmRoadCacheJson),
    ..._manualGameplayFeatures,
    ..._featuresFromCsv(sourceCsv),
  ];
  final uniqueFeatures = <String, Map<String, Object>>{};
  for (final feature in features) {
    final osmId = feature['osmId'];
    final key =
        osmId == null ? '${feature['kind']}|${feature['name']}' : 'osm|$osmId';
    uniqueFeatures[key] = feature;
  }

  return {
    'schemaVersion': 2,
    'name': 'FisherGo Hong Kong terrain MVP',
    'generatedFrom': [
      _sourcePath,
      if (osmVectorCacheJson != null) _osmVectorCachePath,
      if (osmRoadCacheJson != null) _osmRoadCachePath,
    ],
    if (osmRoadCacheJson != null) ...{
      'attribution': '© OpenStreetMap contributors',
      'license': 'ODbL-1.0',
      'licenseUrl': 'https://www.openstreetmap.org/copyright',
    },
    'features': uniqueFeatures.values.toList(),
  };
}

void writeTerrainAsset({
  required File source,
  required File output,
}) {
  final cache = File(_osmVectorCachePath);
  final roadCache = File(_osmRoadCachePath);
  final asset = buildTerrainAsset(
    sourceCsv: source.readAsStringSync(),
    osmVectorCacheJson: cache.existsSync() ? cache.readAsStringSync() : null,
    osmRoadCacheJson:
        roadCache.existsSync() ? roadCache.readAsStringSync() : null,
  );
  const encoder = JsonEncoder.withIndent('  ');
  output.writeAsStringSync('${encoder.convert(asset)}\n');
}

void main() {
  writeTerrainAsset(
    source: File(_sourcePath),
    output: File(_outputPath),
  );
  stdout.writeln('Generated $_outputPath from $_sourcePath');
}

List<Map<String, Object>> _featuresFromOsmVectorCache(String sourceJson) {
  final decoded = jsonDecode(sourceJson) as Map<String, dynamic>;
  final featuresJson = decoded['features'] as List<dynamic>? ?? const [];
  return [
    for (final raw in featuresJson)
      _featureFromOsmCache(raw as Map<String, dynamic>),
  ];
}

Map<String, Object> _featureFromOsmCache(Map<String, dynamic> raw) {
  final geometry = raw['geometry'] as Map<String, dynamic>;
  final coordinates = (geometry['coordinates'] as List<dynamic>)
      .map((coordinate) => [
            _round(((coordinate as List<dynamic>)[0] as num).toDouble()),
            _round((coordinate[1] as num).toDouble()),
          ])
      .toList();
  final center = _centerOf(coordinates);
  return _feature(
    kind: raw['kind'] as String,
    name: raw['name'] as String,
    lat: (raw['lat'] as num?)?.toDouble() ?? center.$1,
    lng: (raw['lng'] as num?)?.toDouble() ?? center.$2,
    radiusMeters: raw['radiusMeters'] as num,
    geometry: {
      'type': geometry['type'] as String,
      'coordinates': coordinates,
    },
    osmId: (raw['osmId'] as num?)?.toInt(),
    region: raw['region'] as String?,
    roadClass: raw['roadClass'] as String?,
    isBridge: raw['isBridge'] as bool?,
    lanes: (raw['lanes'] as num?)?.toInt(),
  );
}

List<Map<String, Object>> _featuresFromCsv(String sourceCsv) {
  final rows = _parseCsv(sourceCsv);
  if (rows.isEmpty) return const [];
  final header = rows.first;
  final features = <Map<String, Object>>[];

  for (final row in rows.skip(1)) {
    final record = _record(header, row);
    final type = record['type'];
    final lat = double.tryParse(record['lat'] ?? '');
    final lng = double.tryParse(record['lon'] ?? '');
    final name = record['name_zh'] ?? record['name'] ?? '';
    if (type == null || name.isEmpty || lat == null || lng == null) continue;
    if (!_isHongKongCoordinate(lat, lng)) continue;

    if (type == 'pier') {
      features.add(_feature(
        kind: 'pier',
        name: name,
        lat: lat,
        lng: lng,
        radiusMeters: 420,
      ));
    } else if (type == 'island') {
      final sourceRadius = double.tryParse(record['radius_meters'] ?? '');
      features.add(_feature(
        kind: 'land',
        name: name,
        lat: lat,
        lng: lng,
        radiusMeters: math.max(900, (sourceRadius ?? 250) * 4),
      ));
    }
  }

  features.sort((a, b) {
    final kindCompare = (a['kind'] as String).compareTo(b['kind'] as String);
    if (kindCompare != 0) return kindCompare;
    return (a['name'] as String).compareTo(b['name'] as String);
  });
  return features;
}

List<Map<String, Object>> get _manualGameplayFeatures => [
      _feature(
        kind: 'water',
        name: '汲水門至青衣海面',
        lat: 22.342,
        lng: 114.073,
        radiusMeters: 6800,
      ),
      _feature(
        kind: 'road',
        name: '青馬大橋',
        lat: 22.3517,
        lng: 114.0743,
        radiusMeters: 1050,
      ),
      _feature(
        kind: 'fishingNode',
        name: '青馬橋底石駁',
        lat: 22.3479,
        lng: 114.0718,
        radiusMeters: 620,
      ),
      _feature(
        kind: 'water',
        name: '東涌機場跑道尾外海',
        lat: 22.291,
        lng: 113.936,
        radiusMeters: 7200,
      ),
      _feature(
        kind: 'land',
        name: '赤鱲角跑道',
        lat: 22.305,
        lng: 113.929,
        radiusMeters: 4300,
      ),
      _feature(
        kind: 'road',
        name: '機場跑道尾道路',
        lat: 22.298,
        lng: 113.929,
        radiusMeters: 900,
      ),
      _feature(
        kind: 'fishingNode',
        name: '跑道尾立魚位',
        lat: 22.286,
        lng: 113.942,
        radiusMeters: 780,
      ),
      _feature(
        kind: 'water',
        name: '三門仔大埔內海',
        lat: 22.462,
        lng: 114.215,
        radiusMeters: 5600,
      ),
      _feature(
        kind: 'fishingNode',
        name: '三門仔烏頭位',
        lat: 22.461,
        lng: 114.211,
        radiusMeters: 680,
      ),
      _feature(
        kind: 'water',
        name: '東水赤立雞魚帶',
        lat: 22.31,
        lng: 114.34,
        radiusMeters: 8600,
      ),
      _feature(
        kind: 'fishingNode',
        name: '東水池仔赤立雞魚位',
        lat: 22.302,
        lng: 114.335,
        radiusMeters: 750,
      ),
      _feature(
        kind: 'water',
        name: '離島外海',
        lat: 22.245,
        lng: 114.02,
        radiusMeters: 10400,
      ),
      _feature(
        kind: 'water',
        name: '維多利亞港海面',
        lat: 22.2936,
        lng: 114.1698,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.315, 114.122],
            [22.309, 114.208],
            [22.289, 114.238],
            [22.271, 114.205],
            [22.279, 114.142],
            [22.292, 114.119],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '藍巴勒海峽',
        lat: 22.3332,
        lng: 114.1112,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.360, 114.096],
            [22.357, 114.129],
            [22.321, 114.128],
            [22.304, 114.110],
            [22.321, 114.094],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '吐露港海面',
        lat: 22.4489,
        lng: 114.2261,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.485, 114.190],
            [22.480, 114.256],
            [22.441, 114.279],
            [22.419, 114.236],
            [22.424, 114.191],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '西貢內海',
        lat: 22.358,
        lng: 114.292,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.402, 114.248],
            [22.394, 114.333],
            [22.339, 114.354],
            [22.312, 114.292],
            [22.338, 114.238],
          ],
        },
      ),
      _feature(
        kind: 'fishingNode',
        name: '離島岩位',
        lat: 22.216,
        lng: 114.037,
        radiusMeters: 780,
      ),
    ];

Map<String, Object> _feature({
  required String kind,
  required String name,
  required double lat,
  required double lng,
  required num radiusMeters,
  Map<String, Object>? geometry,
  int? osmId,
  String? region,
  String? roadClass,
  bool? isBridge,
  int? lanes,
}) =>
    {
      'kind': kind,
      'name': name,
      'lat': _round(lat),
      'lng': _round(lng),
      'radiusMeters': radiusMeters.round(),
      if (geometry != null) 'geometry': geometry,
      if (osmId != null) 'osmId': osmId,
      if (region != null) 'region': region,
      if (roadClass != null) 'roadClass': roadClass,
      if (isBridge != null) 'isBridge': isBridge,
      if (lanes != null) 'lanes': lanes,
    };

(double, double) _centerOf(List<List<double>> coordinates) {
  if (coordinates.isEmpty) return (0, 0);
  final lat =
      coordinates.map((coordinate) => coordinate[0]).reduce((a, b) => a + b) /
          coordinates.length;
  final lng =
      coordinates.map((coordinate) => coordinate[1]).reduce((a, b) => a + b) /
          coordinates.length;
  return (_round(lat), _round(lng));
}

Map<String, String> _record(List<String> header, List<String> row) {
  final result = <String, String>{};
  for (var i = 0; i < header.length && i < row.length; i++) {
    result[header[i]] = row[i];
  }
  return result;
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  final row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (char == '"') {
      final isEscapedQuote =
          inQuotes && i + 1 < source.length && source[i + 1] == '"';
      if (isEscapedQuote) {
        field.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      row.add(field.toString());
      field.clear();
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(List.of(row));
      row.clear();
    } else {
      field.write(char);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(List.of(row));
  }
  return rows;
}

bool _isHongKongCoordinate(double lat, double lng) =>
    lat >= 22.1 && lat <= 22.6 && lng >= 113.8 && lng <= 114.5;

double _round(double value) => double.parse(value.toStringAsFixed(9));
