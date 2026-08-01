/// Game-design habitat profiles for the audited public fishing spots.
///
/// These weights shape the FisherGO loop; they are not a live ecological
/// survey. The remote registry carries the same values after migration 0017.
class FishingSpotHabitatProfile {
  const FishingSpotHabitatProfile({
    required this.habitatTags,
    required this.speciesWeights,
  });

  final List<String> habitatTags;
  final Map<String, double> speciesWeights;
}

const _nearshorePierTags = <String>['nearshore', 'pier'];

const _tungChungRunwayProfile = FishingSpotHabitatProfile(
  habitatTags: <String>[..._nearshorePierTags, 'tung-chung-runway'],
  speciesWeights: <String, double>{
    'fish-103': 4,
    'fish-109': 4,
  },
);

const _northWaterProfile = FishingSpotHabitatProfile(
  habitatTags: <String>[..._nearshorePierTags, 'north-water'],
  speciesWeights: <String, double>{
    'fish-103': 4,
    'fish-109': 4,
  },
);

const _samMunTsaiTaiPoProfile = FishingSpotHabitatProfile(
  habitatTags: <String>[..._nearshorePierTags, 'sam-mun-tsai-tai-po-inner'],
  speciesWeights: <String, double>{
    'fish-063': 4,
    'fish-067': 4,
  },
);

const _tsingMaProfile = FishingSpotHabitatProfile(
  habitatTags: <String>[..._nearshorePierTags, 'tsing-ma-waters'],
  speciesWeights: <String, double>{
    'fish-069': 4,
    'fish-073': 4,
  },
);

const _eastWaterProfile = FishingSpotHabitatProfile(
  habitatTags: <String>[..._nearshorePierTags, 'east-water'],
  speciesWeights: <String, double>{
    'fish-101': 4,
    'fish-103': 4,
    'fish-140': 4,
  },
);

const Map<String, FishingSpotHabitatProfile> fishingSpotHabitatProfiles = {
  'P017': _tungChungRunwayProfile,
  'P018': _tungChungRunwayProfile,
  'P023': _northWaterProfile,
  'P024': _northWaterProfile,
  'P025': _northWaterProfile,
  'P045': _samMunTsaiTaiPoProfile,
  'P046': _samMunTsaiTaiPoProfile,
  'P047': _samMunTsaiTaiPoProfile,
  'P048': _northWaterProfile,
  'P049': _northWaterProfile,
  'P050': _samMunTsaiTaiPoProfile,
  'P051': _tsingMaProfile,
  'P052': _tsingMaProfile,
  'P053': _tsingMaProfile,
  'P054': _tsingMaProfile,
  'P035': _eastWaterProfile,
  'P036': _eastWaterProfile,
  'P043': _eastWaterProfile,
};

FishingSpotHabitatProfile? habitatProfileForSpot(String spotId) =>
    fishingSpotHabitatProfiles[spotId];
