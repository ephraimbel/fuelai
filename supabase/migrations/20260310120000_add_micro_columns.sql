-- Add micro-nutrient columns to meals, meal_items, and daily_summaries

-- Meals
ALTER TABLE meals ADD COLUMN IF NOT EXISTS total_fiber double precision DEFAULT 0;
ALTER TABLE meals ADD COLUMN IF NOT EXISTS total_sugar double precision DEFAULT 0;
ALTER TABLE meals ADD COLUMN IF NOT EXISTS total_sodium double precision DEFAULT 0;

-- Meal items
ALTER TABLE meal_items ADD COLUMN IF NOT EXISTS fiber double precision DEFAULT 0;
ALTER TABLE meal_items ADD COLUMN IF NOT EXISTS sugar double precision DEFAULT 0;

-- Daily summaries
ALTER TABLE daily_summaries ADD COLUMN IF NOT EXISTS total_fiber double precision DEFAULT 0;
ALTER TABLE daily_summaries ADD COLUMN IF NOT EXISTS total_sugar double precision DEFAULT 0;
ALTER TABLE daily_summaries ADD COLUMN IF NOT EXISTS total_sodium double precision DEFAULT 0;
