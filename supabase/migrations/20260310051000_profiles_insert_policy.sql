-- Allow authenticated users to insert their own profile (for new sign-ups)
DO $$ BEGIN DROP POLICY IF EXISTS "Users can insert own profile" ON profiles; EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
