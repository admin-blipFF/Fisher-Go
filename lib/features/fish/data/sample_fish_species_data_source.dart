import '../domain/fish_species.dart';

class SampleFishSpeciesDataSource {
  const SampleFishSpeciesDataSource();

  List<FishSpecies> loadSpecies() => const [
        FishSpecies(
          id: 'sample-yellowfin-seabream',
          afcdId: 'AFCD-SAMPLE-001',
          commonNameZh: '黃腳鱲',
          commonNameEn: 'Yellowfin Seabream',
          scientificName: 'Acanthopagrus latus',
          family: 'Sparidae',
          descriptionZh: '香港常見近岸魚類，釣魚活動中常見。',
          habitatZh: '近岸、碼頭、河口及沙泥底水域。',
          dangerLevel: 'low',
        ),
        FishSpecies(
          id: 'sample-black-seabream',
          afcdId: 'AFCD-SAMPLE-002',
          commonNameZh: '黑鯛',
          commonNameEn: 'Black Seabream',
          scientificName: 'Acanthopagrus schlegelii',
          family: 'Sparidae',
          descriptionZh: '常見海釣目標魚，適應力強。',
          habitatZh: '岩礁、碼頭、防波堤附近。',
          dangerLevel: 'low',
        ),
        FishSpecies(
          id: 'sample-grouper',
          afcdId: 'AFCD-SAMPLE-003',
          commonNameZh: '石斑',
          commonNameEn: 'Grouper',
          scientificName: 'Epinephelus spp.',
          family: 'Serranidae',
          descriptionZh: '香港市場及釣魚常見魚類，正式版本會按 AFCD 資料細分品種。',
          habitatZh: '礁石區、沉船、海堤洞穴。',
          dangerLevel: 'medium',
        ),
        FishSpecies(
          id: 'sample-rabbitfish',
          afcdId: 'AFCD-SAMPLE-004',
          commonNameZh: '泥鯭',
          commonNameEn: 'Rabbitfish',
          scientificName: 'Siganus canaliculatus',
          family: 'Siganidae',
          descriptionZh: '背鰭有刺，處理時需要小心。',
          habitatZh: '近岸礁石、海草床、碼頭邊。',
          dangerLevel: 'medium',
        ),
        FishSpecies(
          id: 'sample-lionfish',
          afcdId: 'AFCD-SAMPLE-005',
          commonNameZh: '獅子魚',
          commonNameEn: 'Lionfish',
          scientificName: 'Pterois volitans',
          family: 'Scorpaenidae',
          descriptionZh: '具毒棘，觀察和處理時需要格外小心。',
          habitatZh: '礁石及珊瑚環境。',
          dangerLevel: 'high',
        ),
      ];
}
