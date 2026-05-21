insert into public.fish_species
  (afcd_id, common_name_zh, common_name_en, scientific_name, family, description_zh, habitat_zh, danger_level, image_url, silhouette_url)
values
  ('AFCD-SAMPLE-001', '黃腳鱲', 'Yellowfin Seabream', 'Acanthopagrus latus', 'Sparidae', '香港常見近岸魚類，釣魚活動中常見。', '近岸、碼頭、河口及沙泥底水域。', 'low', null, null),
  ('AFCD-SAMPLE-002', '黑鯛', 'Black Seabream', 'Acanthopagrus schlegelii', 'Sparidae', '常見海釣目標魚，適應力強。', '岩礁、碼頭、防波堤附近。', 'low', null, null),
  ('AFCD-SAMPLE-003', '石斑', 'Grouper', 'Epinephelus spp.', 'Serranidae', '香港市場及釣魚常見魚類，品種需以正式 AFCD 資料細分。', '礁石區、沉船、海堤洞穴。', 'medium', null, null),
  ('AFCD-SAMPLE-004', '泥鯭', 'Rabbitfish', 'Siganus canaliculatus', 'Siganidae', '背鰭有刺，處理時需要小心。', '近岸礁石、海草床、碼頭邊。', 'medium', null, null),
  ('AFCD-SAMPLE-005', '獅子魚', 'Lionfish', 'Pterois volitans', 'Scorpaenidae', '具毒棘，觀察和處理時需要格外小心。', '礁石及珊瑚環境。', 'high', null, null)
on conflict (afcd_id) do nothing;
