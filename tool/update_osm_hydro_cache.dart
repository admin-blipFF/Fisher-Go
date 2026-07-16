import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const osmHydroCacheOutputPath = 'data/hk_geo/osm_hydro_geometry_cache.json';
const osmHydroAttribution = '© OpenStreetMap contributors';
const osmHydroLicense = 'ODbL-1.0';
const osmHydroLicenseUrl = 'https://www.openstreetmap.org/copyright';
const _hongKongBbox = '22.13,113.82,22.58,114.51';

Map<String, Object?> buildHydroCacheFromOverpassJson({
  required String coastlineJson,
  required String inlandWaterJson,
}) {
  final coastline = jsonDecode(coastlineJson) as Map<String, dynamic>;
  final inland = jsonDecode(inlandWaterJson) as Map<String, dynamic>;
  final features = <Map<String, Object?>>[];

  for (final raw in coastline['elements'] as List<dynamic>? ?? const []) {
    final element = raw as Map<String, dynamic>;
    final coordinates = _coordinates(element, toleranceMeters: 2.4);
    if (coordinates.length < 2) continue;
    features.add(_feature(
      kind: 'shore',
      name: '',
      element: element,
      coordinates: coordinates,
      geometryType: 'lineString',
      radiusMeters: 24,
    ));
  }

  for (final raw in inland['elements'] as List<dynamic>? ?? const []) {
    final element = raw as Map<String, dynamic>;
    final tags = Map<String, dynamic>.from(
      element['tags'] as Map? ?? const <String, dynamic>{},
    );
    final waterway = tags['waterway'] as String?;
    final isWaterArea =
        tags['natural'] == 'water' || tags['landuse'] == 'reservoir';
    if (!isWaterArea && waterway != 'river' && waterway != 'canal') continue;

    final rawGeometry = element['geometry'] as List<dynamic>? ?? const [];
    final isClosed = rawGeometry.length >= 4 &&
        _samePoint(rawGeometry.first as Map, rawGeometry.last as Map);
    if (isWaterArea && !isClosed) continue;
    final coordinates = _coordinates(
      element,
      toleranceMeters: isClosed ? 2.0 : 3.2,
      preserveClosure: isClosed,
    );
    if (coordinates.length < (isClosed ? 4 : 2)) continue;
    final name = (tags['name:zh'] ?? tags['name'] ?? '').toString().trim();
    final width = double.tryParse(tags['width']?.toString() ?? '');
    features.add(_feature(
      kind: 'water',
      name: name,
      element: element,
      coordinates: coordinates,
      geometryType: isClosed ? 'polygon' : 'lineString',
      radiusMeters: isClosed ? 1 : (width ?? 42).clamp(8, 90),
    ));
  }

  final promotedFeatures = promoteCoastlineLandSurfaces(features);

  promotedFeatures.sort((left, right) {
    final kind = (left['kind']! as String).compareTo(right['kind']! as String);
    if (kind != 0) return kind;
    return (left['osmId']! as int).compareTo(right['osmId']! as int);
  });
  return {
    'schemaVersion': 1,
    'source': osmHydroAttribution,
    'license': osmHydroLicense,
    'licenseUrl': osmHydroLicenseUrl,
    'bbox': _hongKongBbox,
    'features': promotedFeatures,
  };
}

List<Map<String, Object?>> promoteCoastlineLandSurfaces(
  List<Map<String, Object?>> features,
) {
  final coastlines = features
      .where((feature) => feature['kind'] == 'shore')
      .map(_CachedCoastline.new)
      .toList()
    ..sort((left, right) => left.osmId.compareTo(right.osmId));
  final promoted = <Map<String, Object?>>[
    for (final feature in features)
      if (feature['kind'] != 'shore') feature,
  ];
  final used = <int>{};

  for (var index = 0; index < coastlines.length; index++) {
    final coastline = coastlines[index];
    if (!coastline.isClosed) continue;
    used.add(index);
    promoted.add(_landFeatureFromCoastlines([coastline]));
  }

  for (var index = 0; index < coastlines.length; index++) {
    if (used.contains(index)) continue;
    final members = <int>[index];
    used.add(index);
    final chain = coastlines[index].coordinates.map(List<double>.of).toList();

    while (!_isClosedCoordinates(chain)) {
      final endKey = _coordinateKey(chain.last);
      final matches = <int>[
        for (var candidateIndex = 0;
            candidateIndex < coastlines.length;
            candidateIndex++)
          if (!used.contains(candidateIndex) &&
              !coastlines[candidateIndex].isClosed &&
              _coordinateKey(coastlines[candidateIndex].coordinates.first) ==
                  endKey)
            candidateIndex,
      ];
      if (matches.length != 1) break;
      final matchIndex = matches.single;
      final next = coastlines[matchIndex];
      chain.addAll(next.coordinates.skip(1).map(List<double>.of));
      members.add(matchIndex);
      used.add(matchIndex);
    }

    if (_isClosedCoordinates(chain) && chain.length >= 4) {
      promoted.add(
        _landFeatureFromCoastlines(
          [for (final member in members) coastlines[member]],
          coordinates: chain,
        ),
      );
    } else {
      promoted.addAll(
        members.map((member) => coastlines[member].feature),
      );
    }
  }

  return promoted;
}

