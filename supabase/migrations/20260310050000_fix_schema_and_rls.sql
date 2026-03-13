-- ============================================================
-- Fix profiles table: add missing columns expected by the app
-- ============================================================

-- Rename existing columns to match app's CodingKeys
ALTER TABLE profiles RENAME COLUMN full_name TO display_name;
ALTER TABLE profiles RENAME COLUMN goal TO goal_type;
ALTER TABLE profiles RENAME COLUMN current_streak TO streak_count;

-- Add missing columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_calories INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_protein INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_carbs INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_fat INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_weight_kg DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diet_style TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS meals_per_day INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longest_streak INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'imperial';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- ============================================================
-- RLS policies for meals
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own meals" ON meals; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own meals" ON meals; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can update own meals" ON meals; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can delete own meals" ON meals; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own meals" ON meals
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can read own meals" ON meals
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can update own meals" ON meals
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own meals" ON meals
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- RLS policies for meal_items
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own meal_items" ON meal_items; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own meal_items" ON meal_items; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can update own meal_items" ON meal_items; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can delete own meal_items" ON meal_items; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own meal_items" ON meal_items
    FOR INSERT TO authenticated WITH CHECK (
        meal_id IN (SELECT id FROM meals WHERE user_id = auth.uid())
    );
CREATE POLICY "Users can read own meal_items" ON meal_items
    FOR SELECT TO authenticated USING (
        meal_id IN (SELECT id FROM meals WHERE user_id = auth.uid())
    );
CREATE POLICY "Users can update own meal_items" ON meal_items
    FOR UPDATE TO authenticated USING (
        meal_id IN (SELECT id FROM meals WHERE user_id = auth.uid())
    );
CREATE POLICY "Users can delete own meal_items" ON meal_items
    FOR DELETE TO authenticated USING (
        meal_id IN (SELECT id FROM meals WHERE user_id = auth.uid())
    );

-- ============================================================
-- RLS policies for daily_summaries
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own daily_summaries" ON daily_summaries; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own daily_summaries" ON daily_summaries; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can update own daily_summaries" ON daily_summaries; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can delete own daily_summaries" ON daily_summaries; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own daily_summaries" ON daily_summaries
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can read own daily_summaries" ON daily_summaries
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can update own daily_summaries" ON daily_summaries
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own daily_summaries" ON daily_summaries
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- RLS policies for water_logs
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own water_logs" ON water_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own water_logs" ON water_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can delete own water_logs" ON water_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own water_logs" ON water_logs
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can read own water_logs" ON water_logs
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own water_logs" ON water_logs
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- RLS policies for weight_logs
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own weight_logs" ON weight_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own weight_logs" ON weight_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can delete own weight_logs" ON weight_logs; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own weight_logs" ON weight_logs
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can read own weight_logs" ON weight_logs
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own weight_logs" ON weight_logs
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- RLS policies for profiles (ensure authenticated users can CRUD own profile)
-- ============================================================
DO $$ BEGIN DROP POLICY IF EXISTS "Users can read own profile" ON profiles; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can update own profile" ON profiles; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can read own profile" ON profiles
    FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Enable RLS on all tables (idempotent)
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
