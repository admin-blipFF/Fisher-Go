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
  final osmCoastlineImport = osmVectorCacheJson == null
      ? null
      : _cacheMetadata(osmVectorCacheJson, 'osmCoastlineImport');
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
    'schemaVersion': 3,
    'name': 'FisherGo Hong Kong terrain MVP',
    'generatedFrom': [
      _sourcePath,
      if (osmVectorCacheJson != null) _osmVectorCachePath,
      if (osmRoadCacheJson != null) _osmRoadCachePath,
    ],
    if (osmVectorCacheJson != null || osmRoadCacheJson != null) ...{
      'attribution': '© OpenStreetMap contributors',
      'license': 'ODbL-1.0',
      'licenseUrl': 'https://www.openstreetmap.org/copyright',
    },
    if (osmCoastlineImport != null) 'osmCoastlineImport': osmCoastlineImport,
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
  final features = <Map<String, Object>>[];
  for (final raw in featuresJson) {
    final feature = _featureFromOsmCache(raw as Map<String, dynamic>);
    if (feature != null) features.add(feature);
  }
  return features;
}

Map<String, Object>? _featureFromOsmCache(Map<String, dynamic> raw) {
  final geometry = raw['geometry'] as Map<String, dynamic>;
  final coordinates = (geometry['coordinates'] as List<dynamic>)
      .map((coordinate) => [
            _round(((coordinate as List<dynamic>)[0] as num).toDouble()),
            _round((coordinate[1] as num).toDouble()),
          ])
      .toList();
  final geometryType = geometry['type'] as String;
  final kind = raw['kind'] as String;
  if (kind == 'building' &&
      (geometryType != 'polygon' || !_isValidPolygon(coordinates))) {
    return null;
  }
  final osmId = (raw['osmId'] as num?)?.toInt();
  final center = _centerOf(coordinates);
  return _feature(
    kind: kind,
    name: raw['name'] as String,
    lat: (raw['lat'] as num?)?.toDouble() ?? center.$1,
    lng: (raw['lng'] as num?)?.toDouble() ?? center.$2,
    radiusMeters: raw['radiusMeters'] as num,
    geometry: {
      'type': geometryType,
      'coordinates': coordinates,
    },
    provenance: osmId != null ? 'openStreetMap' : raw['provenance'] as String?,
    osmId: osmId,
    osmVersion: (raw['osmVersion'] as num?)?.toInt(),
    osmTimestamp: raw['osmTimestamp'] as String?,
    osmNodeIds: (raw['osmNodeIds'] as List<dynamic>?)
        ?.map((id) => (id as num).toInt())
        .toList(growable: false),
    region: raw['region'] as String?,
    heightMeters: (raw['heightMeters'] as num?)?.toDouble(),
    roadClass: raw['roadClass'] as String?,
    isBridge: raw['isBridge'] as bool?,
    lanes: (raw['lanes'] as num?)?.toInt(),
  );
}

Map<String, dynamic>? _cacheMetadata(String sourceJson, String key) {
  final decoded = jsonDecode(sourceJson) as Map<String, dynamic>;
  final value = decoded[key];
  return value is Map<String, dynamic> ? value : null;
}

bool _isValidPolygon(List<List<double>> coordinates) =>
    coordinates.length >= 4 &&
    coordinates.first[0] == coordinates.last[0] &&
    coordinates.first[1] == coordinates.last[1];

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
            [22.360, 114.096],
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
            [22.485, 114.190],
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
            [22.402, 114.248],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '維多利亞港',
        lat: 22.313,
        lng: 114.184,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.345, 114.108],
            [22.332, 114.136],
            [22.316, 114.158],
            [22.294, 114.176],
            [22.280, 114.199],
            [22.288, 114.225],
            [22.305, 114.243],
            [22.326, 114.247],
            [22.343, 114.232],
            [22.337, 114.207],
            [22.333, 114.181],
            [22.340, 114.153],
            [22.350, 114.128],
            [22.345, 114.108],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '維港西部及昂船洲海面',
        lat: 22.333,
        lng: 114.118,
        radiusMeters: 1,
        geometry: {
          'type': 'polygon',
          'coordinates': [
            [22.365, 114.083],
            [22.350, 114.111],
            [22.330, 114.123],
            [22.312, 114.112],
            [22.305, 114.089],
            [22.323, 114.072],
            [22.365, 114.083],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '城門河',
        lat: 22.383,
        lng: 114.174,
        radiusMeters: 1,
        geometry: {
          'type': 'lineString',
          'coordinates': [
            [22.402, 114.171],
            [22.395, 114.172],
            [22.388, 114.174],
            [22.382, 114.175],
            [22.374, 114.175],
            [22.368, 114.177],
            [22.360, 114.178],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '屯門河',
        lat: 22.394,
        lng: 113.973,
        radiusMeters: 1,
        geometry: {
          'type': 'lineString',
          'coordinates': [
            [22.414, 113.968],
            [22.407, 113.970],
            [22.399, 113.971],
            [22.391, 113.974],
            [22.382, 113.977],
            [22.374, 113.978],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '元朗河及錦田河',
        lat: 22.451,
        lng: 114.040,
        radiusMeters: 1,
        geometry: {
          'type': 'lineString',
          'coordinates': [
            [22.481, 114.055],
            [22.472, 114.051],
            [22.463, 114.047],
            [22.454, 114.042],
            [22.445, 114.036],
            [22.437, 114.029],
            [22.429, 114.021],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '大埔河及林村河',
        lat: 22.458,
        lng: 114.176,
        radiusMeters: 1,
        geometry: {
          'type': 'lineString',
          'coordinates': [
            [22.489, 114.155],
            [22.480, 114.161],
            [22.471, 114.168],
            [22.463, 114.175],
            [22.455, 114.181],
            [22.447, 114.187],
          ],
        },
      ),
      _feature(
        kind: 'water',
        name: '梅窩河',
        lat: 22.265,
        lng: 113.999,
        radiusMeters: 1,
        geometry: {
          'type': 'lineString',
          'coordinates': [
            [22.282, 113.991],
            [22.276, 113.994],
            [22.270, 113.997],
            [22.264, 114.000],
            [22.257, 114.002],
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
  String? provenance,
  int? osmId,
  int? osmVersion,
  String? osmTimestamp,
  List<int>? osmNodeIds,
  String? region,
  double? heightMeters,
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
      if (provenance != null) 'provenance': provenance,
      if (osmId != null) 'osmId': osmId,
      if (osmVersion != null) 'osmVersion': osmVersion,
      if (osmTimestamp != null) 'osmTimestamp': osmTimestamp,
      if (osmNodeIds != null) 'osmNodeIds': osmNodeIds,
      if (region != null) 'region': region,
      if (heightMeters != null) 'heightMeters': _round(heightMeters),
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
