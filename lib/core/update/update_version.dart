int parseAppBuildNumber(Map<String, dynamic> payload) {
  final rawBuild = payload['build_id'] ?? payload['build_number'];
  if (rawBuild is int) return rawBuild;
  return int.tryParse('$rawBuild') ?? 0;
}
