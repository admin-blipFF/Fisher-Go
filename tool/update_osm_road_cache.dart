import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

const osmRoadCacheOutputPath = 'data/hk_geo/osm_road_geometry_cache.json';
const osmAttribution = '© OpenStreetMap contributors';
const osmLicense = 'ODbL-1.0';
const osmLicenseUrl = 'https://www.openstreetmap.org/copyright';

const _regions = <_OsmRoadRegion>[
  _OsmRoadRegion(
    name: 'sha-tin',
    bbox: '114.1814,22.3769,114.1934,22.3869',
  ),
  _OsmRoadRegion(
    name: 'tsing-ma',
    bbox: '114.0640,22.3460,114.0845,22.3585',
  ),
  _OsmRoadRegion(
    name: 'central-harbour',
    bbox: '114.1550,22.2790,114.1700,22.2920',
  ),
  _OsmRoadRegion(
    name: 'north-point',
    bbox: '114.1900,22.2860,114.2050,22.3000',
  ),
  _OsmRoadRegion(
    name: 'aberdeen',
    bbox: '114.1460,22.2390,114.1610,22.2530',
  ),
  _OsmRoadRegion(
    name: 'sai-kung',
    bbox: '114.2670,22.3740,114.2820,22.3890',
  ),
  _OsmRoadRegion(
    name: 'tai-po',
    bbox: '114.1760,22.4350,114.1910,22.4500',
  ),
  _OsmRoadRegion(
    name: 'sam-mun-tsai',
    bbox: '114.2060,22.4480,114.2210,22.4630',
  ),
  _OsmRoadRegion(
    name: 'tung-chung',
    bbox: '113.9270,22.2790,113.9470,22.3000',
  ),
  _OsmRoadRegion(
    name: 'chek-lap-kok-east',
    bbox: '113.9230,22.3070,113.9450,22.3270',
  ),
  _OsmRoadRegion(
    name: 'cheung-chau',
    bbox: '114.0210,22.2010,114.0370,22.2170',
  ),
  _OsmRoadRegion(
    name: 'lamma',
    bbox: '114.1150,22.2010,114.1330,22.2190',
  ),
  _OsmRoadRegion(
    name: 'stanley',
    bbox: '114.2020,22.2100,114.2180,22.2250',
  ),
];

List<String> get osmRoadRegionNames => [
      for (final region in _regions) region.name,
    ];

Map<String, Object?> buildRoadCacheFromOsmXml(
  String source, {
  required String regionName,
}) {
  final document = XmlDocument.parse(source);
  final nodes = <int, (double, double)>{};
  for (final node in document.findAllElements('node')) {
    final id = int.tryParse(node.getAttribute('id') ?? '');
    final lat = double.tryParse(node.getAttribute('lat') ?? '');
    final lon = double.tryParse(node.getAttribute('lon') ?? '');
    if (id != null && lat != null && lon != null) {
      nodes[id] = (lat, lon);
    }
  }

  final features = <Map<String, Object?>>[];
  for (final way in document.findAllElements('way')) {
    final osmId = int.tryParse(way.getAttribute('id') ?? '');
    if (osmId == null) continue;
    final tags = <String, String>{
      for (final tag in way.findElements('tag'))
        if (tag.getAttribute('k') case final key?)
          key: tag.getAttribute('v') ?? '',
    };
    final roadClass = _normalizeRoadClass(tags['highway']);
    if (roadClass == null) continue;

    final name = (tags['name:zh'] ?? tags['name'] ?? '').trim();
    if (_requiresName(roadClass) && name.isEmpty) continue;

    final coordinates = <List<double>>[];
    for (final nd in way.findElements('nd')) {
      final ref = int.tryParse(nd.getAttribute('ref') ?? '');
      final coordinate = ref == null ? null : nodes[ref];
      if (coordinate == null) continue;
      coordinates.add([
        _roundCoordinate(coordinate.$1),
        _roundCoordinate(coordinate.$2),
      ]);
    }
    if (coordinates.length < 2) continue;

    final centerLat =
        coordinates.map((coordinate) => coordinate[0]).reduce((a, b) => a + b) /
            coordinates.length;
    final centerLng =
        coordinates.map((coordinate) => coordinate[1]).reduce((a, b) => a + b) /
            coordinates.length;
    final bridge = tags['bridge'];
    final lanes = _parseLanes(tags['lanes']);

    features.add({
      'kind': 'road',
      'name': name,
      'osmId': osmId,
      'region': regionName,
      'roadClass': roadClass,
      'isBridge': bridge != null && bridge.isNotEmpty && bridge != 'no',
      if (lanes != null) 'lanes': lanes,
      'lat': _roundCoordinate(centerLat),
      'lng': _roundCoordinate(centerLng),
      'radiusMeters': 50,
      'geometry': {
        'type': 'lineString',
        'coordinates': coordinates,
      },
    });
  }
  features.sort(
    (left, right) => (left['osmId']! as int).compareTo(right['osmId']! as int),
  );

  return {
    'schemaVersion': 1,
    'source': osmAttribution,
    'license': osmLicense,
    'licenseUrl': osmLicenseUrl,
    'regions': [regionName],
    'features': features,
  };
}

