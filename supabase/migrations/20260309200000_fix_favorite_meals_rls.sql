-- Drop and recreate RLS policies for favorite_meals
DO $$ BEGIN
    DROP POLICY IF EXISTS "Users can insert own favorites" ON favorite_meals;
    DROP POLICY IF EXISTS "Users can read own favorites" ON favorite_meals;
    DROP POLICY IF EXISTS "Users can update own favorites" ON favorite_meals;
    DROP POLICY IF EXISTS "Users can delete own favorites" ON favorite_meals;
END $$;

ALTER TABLE favorite_meals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own favorites"
    ON favorite_meals FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own favorites"
    ON favorite_meals FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own favorites"
    ON favorite_meals FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
    ON favorite_meals FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
