-- Add measurement fields to meal_items for portion-based adjustments
ALTER TABLE meal_items ADD COLUMN IF NOT EXISTS estimated_grams double precision DEFAULT 0;
ALTER TABLE meal_items ADD COLUMN IF NOT EXISTS measurement_unit text DEFAULT 'g';
ALTER TABLE meal_items ADD COLUMN IF NOT EXISTS measurement_amount double precision DEFAULT 1.0;
