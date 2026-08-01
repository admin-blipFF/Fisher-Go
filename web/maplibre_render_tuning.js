(() => {
  if (!window.maplibregl || !window.maplibregl.Map) return;

  const OriginalMap = window.maplibregl.Map;
  if (OriginalMap.__fisherGoRenderTuning) return;

  const TunedMap = new Proxy(OriginalMap, {
    construct(target, args, newTarget) {
      const options = {
        ...args[0],
        // FisherGO has no symbol layers, so collision and fade work is unused.
        crossSourceCollisions: false,
        fadeDuration: 0,
        refreshExpiredTiles: false,
        renderWorldCopies: false,
        reparseOverscaled: false,
      };
      const query = new URLSearchParams(window.location.search);
      const requestedPixelRatioRaw = query.get('fishergo_pixel_ratio');
      const requestedPixelRatio = requestedPixelRatioRaw === null
        ? null
        : Number(requestedPixelRatioRaw);
      const adaptivePixelRatio = window.innerWidth >= 768 &&
          (window.devicePixelRatio >= 1.25 || window.innerWidth >= 1024)
        ? 0.75
        : null;
      const pixelRatio = requestedPixelRatio !== null &&
          Number.isFinite(requestedPixelRatio)
        ? requestedPixelRatio
        : adaptivePixelRatio;
      if (pixelRatio !== null && pixelRatio >= 0.5 && pixelRatio <= 1) {
        // Keep the same vector geometry while limiting the wide-screen WebGL
        // canvas to a measured 0.75 ratio. Query values remain available for
        // an explicit 1.0/0.75 A/B and for future device tuning.
        options.pixelRatio = pixelRatio;
        window.__FISHERGO_PIXEL_RATIO__ = pixelRatio;
        window.__FISHERGO_PIXEL_RATIO_ADAPTIVE__ =
          requestedPixelRatio === null;
      }
      const requestedTileCacheLevelsRaw = query.get(
        'fishergo_tile_cache_levels',
      );
      const requestedTileCacheLevels = requestedTileCacheLevelsRaw === null
        ? null
        : Number(requestedTileCacheLevelsRaw);
      if (requestedTileCacheLevels !== null &&
          Number.isInteger(requestedTileCacheLevels) &&
          requestedTileCacheLevels >= 1 &&
          requestedTileCacheLevels <= 8) {
        // Keep the default dynamic cache policy in production. This bounded
        // query gate is only for motion/working-set A/B measurements.
        options.maxTileCacheZoomLevels = requestedTileCacheLevels;
        window.__FISHERGO_TILE_CACHE_LEVELS__ = requestedTileCacheLevels;
      }
      if (query.get('fishergo_desynchronized') === '1') {
        options.canvasContextAttributes = {
          ...(options.canvasContextAttributes ?? {}),
          desynchronized: true,
        };
        window.__FISHERGO_DESYNCHRONIZED_CONTEXT__ = true;
      }
      if (query.get('fishergo_road_simplify') === '1') {
        const originalStyle = options.style;
        try {
          const style = typeof originalStyle === 'string'
            ? JSON.parse(originalStyle)
            : originalStyle;
          if (style && Array.isArray(style.layers)) {
            style.layers = style.layers.filter((layer) => ![
              'road-path',
              'road-minor-casing',
              'road-minor',
            ].includes(layer.id));
            options.style = typeof originalStyle === 'string'
              ? JSON.stringify(style)
              : style;
            window.__FISHERGO_ROAD_SIMPLIFY__ = true;
          }
        } catch (_) {
          // Keep the accepted style if a future MapLibre binding changes shape.
        }
      }
      if (query.get('fishergo_web_no_extrusion') === '1') {
        const originalStyle = options.style;
        try {
          const style = typeof originalStyle === 'string'
            ? JSON.parse(originalStyle)
            : originalStyle;
          if (style && Array.isArray(style.layers)) {
            style.layers = style.layers.filter(
              (layer) => layer.id !== 'building-3d',
            );
            options.style = typeof originalStyle === 'string'
              ? JSON.stringify(style)
              : style;
            window.__FISHERGO_WEB_NO_EXTRUSION__ = true;
          }
        } catch (_) {
          // Keep the accepted style if a future MapLibre binding changes shape.
        }
      }
      return Reflect.construct(target, [options], newTarget);
    },
  });

  TunedMap.__fisherGoRenderTuning = true;
  window.maplibregl.Map = TunedMap;
  window.__FISHERGO_MAP_RENDER_TUNING_APPLIED__ = true;
})();
