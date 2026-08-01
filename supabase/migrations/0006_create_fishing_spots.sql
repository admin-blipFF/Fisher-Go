create table if not exists public.fishing_spots (
  id text primary key,
  name_zh text not null,
  name_en text,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  coordinate_precision_m double precision not null default 50,
  kind text not null check (kind in ('shore','pier','rock','island','reservoir','pond','boat')),
  verification_status text not null default 'draft'
    check (verification_status in ('draft','communityReported','verified','suspended')),
  public_access boolean not null default false,
  safety_notes text not null default '',
  source text not null,
  source_reference text not null,
  reviewer text not null,
  reviewed_at timestamptz not null,
  active boolean not null default false,
  habitat_tags text[] not null default '{}',
  species_weights jsonb not null default '{}'::jsonb,
  environment text not null default 'coastal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fishing_spots enable row level security;

drop policy if exists "public reads active verified fishing spots" on public.fishing_spots;
create policy "public reads active verified fishing spots"
  on public.fishing_spots for select
  to anon, authenticated
  using (active = true and verification_status = 'verified');

revoke insert, update, delete on table public.fishing_spots from anon, authenticated;
grant select on table public.fishing_spots to anon, authenticated;

create index if not exists fishing_spots_active_status_idx
  on public.fishing_spots (active, verification_status);
create index if not exists fishing_spots_coordinates_idx
  on public.fishing_spots (latitude, longitude);
-- Seed rows are auditable app data, not a claim that every location is currently open.
-- Future reviews can suspend rows without shipping a client update.
insert into public.fishing_spots (
  id, name_zh, name_en, latitude, longitude, coordinate_precision_m,
  kind, verification_status, public_access, safety_notes, source,
  source_reference, reviewer, reviewed_at, active, habitat_tags,
  species_weights, environment
)
values
  ('P001', '中環九號碼頭', '中環九號碼頭', 22.286059998, 114.162570004, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P002', '中環十號碼頭', '中環十號碼頭', 22.285370343, 114.162900169, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P003', '糖水道碼頭', '糖水道碼頭', 22.293670445, 114.198504994, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P003A', '三家村碼頭', 'Sam Ka Tsuen Ferry Pier', 22.291001000, 114.236315000, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P003B', '東岸板道', 'East Coast Boardwalk', 22.291883600, 114.195082400, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P004', '長洲公眾碼頭', '長洲公眾碼頭', 22.207984508, 114.028471227, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P005', '芝麻灣碼頭', '芝麻灣碼頭', 22.239654010, 114.000267838, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P006', '蘆荻灣碼頭', '蘆荻灣碼頭', 22.223125650, 114.126631804, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P007', '鹿洲村碼頭', '鹿洲村碼頭', 22.218466997, 114.130648851, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P008', '坪洲公眾碼頭', '坪洲公眾碼頭', 22.284175385, 114.037832489, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P009', '蒲台公眾碼頭', '蒲台公眾碼頭', 22.165038897, 114.253108764, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P010', '西灣碼頭', '西灣碼頭', 22.216597698, 114.103449356, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P011', '沙螺灣碼頭', '沙螺灣碼頭', 22.293758641, 113.904002788, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P012', '索罟灣二號碼頭', '索罟灣二號碼頭', 22.206329855, 114.131118334, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P013', '索罟灣公眾碼頭', '索罟灣公眾碼頭', 22.205652491, 114.130905195, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P014', '大利島碼頭', '大利島碼頭', 22.288515419, 114.033587632, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P015', '大澳公眾碼頭', '大澳公眾碼頭', 22.252621165, 113.853044201, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P016', '大水坑碼頭', '大水坑碼頭', 22.281985666, 114.023037028, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P017', '東涌發展碼頭(公眾)', '東涌發展碼頭(公眾)', 22.294158912, 113.940402296, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P018', '東涌公眾碼頭', '東涌公眾碼頭', 22.286257064, 113.934214975, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P019', '榕樹灣發展碼頭', '榕樹灣發展碼頭', 22.225187856, 114.110384462, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P020', '榕樹灣公眾碼頭', '榕樹灣公眾碼頭', 22.207984508, 114.028471227, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P021', '青衣公眾碼頭', '青衣公眾碼頭', 22.354208013, 114.109537072, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P022', '觀塘公眾碼頭', '觀塘公眾碼頭', 22.308647877, 114.220227597, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P023', '鴨洲公眾碼頭', '鴨洲公眾碼頭', 22.550426745, 114.269788019, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P024', '吉澳洲碼頭', '吉澳洲碼頭', 22.550142865, 114.290029071, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P025', '沙頭角公眾碼頭', '沙頭角公眾碼頭', 22.541541767, 114.227309178, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P026', '大廟灣公眾碼頭', '大廟灣公眾碼頭', 22.269954967, 114.288802966, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P027', '北丫碼頭', '北丫碼頭', 22.352811460, 114.349526267, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P028', '白沙灣第二碼頭', '白沙灣第二碼頭', 22.362255895, 114.259982846, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P029', '布袋澳二號碼頭', '布袋澳二號碼頭', 22.276632871, 114.295513056, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P030', '西貢新公眾碼頭', '西貢新公眾碼頭', 22.381211900, 114.274491497, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P031', '西貢公眾碼頭', '西貢公眾碼頭', 22.381518414, 114.275355924, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P032', '大頭洲碼頭', '大頭洲碼頭', 22.376860483, 114.321086432, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P033', '調景嶺碼頭', '調景嶺碼頭', 22.306986252, 114.264812343, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P034', '早禾坑碼頭', '早禾坑碼頭', 22.392165813, 114.288589804, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P035', '東龍洲北碼頭', '東龍洲北碼頭', 22.258221128, 114.293120604, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P036', '東龍洲公眾碼頭', '東龍洲公眾碼頭', 22.254647937, 114.288926611, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P037', '鹽田仔碼頭', '鹽田仔碼頭', 22.377346985, 114.300666879, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P038', '馬料水渡輪碼頭', '馬料水渡輪碼頭', 22.417169384, 114.214423872, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P039', '烏溪沙碼頭', '烏溪沙碼頭', 22.429472166, 114.234048660, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P040', '赤柱卜公碼頭', '赤柱卜公碼頭', 22.217341293, 114.210170759, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P041', '聖士提反灣 (南 )碼頭', '聖士提反灣 (南 )碼頭', 22.212012294, 114.214223499, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P042', '大潭灣碼頭', '大潭灣碼頭', 22.238830395, 114.225783799, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P043', '高流灣公眾碼頭', '高流灣公眾碼頭', 22.458563997, 114.360684187, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P044', '荔枝莊碼頭', '荔枝莊碼頭', 22.456689462, 114.299678248, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P045', '三門仔村碼頭', '三門仔村碼頭', 22.455476881, 114.213239195, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P046', '大美督一號碼頭', '大美督一號碼頭', 22.470443839, 114.232510837, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P047', '大埔鐵路碼頭', '大埔鐵路碼頭', 22.442549223, 114.183985420, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P048', '塔門碼頭', '塔門碼頭', 22.470360017, 114.358639868, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P049', '東平洲公眾碼頭', '東平洲公眾碼頭', 22.544948259, 114.433370247, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P050', '黃石公眾碼頭', '黃石公眾碼頭', 22.435588638, 114.337107171, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P051', '深井 釣魚灣碼頭', '深井 釣魚灣碼頭', 22.365087287, 114.058005533, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P052', '深井公眾碼頭', '深井公眾碼頭', 22.364833739, 114.057063965, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P053', '大排咀碼頭', '大排咀碼頭', 22.342467938, 114.060985515, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P054', '荃灣渡輪碼頭 (西鐵 )', '荃灣渡輪碼頭 (西鐵 )', 22.366724837, 114.110725295, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P055', '油柑頭碼頭', '油柑頭碼頭', 22.368227496, 114.098529649, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P056', '嘉道理碼頭', '嘉道理碼頭', 22.377121163, 113.980024506, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal'),
  ('P057', '九龍公眾碼頭', '九龍公眾碼頭', 22.293003496, 114.170314350, 50.0, 'pier', 'verified', true, '按公開碼頭資料，實際開放及安全情況須現場確認。', 'FisherGO geocoded spot seed', 'lib/features/catches/data/hk_fishing_spots_geocoded_seed.dart', 'fishergo-team', '2026-07-18T00:00:00Z', true, ARRAY['nearshore','pier']::text[], '{}'::jsonb, 'coastal')
on conflict (id) do update set
  name_zh = excluded.name_zh,
  name_en = excluded.name_en,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  coordinate_precision_m = excluded.coordinate_precision_m,
  kind = excluded.kind,
  verification_status = excluded.verification_status,
  public_access = excluded.public_access,
  safety_notes = excluded.safety_notes,
  source = excluded.source,
  source_reference = excluded.source_reference,
  reviewer = excluded.reviewer,
  reviewed_at = excluded.reviewed_at,
  active = excluded.active,
  habitat_tags = excluded.habitat_tags,
  species_weights = excluded.species_weights,
  environment = excluded.environment,
  updated_at = now();