Map<String, Object?> upgradeHydroCacheLandSurfaces(
  Map<String, dynamic> cache,
) {
  final features = (cache['features'] as List<dynamic>? ?? const [])
      .map((feature) => Map<String, Object?>.from(feature as Map))
      .toList();
  final promoted = promoteCoastlineLandSurfaces(features)
    ..sort((left, right) {
      final kind =
          (left['kind']! as String).compareTo(right['kind']! as String);
      if (kind != 0) return kind;
      return (left['osmId']! as int).compareTo(right['osmId']! as int);
    });
  return {
    ...cache,
    'features': promoted,
  };
}

Map<String, Object?> _landFeatureFromCoastlines(
  List<_CachedCoastline> coastlines, {
  List<List<double>>? coordinates,
}) {
  final ring = coordinates ?? coastlines.single.coordinates;
  final centerLat =
      ring.fold<double>(0, (sum, point) => sum + point[0]) / ring.length;
  final centerLng =
      ring.fold<double>(0, (sum, point) => sum + point[1]) / ring.length;
  final sourceIds = coastlines.map((coastline) => coastline.osmId).toList()
    ..sort();
  return {
    ...coastlines.first.feature,
    'kind': 'land',
    'name': '',
    'osmId': sourceIds.length == 1
        ? sourceIds.single
        : _stitchedCoastlineOsmId(sourceIds),
    'sourceOsmIds': sourceIds,
    'lat': _round(centerLat),
    'lng': _round(centerLng),
    'radiusMeters': 1,
    'geometry': {
      'type': 'polygon',
      'coordinates': ring,
    },
  };
}

int _stitchedCoastlineOsmId(List<int> ids) {
  var hash = 17;
  for (final id in ids) {
    hash = (hash * 31 + id) & 0x3fffffff;
  }
  return -(9000000000000 + hash);
}

bool _isClosedCoordinates(List<List<double>> coordinates) =>
    coordinates.length >= 4 &&
    _coordinateKey(coordinates.first) == _coordinateKey(coordinates.last);

String _coordinateKey(List<double> coordinate) =>
    '${coordinate[0].toStringAsFixed(7)},${coordinate[1].toStringAsFixed(7)}';

class _CachedCoastline {
  _CachedCoastline(this.feature)
      : osmId = feature['osmId']! as int,
        coordinates = ((feature['geometry']! as Map)['coordinates']! as List)
            .map((coordinate) => (coordinate as List)
                .map((value) => (value as num).toDouble())
                .toList(growable: false))
            .toList(growable: false);

  final Map<String, Object?> feature;
  final int osmId;
  final List<List<double>> coordinates;

  bool get isClosed => _isClosedCoordinates(coordinates);
}

Map<String, Object?> _feature({
  required String kind,
  required String name,
  required Map<String, dynamic> element,
  required List<List<double>> coordinates,
  required String geometryType,
  required num radiusMeters,
}) {
  final centerLat =
      coordinates.fold<double>(0, (sum, point) => sum + point[0]) /
          coordinates.length;
  final centerLng =
      coordinates.fold<double>(0, (sum, point) => sum + point[1]) /
          coordinates.length;
  return {
    'kind': kind,
    'name': name,
    'osmId': (element['id'] as num).toInt(),
    'provenance': 'openStreetMap',
    'region': 'hong-kong-wide',
    'lat': _round(centerLat),
    'lng': _round(centerLng),
    'radiusMeters': radiusMeters,
    'geometry': {
      'type': geometryType,
      'coordinates': coordinates,
    },
  };
}

