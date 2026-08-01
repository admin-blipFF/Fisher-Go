-- Audited game-design habitat weights for the existing public spot registry.
-- These are spawn-gameplay weights, not a live ecological survey.
-- Keep this additive so the original geocoded seed remains traceable.

update public.fishing_spots
   set habitat_tags = array['nearshore', 'pier', 'tung-chung-runway']::text[],
       species_weights = jsonb_build_object(
         'fish-103', 4,
         'fish-109', 4
       ),
       updated_at = now()
 where id in ('P017', 'P018');

update public.fishing_spots
   set habitat_tags = array['nearshore', 'pier', 'sam-mun-tsai-tai-po-inner']::text[],
       species_weights = jsonb_build_object(
         'fish-063', 4,
         'fish-067', 4
       ),
       updated_at = now()
 where id in ('P045', 'P046', 'P047', 'P050');

update public.fishing_spots
   set habitat_tags = array['nearshore', 'pier', 'tsing-ma-waters']::text[],
       species_weights = jsonb_build_object(
         'fish-069', 4,
         'fish-073', 4
       ),
       updated_at = now()
 where id in ('P051', 'P052', 'P053', 'P054');

update public.fishing_spots
   set habitat_tags = array['nearshore', 'pier', 'east-water']::text[],
       species_weights = jsonb_build_object(
         'fish-101', 4,
         'fish-103', 4,
         'fish-140', 4
       ),
       updated_at = now()
 where id in ('P035', 'P036', 'P043');
