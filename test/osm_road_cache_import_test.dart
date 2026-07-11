import '../tool/update_osm_road_cache.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports primary bridge metadata and real node coordinates', () {
    final cache = buildRoadCacheFromOsmXml(
      _osmFixture,
      regionName: 'sha-tin',
    );
    final features = cache['features']! as List<Map<String, Object?>>;
    expect(cache['license'], 'ODbL-1.0');
    expect(
      cache['licenseUrl'],
      'https://www.openstreetmap.org/copyright',
    );
    final road = features.singleWhere(
      (feature) => feature['osmId'] == 101,
    );

    expect(road['kind'], 'road');
    expect(road['name'], '沙田鄉事會路');
    expect(road['roadClass'], 'primary');
    expect(road['isBridge'], isTrue);
    expect(road['lanes'], 3);
    expect(
      (road['geometry']! as Map<String, Object?>)['coordinates'],
      [
        [22.3819, 114.1874],
        [22.3822, 114.1881],
      ],
    );
  });

  test('normalizes link roads to their parent hierarchy', () {
    final cache = buildRoadCacheFromOsmXml(
      _osmFixture,
      regionName: 'tsing-ma',
    );
    final features = cache['features']! as List<Map<String, Object?>>;
    final ramp = features.singleWhere(
      (feature) => feature['osmId'] == 102,
    );

    expect(ramp['roadClass'], 'motorway');
    expect(ramp['name'], '青衣西北交匯處');
  });

  test('keeps named footways and excludes unnamed footways', () {
    final cache = buildRoadCacheFromOsmXml(
      _osmFixture,
      regionName: 'sha-tin',
    );
    final features = cache['features']! as List<Map<String, Object?>>;
    final ids = features.map((feature) => feature['osmId']).toSet();

    expect(ids, contains(103));
    expect(ids, isNot(contains(104)));
    expect(
      features.singleWhere((feature) => feature['osmId'] == 103)['roadClass'],
      'footway',
    );
  });

  test('keeps unnamed major-road geometry without exposing an OSM id label',
      () {
    final cache = buildRoadCacheFromOsmXml(
      _osmFixture,
      regionName: 'sha-tin',
    );
    final features = cache['features']! as List<Map<String, Object?>>;
    final unnamedRoad = features.singleWhere(
      (feature) => feature['osmId'] == 105,
    );

    expect(unnamedRoad['name'], isEmpty);
    expect(unnamedRoad['roadClass'], 'trunk');
  });
}

const _osmFixture = '''
<osm version="0.6">
  <node id="1" lat="22.3819000" lon="114.1874000" />
  <node id="2" lat="22.3822000" lon="114.1881000" />
  <node id="3" lat="22.3826000" lon="114.1888000" />
  <node id="4" lat="22.3830000" lon="114.1894000" />
  <way id="101">
    <nd ref="1" /><nd ref="2" />
    <tag k="highway" v="primary" />
    <tag k="bridge" v="yes" />
    <tag k="lanes" v="3" />
    <tag k="name" v="Sha Tin Rural Committee Road" />
    <tag k="name:zh" v="沙田鄉事會路" />
  </way>
  <way id="102">
    <nd ref="2" /><nd ref="3" />
    <tag k="highway" v="motorway_link" />
    <tag k="name:zh" v="青衣西北交匯處" />
  </way>
  <way id="103">
    <nd ref="3" /><nd ref="4" />
    <tag k="highway" v="footway" />
    <tag k="name:zh" v="城門河步道" />
  </way>
  <way id="104">
    <nd ref="1" /><nd ref="4" />
    <tag k="highway" v="footway" />
  </way>
  <way id="105">
    <nd ref="1" /><nd ref="3" />
    <tag k="highway" v="trunk" />
  </way>
</osm>
''';
