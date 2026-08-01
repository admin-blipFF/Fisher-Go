/// Returns a MapLibre bearing in the canonical clockwise 0..360 range.
double normalizeMapBearing(double bearing) {
  final normalized = bearing % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}