List<List<double>> _coordinates(
  Map<String, dynamic> element, {
  required double toleranceMeters,
  bool preserveClosure = false,
}) {
  final geometry = element['geometry'] as List<dynamic>? ?? const [];
  final points = [
    for (final raw in geometry)
      [
        _round(((raw as Map<String, dynamic>)['lat'] as num).toDouble()),
        _round((raw['lon'] as num).toDouble()),
      ],
  ];
  if (points.length <= 2) return points;
  final closed = preserveClosure &&
      points.first[0] == points.last[0] &&
      points.first[1] == points.last[1];
  final source = closed ? points.sublist(0, points.length - 1) : points;
  final simplified = _simplify(source, toleranceMeters);
  if (closed && simplified.isNotEmpty) {
    simplified.add(List.of(simplified.first));
  }
  return simplified;
}

List<List<double>> _simplify(
    List<List<double>> points, double toleranceMeters) {
  if (points.length <= 2) return points.map(List<double>.of).toList();
  var maxDistance = 0.0;
  var splitIndex = 0;
  for (var index = 1; index < points.length - 1; index++) {
    final distance =
        _distanceToSegment(points[index], points.first, points.last);
    if (distance > maxDistance) {
      maxDistance = distance;
      splitIndex = index;
    }
  }
  if (maxDistance <= toleranceMeters) {
    return [List.of(points.first), List.of(points.last)];
  }
  final left = _simplify(points.sublist(0, splitIndex + 1), toleranceMeters);
  final right = _simplify(points.sublist(splitIndex), toleranceMeters);
  return [...left.sublist(0, left.length - 1), ...right];
}

double _distanceToSegment(List<double> point, List<double> a, List<double> b) {
  const latMeters = 111320.0;
  final lngMeters = 111320.0 * math.cos(point[0] * math.pi / 180);
  final px = point[1] * lngMeters;
  final py = point[0] * latMeters;
  final ax = a[1] * lngMeters;
  final ay = a[0] * latMeters;
  final bx = b[1] * lngMeters;
  final by = b[0] * latMeters;
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt(math.pow(px - ax, 2) + math.pow(py - ay, 2));
  }
  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0, 1);
  final cx = ax + dx * t;
  final cy = ay + dy * t;
  return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2));
}

bool _samePoint(Map first, Map last) =>
    first['lat'] == last['lat'] && first['lon'] == last['lon'];

double _round(double value) => (value * 10000000).roundToDouble() / 10000000;

Future<String> _fetchOverpass(String query) async {
  Object? lastError;
  for (final host in const ['overpass-api.de', 'overpass.kumi.systems']) {
    for (var attempt = 0; attempt < 2; attempt++) {
      final client = HttpClient()..userAgent = 'FisherGO-map-cache/1.0';
      try {
        final uri = Uri.https(host, '/api/interpreter', {'data': query});
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Overpass fetch failed: ${response.statusCode}',
            uri: uri,
          );
        }
        return await utf8.decoder.bind(response).join();
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      } finally {
        client.close(force: true);
      }
    }
  }
  throw StateError('All Overpass mirrors failed: $lastError');
}

Future<void> main(List<String> args) async {
  const coastQuery = '[out:json][timeout:180];way["natural"="coastline"]'
      '($_hongKongBbox);out meta geom;';
  const inlandQuery = '[out:json][timeout:180];('
      'way["natural"="water"]($_hongKongBbox);'
      'way["landuse"="reservoir"]($_hongKongBbox);'
      'way["waterway"~"river|canal"]($_hongKongBbox);'
      ');out tags geom;';
  if (args.length == 1 && args.single == '--upgrade-cache') {
    final output = File(osmHydroCacheOutputPath);
    final decoded =
        jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    final upgraded = upgradeHydroCacheLandSurfaces(decoded);
    await output.writeAsString('${jsonEncode(upgraded)}\n');
    stdout.writeln(
      'Upgraded ${output.path}: '
      '${(upgraded['features'] as List).length} features',
    );
    return;
  }
  final useLocalFiles = args.length == 2;
  if (args.isNotEmpty && !useLocalFiles) {
    throw ArgumentError(
      'Pass both coastline and inland-water Overpass JSON paths, or no args.',
    );
  }
  final cache = buildHydroCacheFromOverpassJson(
    coastlineJson: useLocalFiles
        ? File(args[0]).readAsStringSync()
        : await _fetchOverpass(coastQuery),
    inlandWaterJson: useLocalFiles
        ? File(args[1]).readAsStringSync()
        : await _fetchOverpass(inlandQuery),
  );
  final output = File(osmHydroCacheOutputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString('${jsonEncode(cache)}\n');
  stdout.writeln(
      'Wrote ${output.path}: ${(cache['features'] as List).length} features');
}
