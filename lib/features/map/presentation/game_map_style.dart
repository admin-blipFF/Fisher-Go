import 'dart:convert';

/// Lightweight OpenMapTiles style for the gameplay map.
///
/// It intentionally excludes symbol and POI layers. Those layers add visual
/// noise, trigger sprite downloads, and compete with FisherGO markers.
const fisherGoMapStyle = r'''
{
  "version": 8,
  "name": "FisherGO Game Map",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/planet"
    }
  },
  "layers": [
    {
      "id": "land",
      "type": "background",
      "paint": {
        "background-color": "#dce8c9"
      }
    },
    {
      "id": "landuse",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landuse",
      "minzoom": 11,
      "filter": [
        "in",
        "class",
        "residential",
        "commercial",
        "industrial",
        "retail",
        "school",
        "university",
        "hospital",
        "cemetery",
        "stadium",
        "pitch",
        "playground"
      ],
      "paint": {
        "fill-color": [
          "match",
          ["get", "class"],
          "residential", "#d5dec7",
          "commercial", "#e0d5b9",
          "retail", "#e6cfac",
          "industrial", "#c9d1c2",
          "school", "#c5dfb9",
          "university", "#b9d6b3",
          "hospital", "#e2c9c7",
          "cemetery", "#b9d2b8",
          "stadium", "#a8d39b",
          "pitch", "#acd69d",
          "playground", "#d7d99d",
          "#d4dfbd"
        ],
        "fill-opacity": 0.78
      }
    },
    {
      "id": "farmland",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["==", "class", "farmland"],
      "paint": {
        "fill-color": "#d4e4b6",
        "fill-opacity": 0.9
      }
    },
    {
      "id": "grass",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "grass", "meadow"],
      "paint": {
        "fill-color": "#b8dca0",
        "fill-opacity": 0.86
      }
    },
    {
      "id": "wood",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "wood", "forest"],
      "paint": {
        "fill-color": "#91c683",
        "fill-opacity": 0.88
      }
    },
    {
      "id": "park",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "park",
      "paint": {
        "fill-color": "#a7d991",
        "fill-opacity": 0.82
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": [
          "match",
          ["get", "class"],
          "ocean", "#55bfe4",
          "sea", "#55bfe4",
          "bay", "#5bc7e8",
          "strait", "#52b7dc",
          "lake", "#63bddf",
          "river", "#65c8e4",
          "dock", "#4caed1",
          "pond", "#6bcbe3",
          "#63bddd"
        ],
        "fill-opacity": 0.94,
        "fill-outline-color": "#4aa5cd"
      }
    },
    {
      "id": "waterway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "waterway",
      "paint": {
        "line-color": "#62b4df",
        "line-opacity": 0.94,
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          11, 0.7,
          16, 3.5,
          20, 10
        ]
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "building",
      "minzoom": 13,
      "maxzoom": 15.5,
      "paint": {
        "fill-color": "#d6d1c5",
        "fill-outline-color": "#bdb8ad",
        "fill-opacity": 0.78
      }
    },
    {
      "id": "building-3d",
      "type": "fill-extrusion",
      "source": "openmaptiles",
      "source-layer": "building",
      "minzoom": 15.5,
      "paint": {
        "fill-extrusion-color": "#d8d2c6",
        "fill-extrusion-height": [
          "min",
          [
            "coalesce",
            ["get", "render_height"],
            ["get", "height"],
            6
          ],
          36
        ],
        "fill-extrusion-base": [
          "coalesce",
          ["get", "render_min_height"],
          0
        ],
        "fill-extrusion-vertical-gradient": false,
        "fill-extrusion-opacity": 0.66
      }
    },
    {
      "id": "road-path",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 15,
      "filter": ["in", "class", "path", "track", "pedestrian"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#f1e7cd",
        "line-opacity": 0.9,
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          15, 1,
          20, 5
        ]
      }
    },
    {
      "id": "road-minor-casing",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13.5,
      "filter": ["in", "class", "minor", "service"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#8f9a91",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          13.5, 1.4,
          16, 4.5,
          20, 13
        ]
      }
    },
    {
      "id": "road-minor",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13.5,
      "filter": ["in", "class", "minor", "service"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#fff9e8",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          13.5, 0.8,
          16, 3,
          20, 10
        ]
      }
    },
    {
      "id": "road-medium-casing",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 10,
      "filter": ["in", "class", "secondary", "tertiary"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#8d856f",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          10, 1,
          16, 7,
          20, 18
        ]
      }
    },
    {
      "id": "road-medium",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 10,
      "filter": ["in", "class", "secondary", "tertiary"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#f7ddb0",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          10, 0.6,
          16, 5,
          20, 15
        ]
      }
    },
    {
      "id": "road-major-casing",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 6,
      "filter": ["in", "class", "motorway", "trunk", "primary"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#6f817c",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          6, 0.8,
          16, 9,
          20, 23
        ]
      }
    },
    {
      "id": "road-major",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 6,
      "filter": ["in", "class", "motorway", "trunk", "primary"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#f1bf8c",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          6, 0.5,
          16, 6.5,
          20, 19
        ]
      }
    },
    {
      "id": "pier-casing",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13,
      "filter": ["==", "class", "pier"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#8f877b",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          13, 2,
          20, 12
        ]
      }
    },
    {
      "id": "pier",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13,
      "filter": ["==", "class", "pier"],
      "layout": {
        "line-cap": "round",
        "line-join": "round"
      },
      "paint": {
        "line-color": "#e8ddcc",
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          13, 1,
          20, 9
        ]
      }
    }
  ]
}
''';

