-- ============================================
-- FisherGO 雲端同步遷移 v2
-- Supabase Dashboard → SQL Editor → 執行此腳本
-- ============================================

-- 1. 玩家資料表（金幣、角色、裝備）
CREATE TABLE IF NOT EXISTS public.player_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,
    coins INTEGER NOT NULL DEFAULT 500,
    total_coins_earned INTEGER DEFAULT 0,
    avatar_name TEXT DEFAULT '默認角色',
    avatar_color TEXT DEFAULT '#4A90E2',
    equipped_rod TEXT DEFAULT '木竿',
    equipped_bait TEXT DEFAULT '紅蟲',
    equipped_hat TEXT DEFAULT '無',
    equipped_vest TEXT DEFAULT '無',
    equipped_boat TEXT DEFAULT '無',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 魚類圖鑑（記錄已收集的魚）
CREATE TABLE IF NOT EXISTS public.player_fish_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    fish_id TEXT NOT NULL,
    first_caught_at TIMESTAMPTZ DEFAULT now(),
    catch_count INTEGER DEFAULT 1,
    best_weight_grams REAL,
    best_rarity INTEGER,
    UNIQUE(user_id, fish_id)
);

-- 3. 魚獲記錄（釣魚歷史）
CREATE TABLE IF NOT EXISTS public.player_catches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    fish_id TEXT NOT NULL,
    fish_name TEXT,
    spot_name TEXT,
    rarity INTEGER,
    weight_grams REAL,
    caught_at TIMESTAMPTZ DEFAULT now(),
    is_boosted BOOLEAN DEFAULT false
);

-- ============================================
-- 啟用 RLS（行級安全）— 每人只能訪問自己的數據
-- ============================================
ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_fish_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_catches ENABLE ROW LEVEL SECURITY;

-- 每個 policy 讓已登入用戶完全控制自己的數據
CREATE POLICY "users_own_profiles" ON public.player_profiles
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "users_own_fish_collections" ON public.player_fish_collections
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "users_own_catches" ON public.player_catches
    FOR ALL USING (true) WITH CHECK (true);

-- 讓 anon key 能夠操作（前端已做 Auth）
ALTER TABLE public.player_profiles ENABLE ALL;
ALTER TABLE public.player_fish_collections ENABLE ALL;
ALTER TABLE public.player_catches ENABLE ALL;

-- 自動更新 updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_player_profiles_updated_at ON public.player_profiles;
CREATE TRIGGER set_player_profiles_updated_at
    BEFORE UPDATE ON public.player_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 完成後在 Supabase Dashboard 確認：
-- 1. Tables 可見：player_profiles, player_fish_collections, player_catches
-- 2. RLS 已啟用
-- 3. API 可以正常 insert/select
-- ============================================