-- ============================================================================
-- FUEL APP — COMPLETE SUPABASE SETUP
-- ============================================================================
-- Run this in the Supabase SQL Editor (supabase.com > SQL Editor)
-- Safe to re-run: uses IF NOT EXISTS / IF EXISTS / CREATE OR REPLACE
-- ============================================================================

-- =========================
-- 1. EXTENSIONS
-- =========================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================
-- 2. DROP LEGACY (V1) OBJECTS
-- =========================
-- Clean up old schema if upgrading from V1
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TABLE IF EXISTS daily_logs CASCADE;
DROP TABLE IF EXISTS meal_entries CASCADE;
DROP TABLE IF EXISTS nutrition_goals CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- =========================
-- 3. CORE TABLES
-- =========================

-- Profiles (auto-created on signup via trigger)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    age INTEGER,
    sex TEXT CHECK (sex IN ('male', 'female')),
    height_cm DOUBLE PRECISION,
    weight_kg DOUBLE PRECISION,
    target_weight_kg DOUBLE PRECISION,
    activity_level TEXT CHECK (activity_level IN ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    goal_type TEXT CHECK (goal_type IN ('lose', 'tone_up', 'maintain', 'gain', 'bulk', 'athlete')),
    diet_style TEXT CHECK (diet_style IN ('standard', 'high_protein', 'keto', 'vegetarian', 'vegan', 'mediterranean')),
    meals_per_day INTEGER,
    target_calories INTEGER,
    target_protein INTEGER,
    target_carbs INTEGER,
    target_fat INTEGER,
    water_goal_ml INTEGER DEFAULT 2500,
    is_premium BOOLEAN DEFAULT FALSE,
    streak_count INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    unit_system TEXT DEFAULT 'imperial' CHECK (unit_system IN ('imperial', 'metric')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Meals
CREATE TABLE IF NOT EXISTS meals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    display_name TEXT NOT NULL,
    total_calories INTEGER NOT NULL,
    total_protein DOUBLE PRECISION NOT NULL,
    total_carbs DOUBLE PRECISION NOT NULL,
    total_fat DOUBLE PRECISION NOT NULL,
    image_url TEXT,
    logged_date TEXT NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Meal Items (joined via PostgREST as "items:meal_items(*)" from meals)
CREATE TABLE IF NOT EXISTS meal_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_id UUID REFERENCES meals(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    calories INTEGER NOT NULL,
    protein DOUBLE PRECISION NOT NULL,
    carbs DOUBLE PRECISION NOT NULL,
    fat DOUBLE PRECISION NOT NULL,
    serving_size TEXT,
    quantity DOUBLE PRECISION DEFAULT 1.0,
    confidence DOUBLE PRECISION DEFAULT 0.8
);

-- Daily Summaries (upserted by the app on unique(user_id, date))
CREATE TABLE IF NOT EXISTS daily_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    date TEXT NOT NULL,
    total_calories INTEGER DEFAULT 0,
    total_protein DOUBLE PRECISION DEFAULT 0,
    total_carbs DOUBLE PRECISION DEFAULT 0,
    total_fat DOUBLE PRECISION DEFAULT 0,
    water_ml INTEGER DEFAULT 0,
    ai_insight TEXT,
    is_on_target BOOLEAN DEFAULT FALSE,
    UNIQUE(user_id, date)
);

-- Water Logs
CREATE TABLE IF NOT EXISTS water_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    amount_ml INTEGER NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- Weight Logs
CREATE TABLE IF NOT EXISTS weight_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    weight_kg DOUBLE PRECISION NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    role TEXT CHECK (role IN ('user', 'assistant')) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Favorite Meals (items stored as JSONB array of MealItem objects)
CREATE TABLE IF NOT EXISTS favorite_meals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    items JSONB NOT NULL,
    total_calories INTEGER NOT NULL,
    total_protein DOUBLE PRECISION NOT NULL,
    total_carbs DOUBLE PRECISION NOT NULL,
    total_fat DOUBLE PRECISION NOT NULL,
    use_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Nutrition Logs (analytics — tracks every scan/query for accuracy monitoring)
CREATE TABLE IF NOT EXISTS nutrition_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    query_type TEXT NOT NULL,
    query TEXT NOT NULL,
    rag_top_score DOUBLE PRECISION,
    rag_match_count INTEGER NOT NULL DEFAULT 0,
    result_calories INTEGER NOT NULL DEFAULT 0,
    result_confidence TEXT,
    response_time_ms INTEGER NOT NULL DEFAULT 0,
    was_offline BOOLEAN NOT NULL DEFAULT FALSE,
    was_cached BOOLEAN NOT NULL DEFAULT FALSE,
    rag_corrected BOOLEAN NOT NULL DEFAULT FALSE,
    correction_amount INTEGER NOT NULL DEFAULT 0,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================
-- 4. INDEXES
-- =========================
CREATE INDEX IF NOT EXISTS idx_meals_user_date ON meals(user_id, logged_date);
CREATE INDEX IF NOT EXISTS idx_meals_logged_at ON meals(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON meal_items(meal_id);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_user_date ON daily_summaries(user_id, date);
CREATE INDEX IF NOT EXISTS idx_water_logs_user_date ON water_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_weight_logs_user ON weight_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON chat_messages(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_favorite_meals_user ON favorite_meals(user_id, use_count DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_logs_timestamp ON nutrition_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_logs_query_type ON nutrition_logs(query_type);

-- =========================
-- 5. ROW LEVEL SECURITY
-- =========================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorite_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first (safe to re-run)
DROP POLICY IF EXISTS "Users own profile" ON profiles;
DROP POLICY IF EXISTS "Users own meals" ON meals;
DROP POLICY IF EXISTS "Users own meal_items" ON meal_items;
DROP POLICY IF EXISTS "Users own summaries" ON daily_summaries;
DROP POLICY IF EXISTS "Users own water" ON water_logs;
DROP POLICY IF EXISTS "Users own weight" ON weight_logs;
DROP POLICY IF EXISTS "Users own chat" ON chat_messages;
DROP POLICY IF EXISTS "Users own favorites" ON favorite_meals;
DROP POLICY IF EXISTS "Users can insert logs" ON nutrition_logs;

-- Profiles: users can only access their own row
CREATE POLICY "Users own profile" ON profiles
    FOR ALL USING (auth.uid() = id);

-- Meals: users can only access their own meals
CREATE POLICY "Users own meals" ON meals
    FOR ALL USING (auth.uid() = user_id);

-- Meal items: users can only access items in their own meals
CREATE POLICY "Users own meal_items" ON meal_items
    FOR ALL USING (meal_id IN (SELECT id FROM meals WHERE user_id = auth.uid()));

-- Daily summaries: users can only access their own
CREATE POLICY "Users own summaries" ON daily_summaries
    FOR ALL USING (auth.uid() = user_id);

-- Water logs: users can only access their own
CREATE POLICY "Users own water" ON water_logs
    FOR ALL USING (auth.uid() = user_id);

-- Weight logs: users can only access their own
CREATE POLICY "Users own weight" ON weight_logs
    FOR ALL USING (auth.uid() = user_id);

-- Chat messages: users can only access their own
CREATE POLICY "Users own chat" ON chat_messages
    FOR ALL USING (auth.uid() = user_id);

-- Favorite meals: users can only access their own
CREATE POLICY "Users own favorites" ON favorite_meals
    FOR ALL USING (auth.uid() = user_id);

-- Nutrition logs: any authenticated user can insert (anonymized analytics)
CREATE POLICY "Users can insert logs" ON nutrition_logs
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- =========================
-- 6. FUNCTIONS
-- =========================

-- Auto-create profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Calculate logging streak and update profile
-- Called via: supabase.rpc("calculate_streak", params: ["p_user_id": uuid])
-- Returns: { "streak": Int }
CREATE OR REPLACE FUNCTION calculate_streak(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
    streak INTEGER := 0;
    check_date TEXT;
BEGIN
    check_date := TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD');

    LOOP
        IF EXISTS (
            SELECT 1 FROM daily_summaries
            WHERE user_id = p_user_id AND date = check_date AND total_calories > 0
        ) THEN
            streak := streak + 1;
            check_date := TO_CHAR(TO_DATE(check_date, 'YYYY-MM-DD') - INTERVAL '1 day', 'YYYY-MM-DD');
        ELSE
            EXIT;
        END IF;
    END LOOP;

    UPDATE profiles SET
        streak_count = streak,
        longest_streak = GREATEST(longest_streak, streak),
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN json_build_object('streak', streak);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment favorite meal use count
-- Called via: supabase.rpc("increment_favorite_use", params: ["p_id": uuid])
CREATE OR REPLACE FUNCTION increment_favorite_use(p_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE favorite_meals SET use_count = use_count + 1 WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete user account and ALL associated data
-- Called via: supabase.rpc("delete_user_account", params: ["user_id": uuid])
-- Cascading FKs handle meals, meal_items, summaries, water, weight, chat, favorites.
-- Then removes the auth.users row which triggers profile cascade.
CREATE OR REPLACE FUNCTION delete_user_account(user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Verify the caller is deleting their own account
    IF auth.uid() != user_id THEN
        RAISE EXCEPTION 'Not authorized to delete this account';
    END IF;

    -- Delete nutrition logs for this user (no FK, manual cleanup)
    -- nutrition_logs is anonymized and has no user_id column, so nothing to clean there.

    -- Delete the auth user — this cascades to profiles, which cascades to everything else
    DELETE FROM auth.users WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =========================
-- 7. STORAGE BUCKETS
-- =========================

-- Create "meal-images" bucket (public read, authenticated write)
INSERT INTO storage.buckets (id, name, public)
VALUES ('meal-images', 'meal-images', true)
ON CONFLICT (id) DO NOTHING;

-- Create "food-database" bucket (public read) for remote food sync
INSERT INTO storage.buckets (id, name, public)
VALUES ('food-database', 'food-database', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies (safe to re-run)
DROP POLICY IF EXISTS "Users upload own meal images" ON storage.objects;
DROP POLICY IF EXISTS "Public read meal images" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own meal images" ON storage.objects;
DROP POLICY IF EXISTS "Public read food database" ON storage.objects;

-- meal-images: authenticated users upload to their own folder ({user_id}/...)
CREATE POLICY "Users upload own meal images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- meal-images: anyone can read (public bucket for image display)
CREATE POLICY "Public read meal images"
ON storage.objects FOR SELECT
USING (bucket_id = 'meal-images');

-- meal-images: users can delete their own photos
CREATE POLICY "Users delete own meal images"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- food-database: public read for food JSON files (RemoteFoodSync downloads foods_v1.json)
CREATE POLICY "Public read food database"
ON storage.objects FOR SELECT
USING (bucket_id = 'food-database');

-- =========================
-- 8. VERIFY
-- =========================
-- Quick sanity check: list all tables we just created
DO $$
DECLARE
    tbl TEXT;
    expected TEXT[] := ARRAY[
        'profiles', 'meals', 'meal_items', 'daily_summaries',
        'water_logs', 'weight_logs', 'chat_messages',
        'favorite_meals', 'nutrition_logs'
    ];
    missing TEXT[] := '{}';
BEGIN
    FOREACH tbl IN ARRAY expected LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            missing := array_append(missing, tbl);
        END IF;
    END LOOP;

    IF array_length(missing, 1) > 0 THEN
        RAISE WARNING 'MISSING TABLES: %', array_to_string(missing, ', ');
    ELSE
        RAISE NOTICE 'All 9 tables created successfully.';
    END IF;
END $$;

-- =========================
-- 9. POST-SETUP CHECKLIST
-- =========================
-- After running this SQL, complete these steps in order:
--
-- A) Set the ANTHROPIC_API_KEY secret for edge functions:
--      supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-...
--
-- B) Deploy all 4 edge functions:
--      supabase functions deploy get-api-key
--      supabase functions deploy analyze-food
--      supabase functions deploy fuel-chat
--      supabase functions deploy fuel-insight
--
-- C) Upload the food database to the food-database storage bucket:
--      Go to Supabase Dashboard > Storage > food-database > Upload
--      Upload file: Fuel/Resources/expanded_foods.json  (rename to foods_v1.json)
--
-- D) Verify in the app:
--      1. Sign up with Apple — profile should auto-create
--      2. Photo scan a meal — should return structured nutrition data
--      3. Check Table Editor > nutrition_logs — should see analytics rows
--      4. Check Table Editor > meals — should see logged meals
--
-- ============================================================================
-- REFERENCE: What the app talks to
-- ============================================================================
-- TABLES (9):    profiles, meals, meal_items, daily_summaries, water_logs,
--                weight_logs, chat_messages, favorite_meals, nutrition_logs
-- RPC (3):       calculate_streak, increment_favorite_use, delete_user_account
-- EDGE FNS (4):  get-api-key, analyze-food, fuel-chat, fuel-insight
-- STORAGE (2):   meal-images (user photos), food-database (foods_v1.json)
-- TRIGGER (1):   on_auth_user_created -> handle_new_user()
-- ============================================================================
