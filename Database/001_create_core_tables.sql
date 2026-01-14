-- ============================================
-- EarthLord 核心数据表迁移脚本
-- 版本: 001
-- 创建时间: 2026-01-14
-- ============================================

-- ============================================
-- 1. profiles（用户资料表）
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加表注释
COMMENT ON TABLE public.profiles IS '用户资料表';
COMMENT ON COLUMN public.profiles.id IS '用户ID，关联auth.users';
COMMENT ON COLUMN public.profiles.username IS '用户名';
COMMENT ON COLUMN public.profiles.avatar_url IS '头像URL';
COMMENT ON COLUMN public.profiles.created_at IS '创建时间';

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看所有资料
CREATE POLICY "profiles_select_policy" ON public.profiles
    FOR SELECT USING (true);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "profiles_update_policy" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- RLS 策略：用户只能插入自己的资料
CREATE POLICY "profiles_insert_policy" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- 2. territories（领地表）
-- ============================================
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL,
    area DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加表注释
COMMENT ON TABLE public.territories IS '领地表';
COMMENT ON COLUMN public.territories.id IS '领地ID';
COMMENT ON COLUMN public.territories.user_id IS '所有者用户ID';
COMMENT ON COLUMN public.territories.name IS '领地名称';
COMMENT ON COLUMN public.territories.path IS '路径点数组 [{lat, lng}, ...]';
COMMENT ON COLUMN public.territories.area IS '面积（平方米）';
COMMENT ON COLUMN public.territories.created_at IS '创建时间';

-- 创建索引
CREATE INDEX IF NOT EXISTS territories_user_id_idx ON public.territories(user_id);

-- 启用 RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看领地
CREATE POLICY "territories_select_policy" ON public.territories
    FOR SELECT USING (true);

-- RLS 策略：用户只能插入自己的领地
CREATE POLICY "territories_insert_policy" ON public.territories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "territories_update_policy" ON public.territories
    FOR UPDATE USING (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "territories_delete_policy" ON public.territories
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 3. pois（兴趣点表）
-- ============================================
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加表注释
COMMENT ON TABLE public.pois IS '兴趣点表';
COMMENT ON COLUMN public.pois.id IS '外部POI ID';
COMMENT ON COLUMN public.pois.poi_type IS '类型：hospital/supermarket/factory/park/bank等';
COMMENT ON COLUMN public.pois.name IS 'POI名称';
COMMENT ON COLUMN public.pois.latitude IS '纬度';
COMMENT ON COLUMN public.pois.longitude IS '经度';
COMMENT ON COLUMN public.pois.discovered_by IS '发现者用户ID';
COMMENT ON COLUMN public.pois.discovered_at IS '发现时间';

-- 创建索引
CREATE INDEX IF NOT EXISTS pois_type_idx ON public.pois(poi_type);
CREATE INDEX IF NOT EXISTS pois_location_idx ON public.pois(latitude, longitude);
CREATE INDEX IF NOT EXISTS pois_discovered_by_idx ON public.pois(discovered_by);

-- 启用 RLS
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看POI
CREATE POLICY "pois_select_policy" ON public.pois
    FOR SELECT USING (true);

-- RLS 策略：已登录用户可以插入POI
CREATE POLICY "pois_insert_policy" ON public.pois
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RLS 策略：只有发现者可以更新POI
CREATE POLICY "pois_update_policy" ON public.pois
    FOR UPDATE USING (auth.uid() = discovered_by);

-- ============================================
-- 4. 创建触发器：新用户自动创建 profile
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'Pioneer_' || LEFT(NEW.id::TEXT, 8)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除已存在的触发器（如果有）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 完成
-- ============================================