/// Web motion style that preserves gameplay-critical geography and building
/// footprints while avoiding high-cost extrusion and duplicate road passes.
///
/// This is generated once from the accepted full style so the candidate cannot
/// drift in source, water, or land-use coverage. Main roads remain readable;
/// paths, minor roads, and casing layers are intentionally omitted on Web.
final fisherGoWebMotionMapStyle = _withoutBuildingExtrusion(fisherGoMapStyle);

String _withoutBuildingExtrusion(String source) {
  final style = jsonDecode(source) as Map<String, dynamic>;
  const excludedLayerIds = <String>{
    'building-3d',
    'road-path',
    'road-minor-casing',
    'road-minor',
    'road-medium-casing',
    'road-major-casing',
    'pier-casing',
  };
  final layers = (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>()
    ..removeWhere((layer) => excludedLayerIds.contains(layer['id']));
  style['layers'] = layers;
  return jsonEncode(style);
}

/// A reduced 3D gameplay style for Android motion tests and capable devices.
/// It keeps OSM-driven water, waterways, major roads, piers, and building
/// extrusion while omitting paths, service lanes, and minor roads that add
/// visual noise and draw work without changing the playable geography.
const fisherGoGame3dMapStyle = r'''
{
  "version": 8,
  "name": "FisherGO Game 3D Map",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/planet"
    }
  },
  "layers": [
    {
      "id": "land",
      "type": "background",
      "paint": {"background-color": "#dce8c9"}
    },
    {
      "id": "grass",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "farmland", "grass", "meadow"],
      "paint": {"fill-color": "#b8dca0", "fill-opacity": 0.86}
    },
    {
      "id": "wood",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "wood", "forest"],
      "paint": {"fill-color": "#91c683", "fill-opacity": 0.88}
    },
    {
      "id": "park",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "park",
      "paint": {"fill-color": "#a7d991", "fill-opacity": 0.82}
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": [
          "match",
          ["get", "class"],
          "ocean", "#55bfe4",
          "sea", "#55bfe4",
          "bay", "#5bc7e8",
          "strait", "#52b7dc",
          "lake", "#63bddf",
          "river", "#65c8e4",
          "dock", "#4caed1",
          "pond", "#6bcbe3",
          "#63bddd"
        ],
        "fill-opacity": 0.94,
        "fill-outline-color": "#4aa5cd"
      }
    },
    {
      "id": "waterway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "waterway",
      "paint": {
        "line-color": "#62b4df",
        "line-opacity": 0.94,
        "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.7, 16, 3.5, 20, 10]
      }
    },
    {
      "id": "building-3d",
      "type": "fill-extrusion",
      "source": "openmaptiles",
      "source-layer": "building",
      "minzoom": 15,
      "paint": {
        "fill-extrusion-color": "#d8d2c6",
        "fill-extrusion-height": [
          "min",
          [
            "coalesce",
            ["get", "render_height"],
            ["get", "height"],
            6
          ],
          36
        ],
      "fill-extrusion-base": [
          "coalesce",
          ["get", "render_min_height"],
          0
        ],
        "fill-extrusion-vertical-gradient": false,
        "fill-extrusion-opacity": 0.66
      }
    },
    {
      "id": "road-main",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 10,
      "filter": ["in", "class", "motorway", "trunk", "primary", "secondary", "tertiary"],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": [
          "match",
          ["get", "class"],
          "motorway", "#f1bf8c",
          "trunk", "#f1bf8c",
          "primary", "#f1bf8c",
          "secondary", "#f7ddb0",
          "tertiary", "#f7ddb0",
          "#fff9e8"
        ],
        "line-opacity": 0.96,
        "line-width": [
          "interpolate",
          ["linear"],
          ["zoom"],
          10,
          [
            "match",
            ["get", "class"],
            "motorway", 1,
            "trunk", 1,
            "primary", 1,
            "secondary", 0.7,
            "tertiary", 0.7,
            0
          ],
          13.5,
          [
            "match",
            ["get", "class"],
            "motorway", 4.5,
            "trunk", 4.5,
            "primary", 4.5,
            "secondary", 3.6,
            "tertiary", 3.6,
            0
          ],
          16,
          [
            "match",
            ["get", "class"],
            "motorway", 7,
            "trunk", 7,
            "primary", 7,
            "secondary", 5.5,
            "tertiary", 5.5,
            0
          ],
          20,
          [
            "match",
            ["get", "class"],
            "motorway", 19,
            "trunk", 19,
            "primary", 19,
            "secondary", 15,
            "tertiary", 15,
            0
          ]
        ]
      }
    },
    {
      "id": "pier",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13,
      "filter": ["==", "class", "pier"],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": "#e8ddcc",
        "line-width": ["interpolate", ["linear"], ["zoom"], 13, 1, 20, 9]
      }
    }
  ]
}
''';

/// Diagnostic-only Android style that keeps the same OSM layer topology while
/// removing per-building height/base property expressions.
final fisherGoFixedBuildingHeightGame3dMapStyle =
    _withFixedBuildingHeight(fisherGoGame3dMapStyle);

String _withFixedBuildingHeight(String source) {
  final style = jsonDecode(source) as Map<String, dynamic>;
  final layers = (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
  final building = layers.firstWhere((layer) => layer['id'] == 'building-3d');
  final paint = building['paint'] as Map<String, dynamic>;
  paint['fill-extrusion-height'] = 24;
  paint['fill-extrusion-base'] = 0;
  return jsonEncode(style);
}

/// A measured fallback for Android devices where the full style misses the
/// frame budget. It preserves map-driven water, roads, buildings, and piers
/// while removing duplicate road casings and extra landcover passes.
const fisherGoCompactMapStyle = r'''
{
  "version": 8,
  "name": "FisherGO Compact Game Map",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/planet"
    }
  },
  "layers": [
    {
      "id": "land",
      "type": "background",
      "paint": {"background-color": "#dce8c9"}
    },
    {
      "id": "landcover",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "farmland", "grass", "meadow"],
      "paint": {"fill-color": "#b8d99f", "fill-opacity": 0.88}
    },
    {
      "id": "wood",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "wood", "forest"],
      "paint": {"fill-color": "#91c683", "fill-opacity": 0.88}
    },
    {
      "id": "park",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "park",
      "paint": {"fill-color": "#a7d991", "fill-opacity": 0.82}
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": [
          "match",
          ["get", "class"],
          "ocean", "#55bfe4",
          "sea", "#55bfe4",
          "bay", "#5bc7e8",
          "strait", "#52b7dc",
          "lake", "#63bddf",
          "river", "#65c8e4",
          "dock", "#4caed1",
          "pond", "#6bcbe3",
          "#63bddd"
        ],
        "fill-opacity": 0.94,
        "fill-outline-color": "#4aa5cd"
      }
    },
    {
      "id": "waterway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "waterway",
      "paint": {
        "line-color": "#62b4df",
        "line-opacity": 0.94,
        "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.7, 16, 3.5, 20, 10]
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "building",
      "minzoom": 14,
      "paint": {
        "fill-color": "#d6d1c5",
        "fill-opacity": 0.72
      }
    },
    {
      "id": "road-path",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 15,
      "filter": ["in", "class", "path", "track", "pedestrian"],
      "paint": {
        "line-color": "#f1e7cd",
        "line-opacity": 0.9,
        "line-width": ["interpolate", ["linear"], ["zoom"], 15, 1, 20, 5]
      }
    },
    {
      "id": "road-minor",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13.5,
      "filter": ["in", "class", "minor", "service"],
      "paint": {
        "line-color": "#fff9e8",
        "line-opacity": 0.9,
        "line-width": ["interpolate", ["linear"], ["zoom"], 13.5, 1.1, 16, 3.5, 20, 11]
      }
    },
    {
      "id": "road-medium",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 10,
      "filter": ["in", "class", "secondary", "tertiary"],
      "paint": {
        "line-color": "#f7ddb0",
        "line-width": ["interpolate", ["linear"], ["zoom"], 10, 1, 16, 5.5, 20, 15]
      }
    },
    {
      "id": "road-major",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 6,
      "filter": ["in", "class", "motorway", "trunk", "primary"],
      "paint": {
        "line-color": "#f1bf8c",
        "line-width": ["interpolate", ["linear"], ["zoom"], 6, 1, 16, 8, 20, 20]
      }
    },
    {
      "id": "pier",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13,
      "filter": ["==", "class", "pier"],
      "paint": {
        "line-color": "#e8ddcc",
        "line-width": ["interpolate", ["linear"], ["zoom"], 13, 1.5, 20, 9]
      }
    }
  ]
}
''';

/// An Android performance candidate for devices where vector fill and
/// building geometry dominate raster time. It keeps the data-driven coastline,
/// waterways, roads and piers that define the playable geography, but avoids
/// building polygons and duplicate road casing passes.
const fisherGoLowPowerMapStyle = r'''
{
  "version": 8,
  "name": "FisherGO Low Power Game Map",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "https://tiles.openfreemap.org/planet"
    }
  },
  "layers": [
    {
      "id": "land",
      "type": "background",
      "paint": {"background-color": "#dce8c9"}
    },
    {
      "id": "landcover",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "farmland", "grass", "meadow"],
      "paint": {"fill-color": "#b8d99f", "fill-opacity": 0.84}
    },
    {
      "id": "wood",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["in", "class", "wood", "forest"],
      "paint": {"fill-color": "#91c683", "fill-opacity": 0.84}
    },
    {
      "id": "park",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "park",
      "paint": {"fill-color": "#a7d991", "fill-opacity": 0.78}
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": "#79c3e7",
        "fill-outline-color": "#62abd6"
      }
    },
    {
      "id": "waterway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "waterway",
      "paint": {
        "line-color": "#62b4df",
        "line-opacity": 0.9,
        "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.7, 16, 3, 20, 8]
      }
    },
    {
      "id": "road",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 10,
      "filter": ["in", "class", "motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service"],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": "#fff1c6",
        "line-opacity": 0.9,
        "line-width": ["interpolate", ["linear"], ["zoom"], 10, 0.8, 16, 3.5, 20, 12]
      }
    },
    {
      "id": "path",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 15,
      "filter": ["in", "class", "path", "track", "pedestrian"],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": "#f1e7cd",
        "line-opacity": 0.82,
        "line-width": ["interpolate", ["linear"], ["zoom"], 15, 0.9, 20, 4]
      }
    },
    {
      "id": "pier",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "minzoom": 13,
      "filter": ["==", "class", "pier"],
      "layout": {"line-cap": "round", "line-join": "round"},
      "paint": {
        "line-color": "#e8ddcc",
        "line-width": ["interpolate", ["linear"], ["zoom"], 13, 1, 20, 8]
      }
    }
  ]
}
''';