Future<void> main() async {
  final client = HttpClient()..userAgent = 'FisherGO-map-cache/1.0';
  final merged = <int, Map<String, Object?>>{};
  try {
    for (final region in _regions) {
      final uri = Uri.https(
        'api.openstreetmap.org',
        '/api/0.6/map',
        {'bbox': region.bbox},
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/xml');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'OSM ${region.name} fetch failed with ${response.statusCode}',
          uri: uri,
        );
      }
      final xml = await utf8.decoder.bind(response).join();
      final cache = buildRoadCacheFromOsmXml(
        xml,
        regionName: region.name,
      );
      final features = cache['features']! as List<Map<String, Object?>>;
      for (final feature in features) {
        merged[feature['osmId']! as int] = feature;
      }
      stdout.writeln('${region.name}: ${features.length} road features');
    }
  } finally {
    client.close(force: true);
  }

  final features = merged.values.toList()
    ..sort((left, right) {
      final region =
          (left['region']! as String).compareTo(right['region']! as String);
      if (region != 0) return region;
      return (left['osmId']! as int).compareTo(right['osmId']! as int);
    });
  final output = {
    'schemaVersion': 1,
    'source': osmAttribution,
    'license': osmLicense,
    'licenseUrl': osmLicenseUrl,
    'fetchedAt': DateTime.now().toUtc().toIso8601String(),
    'regions': [for (final region in _regions) region.name],
    'features': features,
  };
  const encoder = JsonEncoder.withIndent('  ');
  final file = File(osmRoadCacheOutputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString('${encoder.convert(output)}\n');
  stdout.writeln('Wrote ${file.path}: ${features.length} road features');
}

String? _normalizeRoadClass(String? highway) {
  return switch (highway) {
    'motorway' || 'motorway_link' => 'motorway',
    'trunk' || 'trunk_link' => 'trunk',
    'primary' || 'primary_link' => 'primary',
    'secondary' || 'secondary_link' => 'secondary',
    'tertiary' || 'tertiary_link' => 'tertiary',
    'residential' || 'unclassified' => 'local',
    'service' => 'service',
    'cycleway' => 'cycleway',
    'pedestrian' || 'footway' || 'path' => 'footway',
    _ => null,
  };
}

bool _requiresName(String roadClass) =>
    roadClass == 'local' ||
    roadClass == 'service' ||
    roadClass == 'footway' ||
    roadClass == 'cycleway';

int? _parseLanes(String? value) {
  if (value == null) return null;
  for (final part in value.split(RegExp(r'[^0-9]+'))) {
    final lanes = int.tryParse(part);
    if (lanes != null && lanes > 0) return lanes;
  }
  return null;
}

double _roundCoordinate(double value) =>
    (value * 10000000).roundToDouble() / 10000000;

class _OsmRoadRegion {
  const _OsmRoadRegion({required this.name, required this.bbox});

  final String name;
  final String bbox;
}
